import PitlogCore
import SwiftData
import SwiftUI

/// The maintenance history of one vehicle: costs per year on top, then the timeline grouped by year.
/// Pushed from the vehicle detail. Rows are tappable rows with swipe actions (a `Button` row in a list
/// fails the clipping audit, see `docs/accessibility-audit.md`).
struct HistoryView: View {
    let vehicle: Vehicle

    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.entitlements) private var entitlements
    @Query private var allVehicles: [Vehicle]
    @State private var scan = ReceiptScanController()
    @State private var paywall: PaywallContext?
    @State private var editorTarget: EntryEditorTarget?
    @State private var filter: MaintenanceCategory?
    @State private var entryToDelete: MaintenanceEntry?
    @State private var showingDeleteConfirmation = false
    @State private var showingServiceRecord = false

    private var entries: [MaintenanceEntry] { vehicle.maintenanceEntries ?? [] }

    /// Over the free limit (ADR-11): the history is readable, changes lead to the paywall.
    private var isReadOnly: Bool {
        entitlements.isReadOnly(vehicle, among: allVehicles.filter { !$0.isArchived })
    }

    /// Runs `change` for an editable vehicle, shows the paywall for a read-only one.
    private func edit(_ change: () -> Void) {
        if isReadOnly { paywall = .vehicles } else { change() }
    }

    var body: some View {
        let groups = HistoryTimeline.groups(entries, filter: filter)
        List {
            if isReadOnly {
                ReadOnlyBanner { paywall = .vehicles }
                    .listRowSeparator(.hidden)
            }
            CostsSection(entries: entries) { paywall = .costs }
            timelineHeader
            filterRow
            addRow
            addFromReceiptRow
            exportRow
            if entries.isEmpty {
                note(Text("No entries yet. Add service, repairs and other workshop visits.", comment: "History: empty state"))
            } else if groups.isEmpty {
                note(Text("No entries in this category.", comment: "History: empty state when the category filter matches nothing"))
            }
            ForEach(groups) { group in
                yearHeader(group.year)
                ForEach(group.entries, id: \.persistentModelID) { entry in
                    row(entry)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(Text("History", comment: "Section header on the vehicle detail: maintenance history and costs"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .paywall($paywall)
        .receiptScan(scan, mode: .saveEntry) { application, attachment in
            createEntry(from: application, attachment: attachment)
        }
        .sheet(item: $editorTarget) { target in
            EntryEditorView(vehicle: vehicle, entry: target.entry, prefill: target.prefill)
        }
        .sheet(isPresented: $showingServiceRecord, onDismiss: { ServiceRecordTempFiles.sweep() }) {
            ServiceRecordExportView(vehicle: vehicle)
        }
        .confirmationDialog(
            Text("Delete this entry?", comment: "History: title of the delete confirmation"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible,
            presenting: entryToDelete
        ) { entry in
            Button(role: .destructive) {
                modelContext.delete(entry)
                entryToDelete = nil
            } label: {
                Text("Delete", comment: "Swipe action to delete a reminder")
            }
        } message: { _ in
            Text("The entry and its receipts are deleted from all your devices.", comment: "History: message of the delete confirmation")
        }
    }

    // MARK: Header rows

    private var timelineHeader: some View {
        Text("Entries", comment: "History: header above the list of entries")
            .font(.title3.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
            .listRowSeparator(.hidden)
            .padding(.top, 8)
    }

    private func yearHeader(_ year: Int) -> some View {
        Text(verbatim: String(year))
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
            .listRowSeparator(.hidden)
    }

    private func note(_ text: Text) -> some View {
        text
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var filterRow: some View {
        MenuPickerRow(
            title: Text("Category", comment: "History: category filter and entry editor field"),
            valueText: filter.map { Text(verbatim: $0.title(locale: locale)) }
                ?? Text("All", comment: "History: category filter value that shows every category"),
            selection: $filter
        ) {
            Text("All", comment: "History: category filter value that shows every category")
                .tag(MaintenanceCategory?.none)
            ForEach(MaintenanceCategory.allCases, id: \.self) { category in
                Text(verbatim: category.title(locale: locale)).tag(MaintenanceCategory?.some(category))
            }
        }
        .accessibilityIdentifier("historyFilter")
    }

    private var addRow: some View {
        Label {
            Text("Add entry", comment: "History: button to add a new entry")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "plus.circle")
        }
        .foregroundStyle(Color.accentColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { edit { editorTarget = .new() } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { edit { editorTarget = .new() } }
        .accessibilityIdentifier("addEntryButton")
    }

    private var addFromReceiptRow: some View {
        let locked = !entitlements.canScanReceipts
        let title = Text("Add from receipt", comment: "History: button that scans a workshop receipt and creates a new entry from it")
        return ActionRow(
            title: title, systemImage: "doc.text.viewfinder", showsProBadge: locked,
            identifier: "addFromReceiptRow",
            accessibilityLabelText: locked
                ? Text("Add from receipt, requires Wagemo Pro", comment: "VoiceOver label of the receipt scan row while the user has no Pro")
                : nil
        ) { startScan() }
    }

    private var exportRow: some View {
        let locked = !entitlements.canExportServiceRecord
        let title = Text("Export service record", comment: "History: button that creates a PDF service record of the vehicle")
        return ActionRow(
            title: title, systemImage: "doc.richtext", showsProBadge: locked,
            identifier: "exportServiceRecordRow",
            accessibilityLabelText: locked
                ? Text("Export service record, requires Wagemo Pro", comment: "VoiceOver label of the service record row while the user has no Pro")
                : nil
        ) { startExport() }
    }

    /// Reading a record is not an edit, so it works on read-only vehicles too, but it is a Pro feature.
    private func startExport() {
        guard entitlements.canExportServiceRecord else {
            paywall = .serviceRecordExport
            return
        }
        showingServiceRecord = true
    }

    private func startScan() {
        guard entitlements.canScanReceipts else {
            paywall = .receiptScan
            return
        }
        edit {
            let infos = allVehicles.filter { !$0.isArchived || $0.id == vehicle.id }.map { ReceiptVehicleInfo($0) }
            scan.start(ReceiptScanInput(vehicles: infos, contextVehicleID: vehicle.id, vehicleIsFixed: false))
        }
    }

    /// The review's vehicle picker may have chosen another vehicle than the one this screen shows.
    private func createEntry(from application: ReceiptApplication, attachment: ReceiptAttachment?) {
        let target = allVehicles.first { $0.id == application.vehicleID } ?? vehicle
        ReceiptEntryWriter.createEntry(from: application, attachment: attachment, vehicle: target, in: modelContext)
    }

    // MARK: Rows

    private func row(_ entry: MaintenanceEntry) -> some View {
        let presentation = HistoryRowPresentation(entry: entry, locale: locale)
        return HistoryRow(presentation: presentation)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { edit { editorTarget = .edit(entry) } }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: presentation.accessibilityLabel.withoutSoftHyphens))
            .accessibilityHint(Text("Opens the entry for editing.", comment: "VoiceOver hint of a history row"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { edit { editorTarget = .edit(entry) } }
            .accessibilityAction(named: Text("Delete", comment: "Swipe action to delete a reminder")) {
                confirmDelete(entry)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    confirmDelete(entry)
                } label: {
                    Label {
                        Text("Delete", comment: "Swipe action to delete a reminder")
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
                Button {
                    edit { editorTarget = .edit(entry) }
                } label: {
                    Label {
                        Text("Edit", comment: "Swipe action to edit a reminder")
                    } icon: {
                        Image(systemName: "pencil")
                    }
                }
                .tint(.indigo)
            }
    }

    private func confirmDelete(_ entry: MaintenanceEntry) {
        edit {
            entryToDelete = entry
            showingDeleteConfirmation = true
        }
    }
}

/// One entry of the timeline: category with icon, date, workshop, work summary and amount.
struct HistoryRow: View {
    let presentation: HistoryRowPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AmountLayout {
                Label {
                    Text(verbatim: presentation.categoryTitle)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: presentation.entry.category.iconName)
                }
                .font(.headline)
            } trailing: {
                if let amount = presentation.amountText {
                    Text(verbatim: amount)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(verbatim: presentation.dateText)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if let workshop = presentation.workshop {
                Text(verbatim: workshop)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let summary = presentation.workSummary {
                Text(verbatim: summary)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if presentation.receiptCount > 0 {
                Label {
                    Text("\(presentation.receiptCount) receipts", comment: "History row: number of attached receipts, plural")
                } icon: {
                    Image(systemName: "paperclip")
                }
                .font(.subheadline)
            }
        }
    }
}
