import Foundation
import PitlogCore
import UserNotifications

enum NotificationAuthorization: Equatable, Sendable {
    case notDetermined
    case denied
    /// Authorized, provisional or ephemeral.
    case authorized
}

/// The part of `UNUserNotificationCenter` the app uses, so tests can use a fake.
@MainActor
protocol UserNotificationCenter {
    func authorizationStatus() async -> NotificationAuthorization
    func requestAuthorization() async throws -> Bool
    func pendingRequestIdentifiers() async -> [String]
    func removePendingRequests(withIdentifiers identifiers: [String])
    func add(_ request: UNNotificationRequest) async throws
}

@MainActor
struct SystemNotificationCenter: UserNotificationCenter {
    private var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    func authorizationStatus() async -> NotificationAuthorization {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized, .provisional, .ephemeral: return .authorized
        @unknown default: return .denied
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func pendingRequestIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }
}

enum NotificationUserInfo {
    static let vehicleID = "vehicleID"
    static let reminderID = "reminderID"
}

/// Replaces the pending local notifications with a plan (ADR-9: every device plans for itself).
@MainActor
final class NotificationScheduler {
    /// Every request of the app carries this prefix, so only our own are replaced.
    static let identifierPrefix = "pitlog.reminder."
    /// iOS keeps at most 64 pending local notifications per app.
    static let maximumRequests = 64

    private let center: any UserNotificationCenter
    private var tail: Task<Void, Never>?

    init(center: any UserNotificationCenter) {
        self.center = center
    }

    /// Runs after any plan still being applied, so overlapping calls never mix two plans.
    func schedule(
        plan: [PlannedNotification],
        vehicleNames: [String: String],
        settings: ReminderSettings,
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent
    ) async {
        let previous = tail
        let task = Task { @MainActor in
            await previous?.value
            await self.apply(
                plan: plan, vehicleNames: vehicleNames, settings: settings, now: now, calendar: calendar,
                locale: locale)
        }
        tail = task
        await task.value
    }

    private func apply(
        plan: [PlannedNotification],
        vehicleNames: [String: String],
        settings: ReminderSettings,
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) async {
        let status = await center.authorizationStatus()
        let ours = await center.pendingRequestIdentifiers().filter { $0.hasPrefix(Self.identifierPrefix) }
        if !ours.isEmpty { center.removePendingRequests(withIdentifiers: ours) }
        // Without permission nothing is scheduled (and the app never asks on its own here).
        guard status == .authorized, settings.isEnabled else { return }

        var added = 0
        for item in plan {
            guard added < Self.maximumRequests else { break }
            guard let request = Self.request(
                for: item, vehicleName: vehicleNames[item.vehicleID] ?? "", settings: settings, now: now,
                calendar: calendar, locale: locale)
            else { continue }
            do {
                try await center.add(request)
                added += 1
            } catch {
                continue
            }
        }
    }

    /// `nil` if the notification time on the fire day is not in the future.
    static func request(
        for item: PlannedNotification,
        vehicleName: String,
        settings: ReminderSettings,
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) -> UNNotificationRequest? {
        var components = DateComponents()
        components.year = item.fireDay.year
        components.month = item.fireDay.month
        components.day = item.fireDay.day
        components.hour = settings.hour
        components.minute = settings.minute
        guard let fireDate = calendar.date(from: components), fireDate > now else { return nil }

        let text = NotificationTexts.text(for: item, vehicleName: vehicleName, locale: locale)
        let content = UNMutableNotificationContent()
        content.title = text.title
        content.body = text.body
        content.sound = .default
        content.threadIdentifier = item.vehicleID
        content.userInfo = [
            NotificationUserInfo.vehicleID: item.vehicleID,
            NotificationUserInfo.reminderID: item.reminderID,
        ]
        // Components without calendar and time zone: the trigger uses the device's current ones.
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(
            identifier: identifierPrefix + item.id, content: content, trigger: trigger)
    }
}
