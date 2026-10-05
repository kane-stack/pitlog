public struct OdometerSample: Hashable, Sendable {
    public var day: DayDate
    public var km: Int

    public init(day: DayDate, km: Int) {
        self.day = day
        self.km = km
    }
}

/// Linear estimate of the daily mileage, from the first to the last reading. Always an estimate.
public struct OdometerProjection: Hashable, Sendable {
    /// Readings must span at least this many days.
    public static let minimumSpanDays = 14
    /// Projections further out than this are treated as unusable.
    static let maximumProjectedDays = 36_500

    public let latest: OdometerSample
    public let kmPerDay: Double

    /// Projections are estimates by nature; the UI must label them so.
    public var isEstimate: Bool { true }

    /// `nil` with fewer than two readings or if they span less than `minimumSpanDays`.
    public init?(samples: [OdometerSample]) {
        let sorted = samples.sorted { ($0.day, $0.km) < ($1.day, $1.km) }
        guard let first = sorted.first, let last = sorted.last else { return nil }
        let span = last.day.days(from: first.day)
        guard sorted.count >= 2, span >= Self.minimumSpanDays else { return nil }
        self.latest = last
        self.kmPerDay = Double(last.km - first.km) / Double(span)
    }

    /// The day the odometer is estimated to reach `target`. If the latest reading is already at or past
    /// `target`, that reading's day. `nil` if the vehicle does not move or the day is unreasonably far out.
    public func projectedDay(forKm target: Int) -> DayDate? {
        if target <= latest.km { return latest.day }
        guard kmPerDay > 0 else { return nil }
        let days = (Double(target - latest.km) / kmPerDay).rounded(.up)
        guard days <= Double(Self.maximumProjectedDays) else { return nil }
        return latest.day.adding(days: Int(days))
    }
}
