import Testing
@testable import PitlogCore

func sample(_ d: DayDate, _ km: Int) -> OdometerSample {
    OdometerSample(day: d, km: km)
}

@Test(arguments: [
    [OdometerSample](),
    [sample(day(2026, 1, 1), 10_000)],
    // 13 days: too short
    [sample(day(2026, 1, 1), 10_000), sample(day(2026, 1, 14), 10_400)],
    // two readings on the same day
    [sample(day(2026, 1, 1), 10_000), sample(day(2026, 1, 1), 10_050)],
])
func projectionNeedsTwoReadingsSpanningTwoWeeks(_ samples: [OdometerSample]) {
    #expect(OdometerProjection(samples: samples) == nil)
}

@Test func projectionWithExactlyFourteenDays() throws {
    let projection = try #require(
        OdometerProjection(samples: [sample(day(2026, 1, 1), 0), sample(day(2026, 1, 15), 140)]))
    #expect(projection.kmPerDay == 10)
    #expect(projection.isEstimate)
}

@Test func projectionIgnoresInputOrderAndUsesFirstAndLastReading() throws {
    let projection = try #require(
        OdometerProjection(samples: [
            sample(day(2026, 1, 31), 10_900),
            sample(day(2026, 1, 1), 10_000),
            sample(day(2026, 1, 15), 10_200),
        ]))
    #expect(projection.kmPerDay == 30)
    #expect(projection.latest == sample(day(2026, 1, 31), 10_900))
}

struct ProjectedDayCase: Sendable {
    let targetKm: Int
    let expected: DayDate?
}

@Test(arguments: [
    // 20 days at 30 km/day from the latest reading
    ProjectedDayCase(targetKm: 11_500, expected: day(2026, 2, 20)),
    // 1100 / 30 = 36.7 days, rounded up to 37
    ProjectedDayCase(targetKm: 12_000, expected: day(2026, 3, 9)),
    // already reached: the day of the latest reading
    ProjectedDayCase(targetKm: 10_900, expected: day(2026, 1, 31)),
    ProjectedDayCase(targetKm: 9_000, expected: day(2026, 1, 31)),
])
func projectedDay(_ c: ProjectedDayCase) throws {
    let projection = try #require(
        OdometerProjection(samples: [sample(day(2026, 1, 1), 10_000), sample(day(2026, 1, 31), 10_900)]))
    #expect(projection.projectedDay(forKm: c.targetKm) == c.expected)
}

@Test func standingVehicleHasNoProjectedDay() throws {
    let projection = try #require(
        OdometerProjection(samples: [sample(day(2026, 1, 1), 10_000), sample(day(2026, 3, 1), 10_000)]))
    #expect(projection.projectedDay(forKm: 10_500) == nil)
}

@Test func absurdlyFarProjectionIsRejected() throws {
    let projection = try #require(
        OdometerProjection(samples: [sample(day(2026, 1, 1), 10_000), sample(day(2026, 12, 31), 10_001)]))
    #expect(projection.projectedDay(forKm: 500_000) == nil)
}
