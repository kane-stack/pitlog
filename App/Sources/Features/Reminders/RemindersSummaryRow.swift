import PitlogCore
import SwiftUI

/// The vehicle detail's entry to the reminders: the next one at a glance.
struct RemindersSummaryRow: View {
    let vehicle: Vehicle
    let today: DayDate

    @Environment(\.locale) private var locale

    private var next: ReminderPresentation? {
        (vehicle.reminders ?? [])
            .filter(\.isEnabled)
            .map { ReminderPresentation(reminder: $0, vehicle: vehicle, today: today, locale: locale) }
            .compactMap { $0.sortDay == nil ? nil : $0 }
            .min { ($0.sortDay ?? today) < ($1.sortDay ?? today) }
    }

    var body: some View {
        NavigationLink {
            RemindersView(vehicle: vehicle)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text("Reminders", comment: "Section header on the vehicle detail: reminders")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "bell")
                }
                .font(.headline)
                if let next {
                    Text(verbatim: "\(next.title) · \(next.relativeText ?? next.dueText)")
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Tyres, service, vignette and more.", comment: "Vehicle detail: reminders row when there is no upcoming reminder")
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: label))
        }
        .accessibilityIdentifier("remindersRow")
    }

    private var label: String {
        let title = String(localized: "Reminders", locale: locale, comment: "Section header on the vehicle detail: reminders")
        guard let next else { return title }
        return "\(title). \(next.accessibilityLabel)"
    }
}
