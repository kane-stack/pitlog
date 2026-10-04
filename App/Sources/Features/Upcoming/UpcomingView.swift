import PitlogCore
import SwiftData
import SwiftUI

struct UpcomingView: View {
    @Query(filter: #Predicate<Vehicle> { !$0.isArchived }, sort: \Vehicle.createdAt)
    private var vehicles: [Vehicle]
    @Environment(\.locale) private var locale

    private let service = InspectionService()

    private struct Row: Identifiable {
        let vehicle: Vehicle
        let status: InspectionStatus
        var id: PersistentIdentifier { vehicle.persistentModelID }
    }

    var body: some View {
        let today = CalendarDay.today(in: CalendarDay.austria)
        let rows: [Row] = vehicles
            .compactMap { vehicle in
                service.evaluate(vehicle, today: today).status.map { Row(vehicle: vehicle, status: $0) }
            }
            .sorted { $0.status.window.closes < $1.status.window.closes }

        List {
            Section {
                ForEach(rows) { row in
            let presentation = InspectionPresentation(status: row.status, today: today, locale: locale)
            NavigationLink(value: row.vehicle) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.vehicle.displayName)
                        .font(.headline)
                    Text("Due \(presentation.dueMonthText)", comment: "Upcoming list: due month of the inspection")
                    Label(presentation.badgeText, systemImage: presentation.iconName)
                        .font(.subheadline)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "\(row.vehicle.displayName). \(presentation.badgeAccessibilityLabel)"))
            }
                }
            } footer: {
                // Part of the list content, so it never sits under the tab bar (contrast audit).
                if !rows.isEmpty { LegalNoticeView() }
            }
        }
        .overlay {
            if rows.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("Nothing due", comment: "Empty state title on the Upcoming tab")
                    } icon: {
                        Image(systemName: "calendar")
                    }
                } description: {
                    Text(
                        "Upcoming inspections and reminders for all your vehicles will appear here.",
                        comment: "Empty state description on the Upcoming tab"
                    )
                }
            }
        }
        .navigationTitle(Text("Upcoming", comment: "Navigation title of the Upcoming tab"))
        .navigationDestination(for: Vehicle.self) { vehicle in
            VehicleDetailView(vehicle: vehicle)
        }
    }
}
