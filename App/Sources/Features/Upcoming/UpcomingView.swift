import PitlogCore
import SwiftData
import SwiftUI

/// Inspection deadlines and reminders of all vehicles, in one list sorted by date.
struct UpcomingView: View {
    @Query(filter: #Predicate<Vehicle> { !$0.isArchived }, sort: \Vehicle.createdAt)
    private var vehicles: [Vehicle]
    @Environment(\.locale) private var locale
    @Environment(\.entitlements) private var entitlements

    private let service = InspectionService()

    /// One row: type and icon are always text, never color alone.
    private struct Item: Identifiable {
        let id: String
        let vehicle: Vehicle
        let typeTitle: String
        let iconName: String
        let lines: [String]
        /// `nil` sorts last (a service by odometer without an estimate).
        let sortDay: DayDate?
        let accessibilityLabel: String
    }

    private func items(today: DayDate, reminderToday: DayDate) -> [Item] {
        var result: [Item] = []
        for vehicle in vehicles {
            if let status = service.evaluate(vehicle, today: today).status {
                let presentation = InspectionPresentation(status: status, today: today, locale: locale)
                let typeTitle = String(localized: "Inspection", locale: locale, comment: "Notification title part: the periodic vehicle inspection (Pickerl)")
                let due = String(localized: "Due \(presentation.dueMonthText)", locale: locale, comment: "Upcoming list: due month of the inspection")
                result.append(
                    Item(
                        id: "\(vehicle.id.uuidString)/inspection", vehicle: vehicle, typeTitle: typeTitle,
                        iconName: "checkmark.seal", lines: [due, presentation.badgeText],
                        sortDay: status.window.closes,
                        accessibilityLabel: "\(vehicle.displayName). \(typeTitle). \(presentation.badgeAccessibilityLabel)"))
            }
            // Reminders of the Pro kinds are not planned without Pro, so they are not "upcoming" either.
            // They stay in the reminder list of the vehicle.
            for reminder in vehicle.reminders ?? [] where reminder.isEnabled && entitlements.canUseProReminders {
                let presentation = ReminderPresentation(
                    reminder: reminder, vehicle: vehicle, today: reminderToday, locale: locale)
                result.append(
                    Item(
                        id: "\(vehicle.id.uuidString)/\(reminder.id.uuidString)", vehicle: vehicle,
                        typeTitle: presentation.title, iconName: presentation.iconName,
                        lines: [presentation.dueText] + (presentation.relativeText.map { [$0] } ?? []),
                        sortDay: presentation.sortDay,
                        accessibilityLabel: "\(vehicle.displayName). \(presentation.accessibilityLabel)"))
            }
        }
        return result.sorted { lhs, rhs in
            switch (lhs.sortDay, rhs.sortDay) {
            case let (left?, right?) where left != right: return left < right
            case (_?, nil): return true
            case (nil, _?): return false
            default: return lhs.id < rhs.id
            }
        }
    }

    var body: some View {
        let today = CalendarDay.today(in: CalendarDay.austria)
        let items = items(today: today, reminderToday: CalendarDay.today(in: .current))

        VStack(spacing: 0) {
            if vehicles.contains(where: { service.evaluate($0, today: today).status != nil }) {
                // Above the list, away from the floating tab bar (contrast) and outside the list cells.
                LegalNoticeView()
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            List {
                Section {
                    ForEach(items) { item in
                        NavigationLink(value: item.vehicle) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.vehicle.displayName)
                                    .font(.headline)
                                Label(item.typeTitle, systemImage: item.iconName)
                                ForEach(Array(item.lines.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.subheadline)
                                }
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(verbatim: item.accessibilityLabel.withoutSoftHyphens))
                        }
                    }
                }
            }
            .scrollEdgeEffectStyle(.hard, for: .bottom)
            .overlay {
                if items.isEmpty {
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
        }
        .navigationTitle(Text("Upcoming", comment: "Navigation title of the Upcoming tab"))
        .navigationDestination(for: Vehicle.self) { vehicle in
            VehicleDetailView(vehicle: vehicle)
        }
    }
}
