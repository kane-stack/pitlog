import PitlogCore
import SwiftData
import SwiftUI

/// The result of a receipt scan, field by field. Every value shows its text snippet and how sure the scan is
/// (icon and words, never colour alone). The user accepts, edits or discards each value, and picks one of two
/// readings where they disagree. Nothing is saved here: the caller turns the application into an entry.
struct ReceiptReviewView: View {
    @State private var review: ReceiptReview
    let mode: ReceiptReviewMode
    let hasAttachment: Bool
    let onConfirm: (ReceiptApplication) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @State private var plaqueTarget: PlaqueUpdateTarget?

    init(
        review: ReceiptReview, mode: ReceiptReviewMode, hasAttachment: Bool,
        onConfirm: @escaping (ReceiptApplication) -> Void
    ) {
        _review = State(initialValue: review)
        self.mode = mode
        self.hasAttachment = hasAttachment
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            Form {
                introSection
                vehicleSection
                ForEach($review.items) { $item in
                    Section {
                        ReceiptReviewRow(item: $item, review: $review)
                    }
                }
                plaqueSection
                if hasAttachment {
                    Section {
                        ReceiptReviewNote(
                            text: Text("The scan is attached to the entry as a receipt. The name and address of the customer are not kept in its text.", comment: "Receipt review: what happens with the scanned pages"),
                            systemImage: "paperclip")
                    }
                }
            }
            .navigationTitle(Text("Check the receipt", comment: "Navigation title of the receipt review"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Cancel button of a form")
                    }
                    .accessibilityIdentifier("receiptReviewCancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onConfirm(review.application)
                        dismiss()
                    } label: {
                        switch mode {
                        case .saveEntry:
                            Text("Add entry", comment: "History: button to add a new entry")
                        case .fillForm:
                            Text("Apply", comment: "Registration review: copies the switched-on values into the vehicle form")
                        }
                    }
                    .disabled(!review.canApply)
                    .accessibilityIdentifier("receiptReviewApplyButton")
                }
            }
            .sheet(item: $plaqueTarget) { target in
                PlaqueUpdateView(vehicle: target.vehicle, suggestion: target.month)
            }
        }
    }

    // MARK: Sections

    private var introSection: some View {
        Section {
            Text(introText)
                .fixedSize(horizontal: false, vertical: true)
            if review.isCreditNote {
                ReceiptReviewNote(
                    text: Text("This looks like a credit note or a cancellation. No amount was taken over.", comment: "Receipt review: notice when the receipt is a credit note"),
                    systemImage: "info.circle")
            }
            if review.items.isEmpty {
                ReceiptReviewNote(
                    text: Text("Nothing could be read from this receipt.", comment: "Receipt review: notice when no field was found"),
                    systemImage: "info.circle")
            }
        }
    }

    private var introText: LocalizedStringResource {
        switch mode {
        case .saveEntry:
            LocalizedStringResource("Check what was read from your receipt. Only values that are switched on go into the new entry.", comment: "Receipt review: introduction when the review creates a new entry")
        case .fillForm:
            LocalizedStringResource("Check what was read from your receipt. Only values that are switched on are copied into the entry. Nothing is saved until you tap Save.", comment: "Receipt review: introduction when the review fills the entry form")
        }
    }

    @ViewBuilder
    private var vehicleSection: some View {
        Section {
            if !review.vehicleIsFixed {
                MenuPickerRow(
                    title: Text("Vehicle", comment: "Receipt review: which vehicle the entry belongs to"),
                    valueText: vehicleName.map { Text(verbatim: $0) }
                        ?? Text("Choose a vehicle", comment: "Receipt review: picker value while no vehicle is chosen"),
                    selection: $review.vehicleID
                ) {
                    ForEach(review.vehicles) { vehicle in
                        Text(verbatim: vehicle.displayName).tag(UUID?.some(vehicle.id))
                    }
                }
                .accessibilityIdentifier("receiptVehicle")
            }
            vehicleStatusNote
            if let plate = review.receiptPlate {
                receiptIdentifier(
                    Text("License plate on the receipt: \(shown(plate))", comment: "Receipt review: the license plate read from the receipt; the argument is the plate"))
            }
            if let vin = review.receiptVIN {
                receiptIdentifier(
                    Text("VIN on the receipt: \(shown(vin))", comment: "Receipt review: the vehicle identification number read from the receipt; the argument is the VIN"))
            }
        }
    }

    private var vehicleName: String? {
        review.vehicles.first { $0.id == review.vehicleID }?.displayName
    }

    /// The readings of an identifier, joined if the readers disagree.
    private func shown(_ field: MergedField<String>) -> String {
        field.candidates.map(\.value).joined(separator: " / ")
    }

    private func receiptIdentifier(_ text: Text) -> some View {
        text
            .font(.footnote)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var vehicleStatusNote: some View {
        switch review.vehicleStatus {
        case .matches(.vin):
            ReceiptReviewNote(
                text: Text("The VIN on the receipt matches this vehicle.", comment: "Receipt review: the VIN of the receipt belongs to the selected vehicle"),
                systemImage: "checkmark.circle")
        case .matches(.plate):
            ReceiptReviewNote(
                text: Text("The license plate on the receipt matches this vehicle.", comment: "Receipt review: the license plate of the receipt belongs to the selected vehicle"),
                systemImage: "checkmark.circle")
        case .differs:
            ReceiptReviewNote(
                text: Text("The license plate or VIN on the receipt does not match this vehicle. Check that the receipt belongs to it.", comment: "Receipt review: warning when the receipt seems to belong to another vehicle"),
                systemImage: "exclamationmark.triangle")
        case .unknown:
            ReceiptReviewNote(
                text: Text("The receipt shows no license plate or VIN. Check that it belongs to this vehicle.", comment: "Receipt review: notice when the receipt does not name a vehicle"),
                systemImage: "info.circle")
        }
    }

    /// A § 57a receipt may state the new sticker month. It is a hint only: the sticker itself is authoritative
    /// (ADR-5), so nothing is changed unless the user does it in the picker.
    @ViewBuilder
    private var plaqueSection: some View {
        if let month = review.suggestedPlaque, let vehicle = selectedVehicle {
            Section {
                ReceiptReviewNote(
                    text: Text("The receipt states the new inspection sticker: \(month.displayString(locale: locale)). Your sticker is not changed unless you do it yourself.", comment: "Receipt review: hint with the month a § 57a receipt says was punched; the argument is the month"),
                    systemImage: "checkmark.seal")
                Button {
                    plaqueTarget = PlaqueUpdateTarget(vehicle: vehicle, month: month)
                } label: {
                    Label {
                        Text("Update sticker month…", comment: "Receipt review: opens the sticker picker, prefilled with the month from the receipt")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "calendar.badge.checkmark")
                    }
                }
                .accessibilityIdentifier("receiptUpdatePlaqueButton")
            }
        }
    }

    private var selectedVehicle: Vehicle? {
        guard let id = review.vehicleID else { return nil }
        return try? modelContext.fetch(FetchDescriptor<Vehicle>(predicate: #Predicate { $0.id == id })).first
    }
}

struct PlaqueUpdateTarget: Identifiable {
    let id = UUID()
    let vehicle: Vehicle
    let month: YearMonth
}

/// One scanned value: the switch, the editor, how sure the scan is with the snippet, and the other reading.
private struct ReceiptReviewRow: View {
    @Binding var item: ReceiptReviewItem
    @Binding var review: ReceiptReview

    @Environment(\.locale) private var locale

    var body: some View {
        Toggle(isOn: $item.included) {
            Text(item.field.useTitle)
        }
        .accessibilityIdentifier("receiptToggle-\(item.field.rawValue)")

        editor

        if item.field == .odometer {
            ReceiptReviewNote(
                text: Text("Also saved as an odometer reading if it is newer than your latest one.", comment: "Receipt review: what happens with the scanned odometer reading"),
                systemImage: "gauge.with.dots.needle.50percent")
        }

        confidenceRow

        if item.choices.count > 1 {
            choicePicker
        }
    }

    /// Editing a value is a decision to use it: the switch turns on.
    private func edited<Value>(_ keyPath: WritableKeyPath<ReceiptReviewItem, Value>) -> Binding<Value> {
        Binding(
            get: { item[keyPath: keyPath] },
            set: {
                item[keyPath: keyPath] = $0
                item.included = true
            })
    }

    @ViewBuilder
    private var editor: some View {
        switch item.field {
        case .date:
            DatePicker(
                selection: Binding(
                    get: { CalendarDay.date(from: item.day ?? CalendarDay.today(in: .current), in: .current) },
                    set: {
                        item.day = CalendarDay.dayDate(from: $0, in: .current)
                        item.included = true
                    }),
                displayedComponents: .date
            ) {
                Text(item.field.title)
            }
        case .amount:
            LabeledContent {
                HStack {
                    TextField(text: edited(\.text), prompt: Text(verbatim: "")) {
                        Text(item.field.title)
                    }
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .accessibilityLabel(Text(item.field.title))
                    .accessibilityIdentifier("receiptAmount")
                    // Primary on purpose: the secondary color of a value next to a field fails the contrast audit.
                    Text(verbatim: item.currency)
                        .foregroundStyle(.primary)
                }
            } label: {
                Text(item.field.title)
                    .foregroundStyle(.primary)
            }
            if item.included, MoneyFormat.parse(item.text, currency: item.currency, locale: locale) == .invalid {
                ReceiptReviewNote(
                    text: Text("Enter the amount as a number, for example 120.50.", comment: "Entry editor: the amount field does not contain a valid number"),
                    systemImage: "exclamationmark.triangle")
            }
        case .workshop:
            FormTextField(title: Text(item.field.title), text: edited(\.text))
        case .category:
            MenuPickerRow(
                title: Text(item.field.title),
                valueText: Text(verbatim: item.category.title(locale: locale)),
                selection: edited(\.category)
            ) {
                ForEach(MaintenanceCategory.allCases, id: \.self) { category in
                    Text(verbatim: category.title(locale: locale)).tag(category)
                }
            }
        case .workItems:
            FormMultilineTextField(title: Text(item.field.title), text: edited(\.text))
        case .odometer:
            FormNumberField(title: Text(item.field.title), value: edited(\.kilometers))
        }
    }

    /// Icon and words, never colour alone. One element for VoiceOver: confidence, note, then the snippet.
    private var confidenceRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(item.confidence.title)
            } icon: {
                Image(systemName: item.confidence.symbolName)
            }
            .font(.subheadline.weight(.semibold))
            if let note = item.agreement.note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.primary)
            }
            if let source = item.sourceText(locale: locale) {
                Text(verbatim: source)
                    .font(.footnote)
                    // Primary on purpose: secondary text fails the contrast audit on the grouped background.
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("receiptConfidence-\(item.field.rawValue)")
    }

    /// All readings; choosing one takes it over and switches the value on.
    private var choicePicker: some View {
        MenuPickerRow(
            title: Text("Reading", comment: "Receipt review: picker to choose between two readings of one field"),
            valueText: Text(verbatim: selectedChoiceText),
            selection: Binding(
                get: { item.selectedChoice },
                set: { review.choose($0, for: item.field) })
        ) {
            ForEach(Array(item.choices.enumerated()), id: \.offset) { offset, choice in
                Text("\(String(localized: choice.source.title)): \(choice.value.displayText(locale: locale))", comment: "Receipt review: one reading in the list of readings. First argument: who read it, second: the value")
                    .tag(offset)
            }
        }
        .accessibilityIdentifier("receiptChoice-\(item.field.rawValue)")
    }

    private var selectedChoiceText: String {
        guard item.choices.indices.contains(item.selectedChoice) else { return "" }
        let choice = item.choices[item.selectedChoice]
        return "\(String(localized: choice.source.title)): \(choice.value.displayText(locale: locale))"
    }
}

/// Icon plus text that wraps at every Dynamic Type size, without shrinking.
private struct ReceiptReviewNote: View {
    let text: Text
    let systemImage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            text
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.footnote)
    }
}
