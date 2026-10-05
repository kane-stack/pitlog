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
    @Environment(\.entitlements) private var entitlements
    @Query(filter: #Predicate<Vehicle> { !$0.isArchived }, sort: \Vehicle.createdAt)
    private var activeVehicles: [Vehicle]
    @State private var paywall: PaywallContext?
    @State private var editorTarget: ReminderEditorTarget?
    @State private var showingPermissionPrompt = false
    @State private var showingAddDialog = false
    /// Set when a service was marked done: the user is asked whether to log it in the history.
    @State private var historyOffer: EntryPrefill?
    @State private var showingHistoryOffer = false
    @State private var historyEditor: EntryEditorTarget?
    @State private var today = CalendarDay.today(in: .current)

    private let builder = ReminderScheduleBuilder()

    /// Reminders of tyres, service, vignette and custom ones need Pro (ADR-11). They stay stored and listed.
    private var isLocked: Bool { !entitlements.canUseProReminders }
    private var isReadOnly: Bool { entitlements.isReadOnly(vehicle, among: activeVehicles) }

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
        .paywall($paywall)
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
        vehicle.inspectionRemindersEnabled || (!isLocked && (vehicle.reminders ?? []).contains { $0.isEnabled })
    }

    // MARK: Inspection toggle

    private var inspectionToggle: some View {
        Group {
            Toggle(isOn: Binding(
                get: { vehicle.inspectionRemindersEnabled },
                set: { newValue in
                    if isReadOnly {
                        paywall = .vehicles
                        return
                    }
                    vehicle.inspectionRemindersEnabled = newValue
                    if newValue, permission.state == .notDetermined { showingPermissionPrompt = true }
                })
            ) {
                Text("Inspection reminders", comment: "Toggle on the vehicle detail: notifications for the inspection deadline")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("inspectionRemindersToggle")
            Text(
                "When the window opens, the month before it is due, in the due month and a week before the window closes. Check the date on your sticker.",
                comment: "Explanation below the inspection reminders toggle"
            )
            .font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Rows

    private func row(_ presentation: ReminderPresentation) -> some View {
        let reminder = presentation.reminder
        let locked = isLocked
        // Not a Button: button rows in a list fail the clipping audit, tappable rows do not.
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(presentation.title, systemImage: presentation.iconName)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if locked {
                    Spacer(minLength: 8)
                    ProBadge()
                }
            }
            Text(presentation.dueText)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if let relative = presentation.relativeText {
                Text(relative)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if locked {
                Text("Not active without Pitlog Pro. Your reminder is kept and works again with Pro.", comment: "Reminders list: a reminder of a Pro type while the user has no Pro")
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { open(reminder) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: (locked ? lockedLabel(presentation) : presentation.accessibilityLabel).withoutSoftHyphens))
        .accessibilityHint(locked
            ? Text("Opens Pitlog Pro.", comment: "VoiceOver hint of a locked reminder row")
            : Text("Opens the reminder for editing.", comment: "VoiceOver hint of a reminder row"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { open(reminder) }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if reminder.isEnabled && !locked {
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
                if isReadOnly { paywall = .vehicles } else { modelContext.delete(reminder) }
            } label: {
                Label {
                    Text("Delete", comment: "Swipe action to delete a reminder")
                } icon: {
                    Image(systemName: "trash")
                }
            }
            Button {
                open(reminder)
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

    /// Opens the editor, or the paywall for a locked reminder.
    private func open(_ reminder: Reminder) {
        if isLocked {
            paywall = .reminders
        } else if isReadOnly {
            paywall = .vehicles
        } else {
            editorTarget = ReminderEditorTarget(category: reminder.category, reminder: reminder)
        }
    }

    private func lockedLabel(_ presentation: ReminderPresentation) -> String {
        let pro = String(localized: "Requires Pitlog Pro, not active", locale: locale, comment: "VoiceOver: a reminder of a Pro type while the user has no Pro")
        return "\(presentation.title). \(pro). \(presentation.dueText)."
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

    private func addTapped() {
        if isLocked {
            paywall = .reminders
        } else if isReadOnly {
            paywall = .vehicles
        } else {
            showingAddDialog = true
        }
    }

    private var addButton: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Label {
                Text("Add reminder", comment: "Menu button on the vehicle detail to add a reminder")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "plus.circle")
            }
            .foregroundStyle(Color.accentColor)
            if isLocked {
                Spacer(minLength: 8)
                ProBadge()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { addTapped() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLocked
            ? Text("Add reminder, requires Pitlog Pro", comment: "VoiceOver label of the add reminder row while the user has no Pro")
            : Text("Add reminder", comment: "Menu button on the vehicle detail to add a reminder"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { addTapped() }
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
