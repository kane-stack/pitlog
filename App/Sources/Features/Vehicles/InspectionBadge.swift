import PitlogCore
import SwiftUI

/// Status badge: icon plus text, never color only.
struct InspectionBadge: View {
    let outcome: InspectionService.Outcome
    let today: DayDate
    @Environment(\.locale) private var locale

    var body: some View {
        switch outcome {
        case .available(let status):
            let presentation = InspectionPresentation(status: status, today: today, locale: locale)
            Label(presentation.badgeText, systemImage: presentation.iconName)
                .font(.subheadline)
                .fontWeight(status.phase == .overdue ? .bold : .regular)
                .accessibilityLabel(presentation.badgeAccessibilityLabel.withoutSoftHyphens)
        case .unavailable(let reason):
            Label(reason.text(locale: locale), systemImage: "questionmark.circle")
                .font(.subheadline)
        }
    }
}
