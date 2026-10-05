import PhotosUI
import PitlogCore
import QuickLook
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Add and edit form for one history entry. Edits are applied only on "Save". Receipts are attached from
/// Files, Photos or the scanner and previewed with QuickLook, which also offers the share sheet. A scan fills
/// the form through the review screen (M5b).
struct EntryEditorView: View {
    let vehicle: Vehicle
    /// `nil` creates a new entry.
    let entry: MaintenanceEntry?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.entitlements) private var entitlements
    @Query private var allVehicles: [Vehicle]

    @State private var category: MaintenanceCategory
    @State private var date: Date
    @State private var kilometers: Int?
    @State private var workshop: String
    @State private var workItems: String
    @State private var amountText: String
    @State private var currency: String
    @State private var note: String
    @State private var receipts: [EditorReceiptDraft]

    @State private var previewURL: URL?
    @State private var showingFileImporter = false
    @State private var showingPhotoPicker = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var importFailed = false
    @State private var scan = ReceiptScanController()
    @State private var paywall: PaywallContext?

    init(vehicle: Vehicle, entry: MaintenanceEntry?, prefill: EntryPrefill?) {
        self.vehicle = vehicle
        self.entry = entry
        let locale = Locale.autoupdatingCurrent
        let defaultCurrency = MoneyFormat.defaultCurrency(locale: locale)
        if let entry {
            _category = State(initialValue: entry.category)
            _date = State(initialValue: CalendarDay.date(from: entry.date, in: .current))
            _kilometers = State(initialValue: entry.odometerKm)
            _workshop = State(initialValue: entry.workshop)
            _workItems = State(initialValue: entry.workItems)
            _amountText = State(initialValue: entry.money.map { MoneyFormat.editText($0, locale: locale) } ?? "")
            _currency = State(initialValue: entry.currencyCode)
            _note = State(initialValue: entry.note)
            _receipts = State(initialValue: (entry.receipts ?? [])
                .sorted { $0.createdAt < $1.createdAt }
                .compactMap { receipt in
                    receipt.data.map {
                        EditorReceiptDraft(data: $0, contentType: receipt.contentType, pageCount: receipt.pageCount, existing: receipt)
                    }
                })
        } else {
            let day = prefill?.date ?? CalendarDay.today(in: .current)
            _category = State(initialValue: prefill?.category ?? .service)
            _date = State(initialValue: CalendarDay.date(from: day, in: .current))
            _kilometers = State(initialValue: prefill?.km)
            _workshop = State(initialValue: "")
            _workItems = State(initialValue: prefill?.workItems ?? "")
            _amountText = State(initialValue: "")
            _currency = State(initialValue: defaultCurrency)
            _note = State(initialValue: "")
            _receipts = State(initialValue: [])
        }
    }

    private var parsedAmount: MoneyFormat.Parsed {
        MoneyFormat.parse(amountText, currency: currency, locale: locale)
    }

    private var canSave: Bool { parsedAmount != .invalid }

    var body: some View {
        NavigationStack {
            Form {
                basics
                workSection
                costSection
                receiptsSection
                Section {
                    FormTextField(title: Text("Note", comment: "Reminder editor: optional note"), text: $note)
                }
            }
            .navigationTitle(Text("Entry", comment: "Navigation title of the history entry editor"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Cancel button of a form")
                    }
                    .accessibilityIdentifier("cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Text("Save", comment: "Save button of a form")
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("saveEntryButton")
                }
            }
            // On a view of its own: two `fileImporter`s on one view would compete.
            .background {
                Color.clear.receiptScan(scan, mode: .fillForm) { application, attachment in
                    applyScan(application, attachment: attachment)
                }
            }
            .background { Color.clear.paywall($paywall) }
            .quickLookPreview($previewURL)
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.pdf, .image]) { result in
                importFile(result)
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $photoSelection, matching: .images)
            .onChange(of: photoSelection) { _, item in
                guard let item else { return }
                Task { await importPhoto(item) }
            }
            .alert(
                Text("The receipt could not be added.", comment: "Entry editor: alert title when a receipt file cannot be read"),
                isPresented: $importFailed
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Button that dismisses an alert")
                }
            } message: {
                Text("Choose a photo or a PDF of up to 20 MB.", comment: "Entry editor: alert message when a receipt file cannot be read")
            }
        }
    }

    // MARK: Sections

    private var basics: some View {
        Section {
            MenuPickerRow(
                title: Text("Category", comment: "History: category filter and entry editor field"),
                valueText: Text(verbatim: category.title(locale: locale)),
                selection: $category
            ) {
                ForEach(MaintenanceCategory.allCases, id: \.self) { category in
                    Text(verbatim: category.title(locale: locale)).tag(category)
                }
            }
            .accessibilityIdentifier("entryCategory")
            DatePicker(selection: $date, displayedComponents: .date) {
                Text("Date", comment: "Reminder editor: date of the reminder")
            }
            FormNumberField(
                title: Text("Odometer (km)", comment: "Entry editor: odometer reading at the visit, with unit"),
                value: $kilometers)
        }
    }

    private var workSection: some View {
        Section {
            FormTextField(title: Text("Workshop", comment: "Entry editor: name of the workshop"), text: $workshop)
            FormMultilineTextField(
                title: Text("Work done", comment: "Entry editor: what the workshop did, one item per line"),
                text: $workItems)
        }
    }

    private var costSection: some View {
        Section {
            LabeledContent {
                TextField(text: $amountText, prompt: Text(verbatim: "")) {
                    Text("Amount", comment: "Entry editor: what the visit cost")
                }
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .accessibilityLabel(Text("Amount", comment: "Entry editor: what the visit cost"))
                .accessibilityIdentifier("entryAmount")
            } label: {
                Text("Amount", comment: "Entry editor: what the visit cost")
                    .foregroundStyle(.primary)
            }
            MenuPickerRow(
                title: Text("Currency", comment: "Entry editor and costs: the currency of an amount"),
                valueText: Text(verbatim: MoneyFormat.name(of: currency, locale: locale)),
                selection: $currency
            ) {
                ForEach(MoneyFormat.choices(including: [currency], locale: locale), id: \.self) { code in
                    Text(verbatim: MoneyFormat.name(of: code, locale: locale)).tag(code)
                }
            }
            .accessibilityIdentifier("entryCurrency")
            if parsedAmount == .invalid {
                Label {
                    Text("Enter the amount as a number, for example 120.50.", comment: "Entry editor: the amount field does not contain a valid number")
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
            }
        }
    }

    private var receiptsSection: some View {
        Section {
            Text("Receipts", comment: "Entry editor: header of the attached receipts")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(receipts) { receipt in
                receiptRow(receipt)
            }
            ActionRow(
                title: Text("Scan receipt", comment: "Entry editor: scan a workshop receipt with the camera or from a file and fill in the entry"),
                systemImage: "doc.text.viewfinder", showsProBadge: !entitlements.canScanReceipts,
                identifier: "scanReceiptRow",
                accessibilityLabelText: entitlements.canScanReceipts
                    ? nil
                    : Text("Scan receipt, requires Pitlog Pro", comment: "VoiceOver label of the receipt scan row in the entry editor while the user has no Pro")
            ) { startScan() }
            addRow(
                Text("Add from Files", comment: "Entry editor: attach a receipt from the Files app"),
                systemImage: "doc.badge.plus", identifier: "addReceiptFileRow"
            ) { showingFileImporter = true }
            addRow(
                Text("Add from Photos", comment: "Entry editor: attach a receipt from the photo library"),
                systemImage: "photo.badge.plus", identifier: "addReceiptPhotoRow"
            ) { showingPhotoPicker = true }
        }
    }

    private func receiptRow(_ receipt: EditorReceiptDraft) -> some View {
        let title = receiptTitle(receipt)
        return Label {
            Text(verbatim: title)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: receipt.isPDF ? "doc.richtext" : "photo")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { preview(receipt) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityHint(Text("Opens a preview. You can share the receipt from there.", comment: "VoiceOver hint of an attached receipt"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { preview(receipt) }
        .accessibilityAction(named: Text("Remove", comment: "Entry editor: remove an attached receipt")) { remove(receipt) }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                remove(receipt)
            } label: {
                Label {
                    Text("Remove", comment: "Entry editor: remove an attached receipt")
                } icon: {
                    Image(systemName: "trash")
                }
            }
        }
    }

    private func receiptTitle(_ receipt: EditorReceiptDraft) -> String {
        if receipt.isPDF {
            String(localized: "PDF receipt, \(receipt.pageCount) pages", locale: locale, comment: "Entry editor: an attached PDF receipt with its number of pages, plural")
        } else {
            String(localized: "Photo of a receipt", locale: locale, comment: "Entry editor: an attached photo of a receipt")
        }
    }

    private func addRow(_ title: Text, systemImage: String, identifier: String, action: @escaping () -> Void) -> some View {
        Label {
            title.fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
        }
        .foregroundStyle(Color.accentColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
        .accessibilityIdentifier(identifier)
    }

    // MARK: Receipts

    private func startScan() {
        guard entitlements.canScanReceipts else {
            paywall = .receiptScan
            return
        }
        let infos = allVehicles.filter { !$0.isArchived || $0.id == vehicle.id }.map { ReceiptVehicleInfo($0) }
        scan.start(ReceiptScanInput(vehicles: infos, contextVehicleID: vehicle.id, vehicleIsFixed: true))
    }

    /// Copies the values the user kept on the review into the form and attaches the scan. Nothing is saved here.
    private func applyScan(_ application: ReceiptApplication, attachment: ReceiptAttachment?) {
        if let day = application.date { date = CalendarDay.date(from: day, in: .current) }
        if let scanned = application.category { category = scanned }
        if let scanned = application.workshop { workshop = scanned }
        if let scanned = application.workItems { workItems = scanned }
        if let money = application.amount {
            amountText = MoneyFormat.editText(money, locale: locale)
            currency = money.currencyCode
        }
        if let km = application.odometerKm { kilometers = km }
        if let attachment {
            receipts.append(
                EditorReceiptDraft(
                    data: attachment.data, contentType: attachment.contentType, pageCount: attachment.pageCount,
                    existing: nil, recognizedText: attachment.recognizedText))
        }
    }

    private func preview(_ receipt: EditorReceiptDraft) {
        previewURL = receipt.previewFile()
    }

    private func remove(_ receipt: EditorReceiptDraft) {
        receipts.removeAll { $0.id == receipt.id }
    }

    private func importFile(_ result: Result<URL, any Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let draft = ReceiptImport.draft(from: data) else {
            importFailed = true
            return
        }
        receipts.append(draft)
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        defer { photoSelection = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let draft = ReceiptImport.draft(from: data)
        else {
            importFailed = true
            return
        }
        receipts.append(draft)
    }

    // MARK: Save

    private func save() {
        let day = CalendarDay.dayDate(from: date, in: .current)
        let target: MaintenanceEntry
        if let entry {
            target = entry
        } else {
            target = MaintenanceEntry(date: day, category: category)
            modelContext.insert(target)
            target.vehicle = vehicle
        }
        target.category = category
        target.date = day
        target.odometerKm = kilometers
        target.workshop = workshop.trimmingCharacters(in: .whitespacesAndNewlines)
        target.workItems = workItems.trimmingCharacters(in: .whitespacesAndNewlines)
        target.currencyCode = currency
        if case .value(let money) = parsedAmount {
            target.amountMinor = Int(clamping: money.amountMinor)
        } else {
            target.amountMinor = nil
        }
        target.note = note

        // Receipts: drop the removed ones, add the new ones.
        let kept = Set(receipts.compactMap { $0.existing?.persistentModelID })
        for stored in target.receipts ?? [] where !kept.contains(stored.persistentModelID) {
            modelContext.delete(stored)
        }
        for draft in receipts where draft.existing == nil {
            let stored = ReceiptDocument(
                data: draft.data, contentType: draft.contentType, pageCount: draft.pageCount)
            stored.recognizedText = draft.recognizedText
            modelContext.insert(stored)
            stored.entry = target
        }

        OdometerSync.addReadingIfNewer(for: vehicle, day: day, km: kilometers, in: modelContext)
        dismiss()
    }
}
