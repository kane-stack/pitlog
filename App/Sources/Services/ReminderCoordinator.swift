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

/// Persists the `OverdueNoticeLedger` (a few short strings) in the user defaults. Device-local on purpose:
/// every device plans and delivers its own notifications (ADR-9).
enum OverdueNoticeStore {
    static let key = "overdueNoticeLedger"

    static func load(from defaults: UserDefaults) -> OverdueNoticeLedger {
        guard let data = defaults.data(forKey: key),
              let ledger = try? JSONDecoder().decode(OverdueNoticeLedger.self, from: data)
        else { return OverdueNoticeLedger() }
        return ledger
    }

    static func save(_ ledger: OverdueNoticeLedger, to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        defaults.set(data, forKey: key)
    }
}

/// Plans the notifications from the stored data and hands the plan to the scheduler. Triggers: scene
/// becomes active, saves (debounced), setting changes and a daily background refresh.
@MainActor
final class ReminderCoordinator {
    /// Also listed in `BGTaskSchedulerPermittedIdentifiers` (project.yml).
    static let refreshTaskIdentifier = "com.kane.pitlog.refresh-reminders"

    private let container: ModelContainer
    private let scheduler: NotificationScheduler
    private let defaults: UserDefaults
    /// The tier decides which reminder kinds are planned (ADR-11). Read at every plan.
    private let tier: @MainActor () -> Tier
    private let builder = ReminderScheduleBuilder()
    private var debounce: Task<Void, Never>?

    init(
        container: ModelContainer, scheduler: NotificationScheduler, defaults: UserDefaults = .standard,
        tier: @escaping @MainActor () -> Tier = { .pro }
    ) {
        self.container = container
        self.scheduler = scheduler
        self.defaults = defaults
        self.tier = tier
    }

    /// Plans now and replaces the pending notifications.
    func replan() async {
        let settings = ReminderSettings.load(from: defaults)
        let context = container.mainContext
        let vehicles =
            (try? context.fetch(FetchDescriptor<Vehicle>(predicate: #Predicate { !$0.isArchived }))) ?? []
        let today = CalendarDay.today(in: .current)
        let inspectionToday = CalendarDay.today(in: CalendarDay.austria)
        // Without Pro only the inspection reminders are planned, for every vehicle. The stored reminders of the
        // other kinds stay as they are and are planned again as soon as Pro is back.
        let schedules = AccessPolicy(tier: tier()).schedulable(
            vehicles.flatMap { builder.schedules(for: $0, today: today, inspectionToday: inspectionToday) })
        var ledger = OverdueNoticeStore.load(from: defaults)
        let plan = NotificationPlanner.plan(schedules: schedules, today: today, ledger: ledger)
        // An overdue notice fires once: remember its day so that later plans neither move nor repeat it.
        ledger.record(plan)
        OverdueNoticeStore.save(ledger, to: defaults)
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
