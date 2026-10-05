import SwiftData
import SwiftUI
import UserNotifications

@main
struct PitlogApp: App {
    private let container: ModelContainer
    private let coordinator: ReminderCoordinator
    /// The notification center only keeps a weak reference to its delegate.
    private let notificationDelegate: NotificationDelegate
    @State private var router: AppRouter
    @State private var permission: NotificationPermission

    init() {
        let container = Self.makeContainer()
        let center = SystemNotificationCenter()
        let router = AppRouter()
        let delegate = NotificationDelegate(router: router)
        let coordinator = ReminderCoordinator(container: container, scheduler: NotificationScheduler(center: center))

        // The delegate and the background task must be in place before the app finishes launching.
        UNUserNotificationCenter.current().delegate = delegate
        coordinator.registerBackgroundTask()

        self.container = container
        self.coordinator = coordinator
        self.notificationDelegate = delegate
        self._router = State(initialValue: router)
        self._permission = State(initialValue: NotificationPermission(center: center))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.entitlements, Self.entitlements)
                .environment(\.reminderCoordinator, coordinator)
                .environment(router)
                .environment(permission)
        }
        .modelContainer(container)
    }

    private static var entitlements: any Entitlements {
        ProcessInfo.processInfo.arguments.contains("-UITestNoReceiptScan")
            ? NoReceiptScanEntitlements() : UnlimitedEntitlements()
    }

    @MainActor
    private static func makeContainer() -> ModelContainer {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        do {
            if arguments.contains("-UITestSampleData") {
                return PreviewData.container(withSamples: true)
            }
            // Unit tests host the app; keep CloudKit and the on-disk store out of it.
            if environment["XCTestConfigurationFilePath"] != nil {
                return PreviewData.container(withSamples: false)
            }
            do {
                return try ModelContainerFactory.production()
            } catch {
                // No CloudKit (e.g. unsigned build): keep working on a local store.
                return try ModelContainerFactory.localOnly()
            }
        } catch {
            fatalError("Could not create the model container: \(error)")
        }
    }
}
