import SwiftData
import SwiftUI

/// Top-level navigation: Upcoming, Vehicles, Settings. Also drives replanning of the notifications and
/// the deep link from a tapped notification to the vehicle detail.
struct RootView: View {
    @AppStorage("legalNoticeAcknowledged") private var acknowledged = false
    @AppStorage(ReminderSettings.Keys.enabled) private var remindersEnabled = ReminderSettings.Defaults.enabled
    @AppStorage(ReminderSettings.Keys.hour) private var reminderHour = ReminderSettings.Defaults.hour
    @AppStorage(ReminderSettings.Keys.minute) private var reminderMinute = ReminderSettings.Defaults.minute

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.reminderCoordinator) private var coordinator
    @Environment(AppRouter.self) private var router
    @Environment(NotificationPermission.self) private var permission
    @State private var vehiclesPath: [Vehicle] = []

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab(value: AppTab.upcoming) {
                NavigationStack { UpcomingView() }
            } label: {
                Label {
                    Text("Upcoming", comment: "Tab bar item for upcoming deadlines")
                } icon: {
                    Image(systemName: "calendar")
                }
            }

            Tab(value: AppTab.vehicles) {
                NavigationStack(path: $vehiclesPath) { VehicleListView() }
            } label: {
                Label {
                    Text("Vehicles", comment: "Tab bar item for the vehicle list")
                } icon: {
                    Image(systemName: "car")
                }
            }

            Tab(value: AppTab.settings) {
                NavigationStack { SettingsView() }
            } label: {
                Label {
                    Text("Settings", comment: "Tab bar item for settings")
                } icon: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: Binding(get: { !acknowledged }, set: { _ in })) {
            FirstLaunchNoticeView { acknowledged = true }
        }
        .task {
            await permission.refresh()
            await coordinator?.replan()
            openPendingVehicle()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task {
                    await permission.refresh()
                    await coordinator?.replan()
                }
            case .background:
                coordinator?.scheduleBackgroundRefresh()
            default:
                break
            }
        }
        // After model saves, debounced by the coordinator.
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            coordinator?.requestReplan()
        }
        .onChange(of: remindersEnabled) { _, _ in coordinator?.requestReplan(after: .milliseconds(300)) }
        .onChange(of: reminderHour) { _, _ in coordinator?.requestReplan() }
        .onChange(of: reminderMinute) { _, _ in coordinator?.requestReplan() }
        .onChange(of: permission.state) { _, _ in coordinator?.requestReplan(after: .milliseconds(300)) }
        .onChange(of: router.pendingVehicleID) { _, _ in openPendingVehicle() }
    }

    /// A tapped notification carries the vehicle id: open that vehicle's detail.
    private func openPendingVehicle() {
        guard let id = router.pendingVehicleID else { return }
        guard let uuid = UUID(uuidString: id) else {
            router.pendingVehicleID = nil
            return
        }
        // The container may still be loading right after a cold start: keep the id until the vehicle exists.
        let descriptor = FetchDescriptor<Vehicle>(predicate: #Predicate { $0.id == uuid })
        guard let vehicle = try? modelContext.fetch(descriptor).first else { return }
        router.pendingVehicleID = nil
        router.selectedTab = .vehicles
        vehiclesPath = [vehicle]
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container())
        .environment(AppRouter())
        .environment(NotificationPermission(center: SystemNotificationCenter()))
}

#Preview("German") {
    RootView()
        .modelContainer(PreviewData.container())
        .environment(AppRouter())
        .environment(NotificationPermission(center: SystemNotificationCenter()))
        .environment(\.locale, Locale(identifier: "de_AT"))
}
