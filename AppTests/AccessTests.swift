import Foundation
import PitlogCore
import SwiftData
import Testing

@testable import Pitlog

@MainActor
struct AccessTests {
    private func vehicle(_ name: String, created seconds: TimeInterval, archived: Bool = false) -> Vehicle {
        let vehicle = Vehicle(name: name)
        vehicle.createdAt = Date(timeIntervalSince1970: seconds)
        vehicle.isArchived = archived
        return vehicle
    }

    // MARK: Entitlements per tier

    @Test func freeTierMatchesADR11() {
        let free = TierEntitlements(tier: .free)
        #expect(!free.isPro)
        #expect(free.vehicleLimit == 1)
        #expect(!free.canScanReceipts)
        #expect(!free.canUseProReminders)
        #expect(!free.canViewMultiYearCosts)
        #expect(!free.canExportServiceRecord)
    }

    @Test func proTierUnlocksEverything() {
        let pro = TierEntitlements(tier: .pro)
        #expect(pro.isPro)
        #expect(pro.vehicleLimit == .max)
        #expect(pro.canScanReceipts && pro.canUseProReminders && pro.canViewMultiYearCosts && pro.canExportServiceRecord)
    }

    @Test func theFakesBehaveAsNamed() {
        #expect(UnlimitedEntitlements().isPro)
        #expect(!NoReceiptScanEntitlements().canScanReceipts)
        #expect(NoReceiptScanEntitlements().canUseProReminders)
        #expect(FreeEntitlements().vehicleLimit == 1)
        #expect(!FreeEntitlements().canUseProReminders)
    }

    // MARK: Read-only vehicles

    @Test func overTheLimitOnlyTheFirstVehicleIsEditable() {
        let first = vehicle("Golf", created: 100)
        let second = vehicle("Fiat", created: 200)
        let third = vehicle("Traktor", created: 300)
        // The order of the list must not matter: other devices may deliver vehicles in any order.
        let all = [third, first, second]
        let free = FreeEntitlements()
        #expect(!free.isReadOnly(first, among: all))
        #expect(free.isReadOnly(second, among: all))
        #expect(free.isReadOnly(third, among: all))
    }

    @Test func proEditsEveryVehicle() {
        let all = [vehicle("A", created: 1), vehicle("B", created: 2), vehicle("C", created: 3)]
        let pro = TierEntitlements(tier: .pro)
        #expect(all.allSatisfy { !pro.isReadOnly($0, among: all) })
    }

    @Test func aLaterVehicleFromAnotherDeviceDoesNotTakeTheEditablePlace() {
        let mine = vehicle("Mine", created: 1_000)
        let synced = vehicle("Synced", created: 2_000)
        let free = FreeEntitlements()
        #expect(!free.isReadOnly(mine, among: [mine]))
        #expect(!free.isReadOnly(mine, among: [mine, synced]))
        #expect(free.isReadOnly(synced, among: [mine, synced]))
    }

    @Test func anOlderSyncedVehicleTakesTheEditablePlaceDeterministically() {
        // Created first on another device: it is the editable one on every device.
        let local = vehicle("Local", created: 5_000)
        let older = vehicle("Older", created: 1_000)
        let free = FreeEntitlements()
        #expect(free.isReadOnly(local, among: [local, older]))
        #expect(!free.isReadOnly(older, among: [local, older]))
    }

    @Test func archivedVehiclesAreNeverReadOnlyAndDoNotCount() {
        let archived = vehicle("Old", created: 1, archived: true)
        let active = vehicle("Active", created: 2)
        let free = FreeEntitlements()
        #expect(!free.isReadOnly(archived, among: [active]))
        #expect(!free.isReadOnly(active, among: [active]))
    }

    @Test func addingIsBlockedAtTheLimitOnly() {
        let free = FreeEntitlements()
        #expect(free.canAddVehicle(currentCount: 0))
        #expect(!free.canAddVehicle(currentCount: 1))
        #expect(!free.canAddVehicle(currentCount: 5))
    }

    // MARK: Planning without Pro

    private func plannedIdentifiers(tier: Tier) async throws -> [String] {
        let container = PreviewData.container(withSamples: false)
        let context = container.mainContext
        let today = CalendarDay.today(in: CalendarDay.austria)

        let car = Vehicle(
            name: "Golf", licensePlate: "W 1 A", category: .passengerCar,
            firstRegistration: today.adding(years: -5).yearMonth,
            plaque: today.adding(months: 3).yearMonth)
        context.insert(car)
        let reminder = Reminder(category: .custom, vehicle: car)
        reminder.title = "Dentist for the car"
        reminder.leadDays = 0
        reminder.dueDate = CalendarDay.today(in: .current).adding(days: 60)
        context.insert(reminder)

        let center = FakeNotificationCenter()
        let defaults = try #require(UserDefaults(suiteName: "plan-tests-\(UUID().uuidString)"))
        let coordinator = ReminderCoordinator(
            container: container, scheduler: NotificationScheduler(center: center), defaults: defaults,
            tier: { tier })
        await coordinator.replan()
        return center.pending.map(\.identifier)
    }

    @Test func withoutProOnlyTheInspectionRemindersArePlanned() async throws {
        let ids = try await plannedIdentifiers(tier: .free)
        #expect(!ids.isEmpty)
        #expect(ids.allSatisfy { $0.contains("/inspection/") })
    }

    @Test func withProTheStoredRemindersArePlannedToo() async throws {
        let ids = try await plannedIdentifiers(tier: .pro)
        #expect(ids.contains { $0.contains("/inspection/") })
        #expect(ids.contains { !$0.contains("/inspection/") })
    }

    @Test func theStoredReminderIsKeptWhenProEnds() async throws {
        let container = PreviewData.container(withSamples: false)
        let context = container.mainContext
        let car = Vehicle(name: "Golf")
        context.insert(car)
        let reminder = Reminder(category: .service, vehicle: car)
        reminder.dueDate = CalendarDay.today(in: .current).adding(days: 90)
        context.insert(reminder)

        let center = FakeNotificationCenter()
        let defaults = try #require(UserDefaults(suiteName: "plan-tests-\(UUID().uuidString)"))
        let coordinator = ReminderCoordinator(
            container: container, scheduler: NotificationScheduler(center: center), defaults: defaults,
            tier: { .free })
        await coordinator.replan()

        #expect(center.pending.isEmpty)
        let stored = try context.fetch(FetchDescriptor<Reminder>())
        #expect(stored.count == 1)
        #expect(stored.first?.isEnabled == true)
    }
}
