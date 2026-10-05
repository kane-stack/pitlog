import PitlogCore
import SwiftData
import SwiftUI

/// What the reminder editor sheet opens: a new reminder of a category, or an existing one.
struct ReminderEditorTarget: Identifiable {
    let id = UUID()
    let category: ReminderCategory
    let reminder: Reminder?
}

/// The "Reminders" section of the vehicle detail list: inspection toggle, stored reminders and add button.
/// Meant to be placed directly inside a `List`.
struct RemindersSection: View {
    let vehicle: Vehicle
    let today: DayDate
    @Binding var editorTarget: ReminderEditorTarget?
    @Binding var showingPermissionPrompt: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(NotificationPermission.self) private var permission

    private let builder = ReminderScheduleBuilder()

    private var presentations: [ReminderPresentation] {
        (vehicle.reminders ?? [])
            .map { ReminderPresentation(reminder: $0, vehicle: vehicle, today: today, locale: locale) }
            .sorted { lhs, rhs in
                switch (lhs.sortDay, rhs.sortDay) {
                case let (left?, right?): left < right
                case (nil, _?): false
                case (_?, nil): true
                case (nil, nil): lhs.title < rhs.title
                }
            }
    }

    var body: some View {
        Section {
            inspectionToggle
            ForEach(presentations, id: \.reminder.persistentModelID) { presentation in
                row(presentation)
            }
            addMenu
            if hasActiveReminders {
                NotificationPermissionRow()
            }
        } header: {
            // Primary color: the secondary header color fails the contrast audit.
            Text("Reminders", comment: "Section header on the vehicle detail: reminders")
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var hasActiveReminders: Bool {
        vehicle.inspectionRemindersEnabled || (vehicle.reminders ?? []).contains { $0.isEnabled }
    }

    // MARK: Inspection toggle

    private var inspectionToggle: some View {
        Toggle(
            isOn: Binding(
                get: { vehicle.inspectionRemindersEnabled },
                set: { newValue in
                    vehicle.inspectionRemindersEnabled = newValue
                    if newValue, permission.state == .notDetermined { showingPermissionPrompt = true }
                })
        ) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Inspection reminders", comment: "Toggle on the vehicle detail: notifications for the inspection deadline")
                Text(
                    "When the window opens, a month ahead, in the due month and a week before the window closes. Check the date on your sticker.",
                    comment: "Explanation below the inspection reminders toggle"
                )
                .font(.footnote)
            }
        }
        .accessibilityIdentifier("inspectionRemindersToggle")
    }

    // MARK: Rows

    private func row(_ presentation: ReminderPresentation) -> some View {
        let reminder = presentation.reminder
        return Button {
            editorTarget = ReminderEditorTarget(category: reminder.category, reminder: reminder)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label(presentation.title, systemImage: presentation.iconName)
                    .font(.headline)
                Text(presentation.dueText)
                    .font(.subheadline)
                if let relative = presentation.relativeText {
                    Text(relative)
                        .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: presentation.accessibilityLabel))
        .accessibilityHint(Text("Opens the reminder for editing.", comment: "VoiceOver hint of a reminder row"))
        .accessibilityAddTraits(.isButton)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if reminder.isEnabled {
                Button {
                    markDone(reminder)
                } label: {
                    Label {
                        Text("Done", comment: "Swipe action: mark a reminder as done")
                    } icon: {
                        Image(systemName: "checkmark.circle")
                    }
                }
                .tint(.green)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                modelContext.delete(reminder)
            } label: {
                Label {
                    Text("Delete", comment: "Swipe action to delete a reminder")
                } icon: {
                    Image(systemName: "trash")
                }
            }
            Button {
                editorTarget = ReminderEditorTarget(category: reminder.category, reminder: reminder)
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

    private func markDone(_ reminder: Reminder) {
        reminder.complete(
            vehicleID: vehicle.id.uuidString,
            projection: vehicle.odometerProjection,
            defaults: builder.defaults(for: vehicle),
            today: today,
            km: vehicle.currentOdometerKm)
    }

    // MARK: Add

    private var addMenu: some View {
        Menu {
            ForEach(ReminderCategory.allCases, id: \.self) { category in
                Button {
                    editorTarget = ReminderEditorTarget(category: category, reminder: nil)
                } label: {
                    Label(category.addTitle(locale: locale), systemImage: category.iconName)
                }
            }
        } label: {
            Label {
                Text("Add reminder", comment: "Menu button on the vehicle detail to add a reminder")
            } icon: {
                Image(systemName: "plus.circle")
            }
        }
        .accessibilityIdentifier("addReminderButton")
    }
}
