import SwiftUI

/// Settings → Notifications: master switch, time of day, permission state and default lead times.
struct NotificationSettingsView: View {
    @AppStorage(ReminderSettings.Keys.enabled) private var isEnabled = ReminderSettings.Defaults.enabled
    @AppStorage(ReminderSettings.Keys.hour) private var hour = ReminderSettings.Defaults.hour
    @AppStorage(ReminderSettings.Keys.minute) private var minute = ReminderSettings.Defaults.minute
    @AppStorage(ReminderSettings.Keys.tyreLeadDays) private var tyreLeadDays = ReminderSettings.Defaults.tyreLeadDays
    @AppStorage(ReminderSettings.Keys.vignetteLeadDays) private var vignetteLeadDays = ReminderSettings.Defaults.vignetteLeadDays
    @AppStorage(ReminderSettings.Keys.serviceLeadDays) private var serviceLeadDays = ReminderSettings.Defaults.serviceLeadDays
    @AppStorage(ReminderSettings.Keys.serviceLeadKm) private var serviceLeadKm = ReminderSettings.Defaults.serviceLeadKm
    @AppStorage(ReminderSettings.Keys.customLeadDays) private var customLeadDays = ReminderSettings.Defaults.customLeadDays

    @Environment(NotificationPermission.self) private var permission
    @State private var showingPermissionPrompt = false

    private var timeBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date() },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                hour = parts.hour ?? ReminderSettings.Defaults.hour
                minute = parts.minute ?? ReminderSettings.Defaults.minute
            })
    }

    var body: some View {
        List {
            Section {
                Toggle(
                    isOn: Binding(
                        get: { isEnabled },
                        set: { newValue in
                            isEnabled = newValue
                            if newValue, permission.state == .notDetermined { showingPermissionPrompt = true }
                        })
                ) {
                    Text("Reminders", comment: "Settings: master switch for all reminder notifications")
                }
                .accessibilityIdentifier("remindersEnabledToggle")
                DatePicker(selection: timeBinding, displayedComponents: .hourAndMinute) {
                    Text("Time of day", comment: "Settings: time of day reminder notifications arrive")
                }
                NotificationPermissionRow(showsWhenAuthorized: true)
            } footer: {
                Text(
                    "Notifications arrive at this time on the day of each reminder. They are planned on this device only.",
                    comment: "Settings footer below the notification time")
            }

            Section {
                Stepper(value: $tyreLeadDays, in: 0...90) {
                    Text("Tyres: \(tyreLeadDays) days before", comment: "Settings: default lead time of tyre reminders in days, plural")
                }
                Stepper(value: $vignetteLeadDays, in: 0...90) {
                    Text("Vignette: \(vignetteLeadDays) days before", comment: "Settings: default lead time of the vignette expiry reminder in days, plural")
                }
                Stepper(value: $serviceLeadDays, in: 0...90) {
                    Text("Service: \(serviceLeadDays) days before", comment: "Settings: default lead time of service reminders in days, plural")
                }
                Stepper(value: $serviceLeadKm, in: 0...5_000, step: 100) {
                    Text("Service: \(serviceLeadKm) km before", comment: "Settings: default lead distance of service reminders in kilometres")
                }
                Stepper(value: $customLeadDays, in: 0...90) {
                    Text("Own reminders: \(customLeadDays) days before", comment: "Settings: default lead time of custom reminders in days, plural")
                }
            } header: {
                Text("Default lead times", comment: "Settings: section header for default lead times")
            } footer: {
                Text(
                    "Used for new reminders. Existing reminders keep their own lead time.",
                    comment: "Settings footer below the default lead times")
            }
        }
        .navigationTitle(Text("Notifications", comment: "Navigation title of the notification settings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .notificationPermissionPrompt(isPresented: $showingPermissionPrompt)
        .task { await permission.refresh() }
    }
}
