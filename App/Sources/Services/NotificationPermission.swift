import Foundation
import Observation

/// Notification permission state. The app asks only when a reminder is created or switched on, after a
/// short explanation (`NotificationPermissionPrompt`), never at launch.
@MainActor
@Observable
final class NotificationPermission {
    private(set) var state: NotificationAuthorization = .notDetermined

    @ObservationIgnored private let center: any UserNotificationCenter

    init(center: any UserNotificationCenter) {
        self.center = center
    }

    func refresh() async {
        state = await center.authorizationStatus()
    }

    /// Shows the system prompt. Only call it after the explanation.
    @discardableResult
    func request() async -> Bool {
        let granted = (try? await center.requestAuthorization()) ?? false
        await refresh()
        return granted
    }
}
