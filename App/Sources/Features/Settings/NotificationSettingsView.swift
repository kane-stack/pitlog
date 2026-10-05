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

    /// Explanations are rows, not section footers: footers use a secondary color that fails the contrast audit.
    private func note(_ text: Text) -> some View {
        text
            .font(.footnote)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
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
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("remindersEnabledToggle")
                DatePicker(selection: timeBinding, displayedComponents: .hourAndMinute) {
                    Text("Time of day", comment: "Settings: time of day reminder notifications arrive")
                        .fixedSize(horizontal: false, vertical: true)
                }
                NotificationPermissionRow(showsWhenAuthorized: true)
                note(Text(
                    "Notifications arrive at this time on the day of each reminder. They are planned on this device only.",
                    comment: "Settings footer below the notification time"))
            }

            Section {
                Text("Default lead times", comment: "Settings: section header for default lead times")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                LeadPicker(title: Text("Tyres", comment: "Settings: default lead time of tyre reminders"), value: $tyreLeadDays, options: LeadOptions.days, valueText: LeadOptions.days)
                LeadPicker(title: Text("Vignette", comment: "Settings: default lead time of the vignette expiry reminder"), value: $vignetteLeadDays, options: LeadOptions.days, valueText: LeadOptions.days)
                LeadPicker(title: Text("Service, by date", comment: "Settings: default lead time of service reminders by date"), value: $serviceLeadDays, options: LeadOptions.days, valueText: LeadOptions.days)
                LeadPicker(title: Text("Service, by distance", comment: "Settings: default lead distance of service reminders by odometer"), value: $serviceLeadKm, options: LeadOptions.leadKm, valueText: LeadOptions.kilometers)
                LeadPicker(title: Text("Own reminders", comment: "Settings: default lead time of custom reminders"), value: $customLeadDays, options: LeadOptions.days, valueText: LeadOptions.days)
                note(Text(
                    "Used for new reminders. Existing reminders keep their own lead time.",
                    comment: "Settings footer below the default lead times"))
            }
        }
        .navigationTitle(Text("Notifications", comment: "Navigation title of the notification settings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .notificationPermissionPrompt(isPresented: $showingPermissionPrompt)
        .task { await permission.refresh() }
    }
}
