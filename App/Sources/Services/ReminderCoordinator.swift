import BackgroundTasks
import Foundation
import PitlogCore
import SwiftData
import SwiftUI

/// Wraps a `BGTask` so it can cross into a `Task`. `BGTask` is thread-safe for the two calls used.
private final class BackgroundTaskBox: @unchecked Sendable {
    let task: BGTask

    init(_ task: BGTask) {
        self.task = task
    }
}

/// Plans the notifications from the stored data and hands the plan to the scheduler. Triggers: scene
/// becomes active, saves (debounced), setting changes and a daily background refresh.
@MainActor
final class ReminderCoordinator {
    /// Also listed in `BGTaskSchedulerPermittedIdentifiers` (project.yml).
    static let refreshTaskIdentifier = "com.example.pitlog.refresh-reminders"

    private let container: ModelContainer
    private let scheduler: NotificationScheduler
    private let defaults: UserDefaults
    private let builder = ReminderScheduleBuilder()
    private var debounce: Task<Void, Never>?

    init(container: ModelContainer, scheduler: NotificationScheduler, defaults: UserDefaults = .standard) {
        self.container = container
        self.scheduler = scheduler
        self.defaults = defaults
    }

    /// Plans now and replaces the pending notifications.
    func replan() async {
        let settings = ReminderSettings.load(from: defaults)
        let context = container.mainContext
        let vehicles =
            (try? context.fetch(FetchDescriptor<Vehicle>(predicate: #Predicate { !$0.isArchived }))) ?? []
        let today = CalendarDay.today(in: .current)
        let inspectionToday = CalendarDay.today(in: CalendarDay.austria)
        let schedules = vehicles.flatMap {
            builder.schedules(for: $0, today: today, inspectionToday: inspectionToday)
        }
        let plan = NotificationPlanner.plan(schedules: schedules, today: today)
        let names = Dictionary(
            vehicles.map { ($0.id.uuidString, $0.displayName) }, uniquingKeysWith: { first, _ in first })
        await scheduler.schedule(plan: plan, vehicleNames: names, settings: settings)
    }

    /// Plans soon, coalescing bursts of saves into one run.
    func requestReplan(after delay: Duration = .seconds(1)) {
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.replan()
        }
    }

    // MARK: Background refresh

    /// Call once, before the app finishes launching.
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskIdentifier, using: nil) {
            [weak self] task in
            let box = BackgroundTaskBox(task)
            Task { @MainActor in
                guard let self else {
                    box.task.setTaskCompleted(success: false)
                    return
                }
                let work = Task { @MainActor in
                    await self.replan()
                    self.scheduleBackgroundRefresh()
                }
                box.task.expirationHandler = { work.cancel() }
                await work.value
                box.task.setTaskCompleted(success: !work.isCancelled)
            }
        }
    }

    /// Asks iOS for a refresh in about a day. iOS decides when (or whether) it runs.
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 20 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

extension EnvironmentValues {
    @Entry var reminderCoordinator: ReminderCoordinator?
}
