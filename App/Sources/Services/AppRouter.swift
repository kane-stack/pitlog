import Foundation
import Observation
import UserNotifications

enum AppTab: Hashable, Sendable {
    case upcoming
    case vehicles
    case settings
}

/// Navigation state that outside events (a tapped notification) can change.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .upcoming
    /// `Vehicle.id` of a vehicle to open. `RootView` consumes it.
    var pendingVehicleID: String?

    func openVehicle(id: String) {
        pendingVehicleID = id
    }
}

/// Foreground presentation and taps on notifications. A tap opens the vehicle detail.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let router: AppRouter

    init(router: AppRouter) {
        self.router = router
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let id = response.notification.request.content.userInfo[NotificationUserInfo.vehicleID] as? String
        else { return }
        await router.openVehicle(id: id)
    }
}
