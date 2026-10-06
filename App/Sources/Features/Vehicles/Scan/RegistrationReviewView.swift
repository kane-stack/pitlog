import PitlogCore
import SwiftUI

/// The result of a scan, field by field. The user accepts, edits or discards each value; "Apply" fills the
/// vehicle form with what is switched on. Nothing is saved here.
struct RegistrationReviewView: View {
    @State private var review: RegistrationReview
    let onApply: (RegistrationPrefill) -> Void

    @Environment(\.dismiss) private var dismiss
    #if DEBUG
    private var recognizedPages: [[RecognizedLine]] = []
    @State private var copiedLines = false
    #endif

    init(review: RegistrationReview, onApply: @escaping (RegistrationPrefill) -> Void) {
        _review = State(initialValue: review)
        self.onApply = onApply
    }

    #if DEBUG
    init(
        review: RegistrationReview, recognizedPages: [[RecognizedLine]],
        onApply: @escaping (RegistrationPrefill) -> Void
    ) {
        self.init(review: review, onApply: onApply)
        self.recognizedPages = recognizedPages
    }
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Check what was read from your certificate. Only values that are switched on are copied into the form. Nothing is saved until you tap Save.", comment: "Registration review: introduction")
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(RegistrationScanNotice.allCases.filter { review.notices.contains($0) }, id: \.self) { notice in
                        ReviewNote(text: Text(notice.text), systemImage: "info.circle")
                    }
                }

                ForEach($review.items) { $item in
                    Section {
                        RegistrationReviewRow(item: $item)
                    }
                }

                Section {
                    ReviewNote(
                        text: Text("The punched month on the inspection sticker is not on the certificate. Enter it from the sticker itself.", comment: "Registration review: hint that the sticker punch must be entered by hand"),
                        systemImage: "circle.dashed")
                }

                #if DEBUG
                debugSection
                #endif
            }
            .navigationTitle(Text("Check the scan", comment: "Navigation title of the registration review"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Cancel button of a form")
                    }
                    .accessibilityIdentifier("registrationReviewCancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onApply(review.prefill)
                        dismiss()
                    } label: {
                        Text("Apply", comment: "Registration review: copies the switched-on values into the vehicle form")
                    }
                    .disabled(!review.hasSelection)
                    .accessibilityIdentifier("registrationReviewApplyButton")
                }
            }
        }
    }
}

#if DEBUG
extension RegistrationReviewView {
    /// Debug builds only, never in Release: copies the recognized lines for diagnosing a real certificate.
    /// Plain English on purpose, like the other developer tools.
    fileprivate var debugSection: some View {
        Section {
            Button {
                UIPasteboard.general.string = RecognizedLinesDump.text(from: recognizedPages)
                copiedLines = true
            } label: {
                Text(verbatim: "Copy recognized lines")
            }
            .accessibilityIdentifier("registrationCopyLinesButton")
            if copiedLines {
                Text(verbatim: "Copied to the clipboard.")
                    .font(.footnote)
                    .accessibilityIdentifier("registrationCopiedLines")
            }
        } header: {
            Text(verbatim: "Debug")
        } footer: {
            Text(verbatim: "Copies every recognized line with its box coordinates. The text can contain the holder's name and address: redact them before you pass it on.")
        }
    }
}
#endif

/// One scanned value: the switch, the editor, and how sure the scan is, with the snippet it was read from.
private struct RegistrationReviewRow: View {
    @Binding var item: RegistrationReviewItem

    @Environment(\.locale) private var locale

    var body: some View {
        Toggle(isOn: $item.included) {
            Text(item.field.useTitle)
        }
        .accessibilityIdentifier("registrationToggle-\(item.field.rawValue)")

        editor

        if item.field == .category, item.category == .other {
            ReviewNote(
                text: Text(InspectionService.UnavailableReason.unsupportedCategory.text(locale: locale)),
                systemImage: "info.circle")
        }

        confidenceRow
    }

    /// Editing a value is a decision to use it: the switch turns on.
    private func edited<Value>(_ keyPath: WritableKeyPath<RegistrationReviewItem, Value>) -> Binding<Value> {
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
        case .licensePlate:
            FormTextField(title: Text(item.field.title), text: edited(\.text))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
        case .vin:
            FormTextField(title: Text(item.field.title), text: edited(\.text))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
        case .make, .model:
            FormTextField(title: Text(item.field.title), text: edited(\.text))
        case .category:
            MenuPickerRow(
                title: Text(item.field.title),
                valueText: Text(item.category.title),
                selection: edited(\.category)
            ) {
                ForEach(VehicleCategory.allCases, id: \.self) { category in
                    Text(category.title).tag(category)
                }
            }
        case .firstRegistration:
            MenuPickerRow(
                title: Text("First registration, month", comment: "Vehicle form: month of the first registration"),
                valueText: item.month.map { Text(YearMonth.monthName($0, locale: locale)) }
                    ?? Text("Not set", comment: "Picker option for no month"),
                selection: edited(\.month)
            ) {
                Text("Not set", comment: "Picker option for no month").tag(Int?.none)
                ForEach(1...12, id: \.self) { month in
                    Text(YearMonth.monthName(month, locale: locale)).tag(Int?.some(month))
                }
            }
            MenuPickerRow(
                title: Text("First registration, year", comment: "Vehicle form: year of the first registration"),
                valueText: item.year.map { Text($0, format: .number.grouping(.never)) }
                    ?? Text("Not set", comment: "Picker option for no year"),
                selection: edited(\.year)
            ) {
                Text("Not set", comment: "Picker option for no year").tag(Int?.none)
                ForEach((1950...CalendarDay.today(in: CalendarDay.austria).year).reversed(), id: \.self) { year in
                    Text(year, format: .number.grouping(.never)).tag(Int?.some(year))
                }
            }
        }
    }

    /// Icon and words, never colour alone. One element for VoiceOver: confidence, then the snippet.
    private var confidenceRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(item.confidence.title)
            } icon: {
                Image(systemName: item.confidence.symbolName)
            }
            .font(.subheadline.weight(.semibold))
            Text("Read as “\(item.rawText)” (field \(item.source))", comment: "Registration review: the text a value was read from. First argument: the text, second: the field code on the certificate")
                .font(.footnote)
                // Primary on purpose: secondary text fails the contrast audit on the grouped background.
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("registrationConfidence-\(item.field.rawValue)")
    }
}

/// Icon plus text that wraps at every Dynamic Type size, without shrinking.
private struct ReviewNote: View {
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

/// Texts shared by the review and the problem alert.
enum RegistrationScanNoticeTexts {
    static let transferPermit = RegistrationScanNotice.transferPermit.text
}
