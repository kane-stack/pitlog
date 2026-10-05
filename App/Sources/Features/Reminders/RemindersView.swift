import PitlogCore
import SwiftData
import SwiftUI

/// What the reminder editor sheet opens: a new reminder of a category, or an existing one.
struct ReminderEditorTarget: Identifiable {
    let id = UUID()
    let category: ReminderCategory
    let reminder: Reminder?
}

/// All reminders of one vehicle: inspection toggle, stored reminders with swipe actions, and the add menu.
/// Pushed from the vehicle detail, so the list is short and never competes with the Pickerl card for space.
struct RemindersView: View {
    let vehicle: Vehicle

    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(NotificationPermission.self) private var permission
    @State private var editorTarget: ReminderEditorTarget?
    @State private var showingPermissionPrompt = false
    @State private var showingAddDialog = false
    /// Set when a service was marked done: the user is asked whether to log it in the history.
    @State private var historyOffer: EntryPrefill?
    @State private var showingHistoryOffer = false
    @State private var historyEditor: EntryEditorTarget?
    @State private var today = CalendarDay.today(in: .current)

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
        List {
            inspectionToggle
            ForEach(presentations, id: \.reminder.persistentModelID) { presentation in
                row(presentation)
            }
            addButton
            if hasActiveReminders {
                NotificationPermissionRow()
            }
        }
        .navigationTitle(Text("Reminders", comment: "Section header on the vehicle detail: reminders"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $editorTarget) { target in
            ReminderEditorView(vehicle: vehicle, category: target.category, reminder: target.reminder)
        }
        .notificationPermissionPrompt(isPresented: $showingPermissionPrompt)
        .historyOfferAlert(
            isPresented: $showingHistoryOffer, offer: $historyOffer, editor: $historyEditor,
            message: Text("Log this service in the history of this vehicle, for example with the invoice.", comment: "Alert after marking a service reminder as done: offer to add it to the history")
        )
        // Its own node: two sheets on one view do not mix reliably.
        .background {
            Color.clear.sheet(item: $historyEditor) { target in
                EntryEditorView(vehicle: vehicle, entry: target.entry, prefill: target.prefill)
            }
        }
    }

    private var hasActiveReminders: Bool {
        vehicle.inspectionRemindersEnabled || (vehicle.reminders ?? []).contains { $0.isEnabled }
    }

    // MARK: Inspection toggle

    private var inspectionToggle: some View {
        Group {
            Toggle(isOn: Binding(
                get: { vehicle.inspectionRemindersEnabled },
                set: { newValue in
                    vehicle.inspectionRemindersEnabled = newValue
                    if newValue, permission.state == .notDetermined { showingPermissionPrompt = true }
                })
            ) {
                Text("Inspection reminders", comment: "Toggle on the vehicle detail: notifications for the inspection deadline")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("inspectionRemindersToggle")
            Text(
                "When the window opens, a month ahead, in the due month and a week before the window closes. Check the date on your sticker.",
                comment: "Explanation below the inspection reminders toggle"
            )
            .font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Rows

    private func row(_ presentation: ReminderPresentation) -> some View {
        let reminder = presentation.reminder
        // Not a Button: button rows in a list fail the clipping audit, tappable rows do not.
        return VStack(alignment: .leading, spacing: 2) {
            Label(presentation.title, systemImage: presentation.iconName)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(presentation.dueText)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if let relative = presentation.relativeText {
                Text(relative)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            editorTarget = ReminderEditorTarget(category: reminder.category, reminder: reminder)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: presentation.accessibilityLabel))
        .accessibilityHint(Text("Opens the reminder for editing.", comment: "VoiceOver hint of a reminder row"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { editorTarget = ReminderEditorTarget(category: reminder.category, reminder: reminder) }
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
        if reminder.category == .service {
            historyOffer = EntryPrefill(
                category: .service, date: today, km: vehicle.currentOdometerKm, workItems: reminder.title)
            showingHistoryOffer = true
        }
    }

    // MARK: Add

    private var addButton: some View {
        Label {
            Text("Add reminder", comment: "Menu button on the vehicle detail to add a reminder")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "plus.circle")
        }
        .foregroundStyle(Color.accentColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { showingAddDialog = true }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { showingAddDialog = true }
        .accessibilityIdentifier("addReminderButton")
        .confirmationDialog(
            Text("Add reminder", comment: "Menu button on the vehicle detail to add a reminder"),
            isPresented: $showingAddDialog
        ) {
            ForEach(ReminderCategory.allCases, id: \.self) { category in
                Button(category.addTitle(locale: locale)) {
                    editorTarget = ReminderEditorTarget(category: category, reminder: nil)
                }
            }
        }
    }
}
