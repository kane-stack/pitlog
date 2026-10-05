import Foundation
import Testing
@testable import PitlogCore

private func key(_ id: String, _ seconds: TimeInterval) -> VehicleKey {
    VehicleKey(id: id, createdAt: Date(timeIntervalSince1970: seconds))
}

private func schedule(_ kind: ReminderSchedule.Kind) -> ReminderSchedule {
    ReminderSchedule(vehicleID: "v", reminderID: "r", kind: kind)
}

private let inspectionKind: ReminderSchedule.Kind = .inspection(
    InspectionStatus(
        dueMonth: ym(2027, 6), dueMonthSource: .plaque,
        window: InspectionWindow(opens: day(2027, 5, 1), closes: day(2027, 6, 30)),
        phase: .notYetOpen, regime: .amendedLaw, notes: [], exchangePlaqueSuggestion: nil,
        ruleVersion: "test"))

struct LimitCase: Sendable {
    let name: String
    let tier: Tier
    let count: Int
    let canAdd: Bool
}

@Test(arguments: [
    LimitCase(name: "free, none yet", tier: .free, count: 0, canAdd: true),
    LimitCase(name: "free, at the limit", tier: .free, count: 1, canAdd: false),
    LimitCase(name: "free, over the limit", tier: .free, count: 3, canAdd: false),
    LimitCase(name: "pro, many", tier: .pro, count: 500, canAdd: true),
])
func vehicleLimit(_ c: LimitCase) {
    #expect(AccessPolicy(tier: c.tier).canAddVehicle(currentCount: c.count) == c.canAdd, "\(c.name)")
}

@Test func freeVehicleLimitIsOne() {
    #expect(AccessPolicy(tier: .free).vehicleLimit == 1)
    #expect(AccessPolicy(tier: .pro).vehicleLimit == .max)
}

struct EditableCase: Sendable {
    let name: String
    let tier: Tier
    let vehicles: [VehicleKey]
    let editable: Set<String>
}

@Test(arguments: [
    EditableCase(name: "free, empty", tier: .free, vehicles: [], editable: []),
    EditableCase(name: "free, one", tier: .free, vehicles: [key("a", 10)], editable: ["a"]),
    EditableCase(
        name: "free, the oldest wins whatever the input order", tier: .free,
        vehicles: [key("c", 30), key("a", 10), key("b", 20)], editable: ["a"]),
    EditableCase(
        name: "free, equal creation date: the smaller ID wins", tier: .free,
        vehicles: [key("b", 10), key("a", 10)], editable: ["a"]),
    EditableCase(
        name: "pro, all", tier: .pro,
        vehicles: [key("c", 30), key("a", 10), key("b", 20)], editable: ["a", "b", "c"]),
])
func editableVehicles(_ c: EditableCase) {
    let policy = AccessPolicy(tier: c.tier)
    #expect(policy.editableVehicleIDs(among: c.vehicles) == c.editable, "\(c.name)")
    for vehicle in c.vehicles {
        #expect(policy.canEditVehicle(id: vehicle.id, among: c.vehicles) == c.editable.contains(vehicle.id))
    }
}

@Test func editableVehicleIsStableWhenAnotherOneArrives() {
    // A vehicle synced from another device must not take the editable place of the first one.
    let policy = AccessPolicy(tier: .free)
    let before = [key("a", 100)]
    let after = before + [key("z", 200)]
    #expect(policy.editableVehicleIDs(among: before) == ["a"])
    #expect(policy.editableVehicleIDs(among: after) == ["a"])
}

struct KindCase: Sendable {
    let name: String
    let kind: ReminderSchedule.Kind
    let freeAllows: Bool
}

@Test(arguments: [
    KindCase(name: "inspection", kind: inspectionKind, freeAllows: true),
    KindCase(
        name: "tyre", kind: .tyreChange(TyreChange(season: .winter, firstEventDay: day(2026, 10, 1), leadDays: 14)),
        freeAllows: false),
    KindCase(name: "service", kind: .service(ServiceDue(dueDay: day(2027, 1, 1))), freeAllows: false),
    KindCase(
        name: "vignette", kind: .vignette(VignetteDue(firstExpiryDay: day(2027, 1, 31), leadDays: 14, announce: nil)),
        freeAllows: false),
    KindCase(name: "custom", kind: .custom(CustomDue(dueDay: day(2027, 1, 1), leadDays: 7)), freeAllows: false),
])
func reminderKinds(_ c: KindCase) {
    #expect(AccessPolicy(tier: .free).canSchedule(c.kind) == c.freeAllows, "\(c.name)")
    #expect(AccessPolicy(tier: .pro).canSchedule(c.kind), "\(c.name)")
}

@Test func schedulableKeepsOnlyInspectionInFree() {
    let schedules = [
        schedule(inspectionKind),
        schedule(ReminderSchedule.Kind.service(ServiceDue(dueDay: day(2027, 1, 1)))),
        schedule(ReminderSchedule.Kind.custom(CustomDue(dueDay: day(2027, 1, 1), leadDays: 7))),
    ]
    #expect(AccessPolicy(tier: .free).schedulable(schedules) == [schedules[0]])
    #expect(AccessPolicy(tier: .pro).schedulable(schedules) == schedules)
}

struct CostYearCase: Sendable {
    let name: String
    let tier: Tier
    let year: Int
    let today: DayDate
    let visible: Bool
}

@Test(arguments: [
    CostYearCase(name: "free, current year", tier: .free, year: 2026, today: day(2026, 10, 5), visible: true),
    CostYearCase(name: "free, previous year", tier: .free, year: 2025, today: day(2026, 10, 5), visible: false),
    CostYearCase(name: "free, 1 January is the new year", tier: .free, year: 2025, today: day(2026, 1, 1), visible: false),
    CostYearCase(name: "free, 31 December is still the year", tier: .free, year: 2026, today: day(2026, 12, 31), visible: true),
    CostYearCase(name: "pro, old year", tier: .pro, year: 2019, today: day(2026, 10, 5), visible: true),
])
func costYears(_ c: CostYearCase) {
    #expect(AccessPolicy(tier: c.tier).canViewCostYear(c.year, today: c.today) == c.visible, "\(c.name)")
}

@Test func visibleCostYearsFilterTheSeries() {
    let zero = Money.zero("EUR")
    let series = [2024, 2025, 2026].map { YearCosts(year: $0, total: zero, categories: []) }
    #expect(AccessPolicy(tier: .free).visibleCostYears(series, today: day(2026, 3, 1)).map(\.year) == [2026])
    #expect(AccessPolicy(tier: .pro).visibleCostYears(series, today: day(2026, 3, 1)).map(\.year) == [2024, 2025, 2026])
}

@Test func proIncludesEveryFeatureAndFreeNone() {
    for feature in ProFeature.allCases {
        #expect(AccessPolicy(tier: .pro).allows(feature))
        #expect(!AccessPolicy(tier: .free).allows(feature))
    }
}
