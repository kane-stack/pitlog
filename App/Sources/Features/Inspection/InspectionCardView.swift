import PitlogCore
import SwiftUI

/// The Pickerl card: due month, window, phase and the legal notice (always visible).
struct InspectionCardView: View {
    let vehicle: Vehicle
    let outcome: InspectionService.Outcome
    let today: DayDate
    var onRecordInspection: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("§57a inspection", comment: "Title of the Pickerl card (periodic vehicle inspection)")
                .font(.headline)

            switch outcome {
            case .available(let status):
                available(status)
            case .unavailable(let reason):
                unavailable(reason)
            }

            LegalNoticeView()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Available

    @ViewBuilder
    private func available(_ status: InspectionStatus) -> some View {
        let presentation = InspectionPresentation(status: status, today: today, locale: locale)
        let noteTexts = status.notes.map { RuleNoteText.text(for: $0, locale: locale) }

        VStack(alignment: .leading, spacing: 8) {
            (status.dueMonthSource == .plaque
                ? Text("Due", comment: "Pickerl card: caption above the due month")
                : Text("Estimated due", comment: "Pickerl card: caption above an estimated due month"))
                .font(.subheadline)

            Text(presentation.dueMonthText)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("From \(presentation.windowOpensText) to \(presentation.windowClosesText)", comment: "Pickerl card: inspection window, from the first to the last day")

            Label(presentation.phaseText, systemImage: presentation.iconName)
                .fontWeight(.semibold)

            Text(presentation.daysText)
                .font(.subheadline)

            ForEach(Array(noteTexts.enumerated()), id: \.offset) { _, text in
                Label(text, systemImage: "info.circle")
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let exchange = presentation.exchangeSuggestionText {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exchange)
                        if let availability = presentation.exchangeAvailabilityText {
                            Text(availability)
                        }
                    }
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            }

            Text("Rule version \(status.ruleVersion)", comment: "Pickerl card: version of the rule set, small print")
                .font(.footnote)
        }
        // One combined element that spells out due month, last day and status for VoiceOver.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            ([presentation.accessibilityLabel] + noteTexts
                + [presentation.exchangeSuggestionText, presentation.exchangeAvailabilityText].compactMap { $0 })
                .joined(separator: " "))

        recordButton
    }

    // MARK: Unavailable

    @ViewBuilder
    private func unavailable(_ reason: InspectionService.UnavailableReason) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(reason.text(locale: locale), systemImage: "questionmark.circle")
            if let plaque = vehicle.plaque {
                Text("Inspection sticker: \(plaque.displayString(locale: locale))", comment: "Pickerl card: the sticker month entered by the user when no deadline is calculated")
                    .fontWeight(.semibold)
            }
        }
    }

    private var recordButton: some View {
        Button(action: onRecordInspection) {
            Label {
                Text("Record inspection", comment: "Button on the Pickerl card to record a completed inspection")
            } icon: {
                Image(systemName: "checkmark.circle")
            }
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("recordInspectionButton")
    }
}
