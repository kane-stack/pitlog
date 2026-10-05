import Foundation
import PitlogCore

/// User settings for reminders, shared by the Settings screen (`@AppStorage`) and the planner.
struct ReminderSettings: Equatable, Sendable {
    enum Keys {
        static let enabled = "remindersEnabled"
        static let hour = "reminderHour"
        static let minute = "reminderMinute"
        static let tyreLeadDays = "reminderTyreLeadDays"
        static let vignetteLeadDays = "reminderVignetteLeadDays"
        static let serviceLeadDays = "reminderServiceLeadDays"
        static let serviceLeadKm = "reminderServiceLeadKm"
        static let customLeadDays = "reminderCustomLeadDays"
    }

    enum Defaults {
        static let enabled = true
        /// Product decision: 09:00 local time.
        static let hour = 9
        static let minute = 0
        static let tyreLeadDays = AustriaReminderDefaults.defaultTyreLeadDays
        static let vignetteLeadDays = AustriaReminderDefaults.vignetteExpiryLeadDays
        static let serviceLeadDays = ServiceDue.defaultLeadDays
        static let serviceLeadKm = ServiceDue.defaultLeadKm
        static let customLeadDays = 7
    }

    var isEnabled = Defaults.enabled
    var hour = Defaults.hour
    var minute = Defaults.minute
    var tyreLeadDays = Defaults.tyreLeadDays
    var vignetteLeadDays = Defaults.vignetteLeadDays
    var serviceLeadDays = Defaults.serviceLeadDays
    var serviceLeadKm = Defaults.serviceLeadKm
    var customLeadDays = Defaults.customLeadDays

    static func load(from defaults: UserDefaults = .standard) -> ReminderSettings {
        func integer(_ key: String, _ fallback: Int) -> Int {
            defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
        }
        return ReminderSettings(
            isEnabled: defaults.object(forKey: Keys.enabled) as? Bool ?? Defaults.enabled,
            hour: integer(Keys.hour, Defaults.hour),
            minute: integer(Keys.minute, Defaults.minute),
            tyreLeadDays: integer(Keys.tyreLeadDays, Defaults.tyreLeadDays),
            vignetteLeadDays: integer(Keys.vignetteLeadDays, Defaults.vignetteLeadDays),
            serviceLeadDays: integer(Keys.serviceLeadDays, Defaults.serviceLeadDays),
            serviceLeadKm: integer(Keys.serviceLeadKm, Defaults.serviceLeadKm),
            customLeadDays: integer(Keys.customLeadDays, Defaults.customLeadDays))
    }

    /// Default lead in days for a new reminder of `category`.
    func leadDays(for category: ReminderCategory) -> Int {
        switch category {
        case .tyreWinter, .tyreSummer: tyreLeadDays
        case .vignette: vignetteLeadDays
        case .service: serviceLeadDays
        case .custom: customLeadDays
        }
    }
}
