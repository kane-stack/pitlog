import PitlogCore
import SwiftUI

/// The vehicle detail's entry to the history: how many entries and the latest one at a glance.
struct HistorySummaryRow: View {
    let vehicle: Vehicle

    @Environment(\.locale) private var locale

    private var entries: [MaintenanceEntry] { vehicle.maintenanceEntries ?? [] }
    private var latest: MaintenanceEntry? { HistoryTimeline.sorted(entries).first }

    var body: some View {
        NavigationLink {
            HistoryView(vehicle: vehicle)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text("History", comment: "Section header on the vehicle detail: maintenance history and costs")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .font(.headline)
                Text(verbatim: subtitle)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: accessibilityText.withoutSoftHyphens))
        }
        .accessibilityIdentifier("historyRow")
    }

    private var countText: String {
        String(localized: "\(entries.count) entries", locale: locale, comment: "Vehicle detail: number of history entries, plural")
    }

    private var subtitle: String {
        guard let latest else {
            return String(localized: "Service, repairs and costs.", locale: locale, comment: "Vehicle detail: history row when there are no entries yet")
        }
        let date = latest.date.formatted(.abbreviated, locale: locale)
        return "\(countText) · \(String(localized: "last \(date)", locale: locale, comment: "Vehicle detail: date of the latest history entry, after the number of entries. Argument: the date"))"
    }

    private var accessibilityText: String {
        let title = String(localized: "History", locale: locale, comment: "Section header on the vehicle detail: maintenance history and costs")
        guard let latest else { return "\(title). \(subtitle)" }
        let date = latest.date.formatted(.long, locale: locale)
        let last = String(localized: "Latest entry on \(date)", locale: locale, comment: "VoiceOver: date of the latest history entry. Argument: the date")
        return "\(title). \(countText). \(last)"
    }
}
