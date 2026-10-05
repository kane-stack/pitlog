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
    @State private var store: StoreService

    init() {
        let container = Self.makeContainer()
        let center = SystemNotificationCenter()
        let router = AppRouter()
        let delegate = NotificationDelegate(router: router)
        let store = Self.makeStore()
        let coordinator = ReminderCoordinator(
            container: container, scheduler: NotificationScheduler(center: center), tier: { store.tier })

        // The delegate and the background task must be in place before the app finishes launching.
        UNUserNotificationCenter.current().delegate = delegate
        coordinator.registerBackgroundTask()
        // An export that was open when the app ended must not leave a copy of the PDF behind.
        ServiceRecordTempFiles.sweep()

        self.container = container
        self.coordinator = coordinator
        self.notificationDelegate = delegate
        self._router = State(initialValue: router)
        self._permission = State(initialValue: NotificationPermission(center: center))
        self._store = State(initialValue: store)
        store.start()
    }

    var body: some Scene {
        WindowGroup {
            EntitlementsHost(fixed: Self.fixedEntitlements) {
                RootView()
            }
                .environment(store)
                .environment(\.reminderCoordinator, coordinator)
                .environment(router)
                .environment(permission)
        }
        .modelContainer(container)
    }

    /// Entitlements that do not come from the store: only the UI test of one restricted feature.
    private static var fixedEntitlements: (any Entitlements)? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestNoReceiptScan") { return NoReceiptScanEntitlements() }
        #endif
        return nil
    }

    /// StoreKit in the app. Debug builds can replace it for tests: `-UITestFree` and `-UITestPro` fix the tier,
    /// sample data and unit tests (which host the app) run as Pro so that they are not about the tiers.
    @MainActor
    private static func makeStore() -> StoreService {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let isHostedByTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let scratch = UserDefaults(suiteName: "com.kane.pitlog.store-tests") ?? .standard
        if arguments.contains("-UITestFree") {
            return StoreService(backend: StubStoreBackend.free, defaults: scratch)
        }
        if arguments.contains("-UITestPro") || arguments.contains("-UITestSampleData") || isHostedByTests {
            return StoreService(backend: StubStoreBackend.pro, defaults: scratch)
        }
        #endif
        return StoreService(backend: StoreKitBackend())
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

/// Hands the current entitlements to the views. They follow the store's tier and change when the user buys,
/// when the subscription ends or when the debug override is switched.
private struct EntitlementsHost<Content: View>: View {
    let fixed: (any Entitlements)?
    let content: Content
    @Environment(StoreService.self) private var store

    init(fixed: (any Entitlements)?, @ViewBuilder content: () -> Content) {
        self.fixed = fixed
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.entitlements, fixed ?? TierEntitlements(tier: store.tier))
    }
}
