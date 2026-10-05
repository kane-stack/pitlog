/// Season of a tyre change reminder.
public enum TyreSeason: String, Hashable, Codable, Sendable, CaseIterable {
    /// Reminder before the start of the winter tyre period.
    case winter
    /// Reminder before the end of the winter tyre period.
    case summer
}

/// Vignette dates of a country (a toll sticker valid for a period).
public struct VignetteDefaults: Hashable, Sendable {
    /// The day the new annual vignette becomes valid.
    public let newVignetteAvailable: MonthDay
    /// The last day of validity of the previous annual vignette.
    public let validUntil: MonthDay
    /// Default lead of the expiry reminder.
    public let expiryLeadDays: Int
    /// Remote purchases may only become valid this many days after purchase.
    public let remotePurchaseDelayDays: Int

    public init(
        newVignetteAvailable: MonthDay,
        validUntil: MonthDay,
        expiryLeadDays: Int,
        remotePurchaseDelayDays: Int
    ) {
        self.newVignetteAvailable = newVignetteAvailable
        self.validUntil = validUntil
        self.expiryLeadDays = expiryLeadDays
        self.remotePurchaseDelayDays = remotePurchaseDelayDays
    }
}

/// Country defaults for reminders (ADR-6). Pure; the user can change every value.
public protocol ReminderDefaults: Sendable {
    var country: CountryCode { get }
    /// Default lead of the tyre change reminder.
    var tyreLeadDays: Int { get }
    /// The legal date of the season change: start of the winter period, resp. its end.
    func tyreChangeDay(for season: TyreSeason) -> MonthDay
    /// `nil` if the country has no vignette.
    var vignette: VignetteDefaults? { get }
}

extension ReminderDefaults {
    /// First legal date of `season` on or after `today`.
    public func nextTyreChangeDay(for season: TyreSeason, from today: DayDate) -> DayDate {
        tyreChangeDay(for: season).firstOccurrence(onOrAfter: today)
    }

    /// First "valid until" day of the vignette on or after `today`.
    public func nextVignetteExpiry(from today: DayDate) -> DayDate? {
        vignette?.validUntil.firstOccurrence(onOrAfter: today)
    }
}

/// Austria. Sources: `docs/rules/AT-57a-KFG.md` §7, texts in `docs/sources/`.
public struct AustriaReminderDefaults: ReminderDefaults {
    public init() {}

    public var country: CountryCode { .austria }

    /// AT-72: winter period starts on 1 November (§ 102 Abs. 8a KFG).
    public static let winterPeriodStart = MonthDay(uncheckedMonth: 11, day: 1)
    /// AT-72: winter period ends on 15 April (§ 102 Abs. 8a KFG).
    public static let winterPeriodEnd = MonthDay(uncheckedMonth: 4, day: 15)
    /// Product decision (not legal): two weeks ahead of the legal date, so 18 Oct and 1 Apr.
    public static let defaultTyreLeadDays = 14

    /// AT-70: the new annual vignette is valid from 1 December (§ 11 Abs. 1 BStMG).
    public static let vignetteNewAvailable = MonthDay(uncheckedMonth: 12, day: 1)
    /// AT-70: the annual vignette also covers January of the following year (§ 11 Abs. 1 BStMG).
    public static let vignetteValidUntil = MonthDay(uncheckedMonth: 1, day: 31)
    /// AT-71: first day of validity is at the earliest the 18th day after a remote purchase
    /// (§ 15 Abs. 2 Z 8 BStMG, secondary source: the details are in the ASFINAG Mautordnung).
    public static let vignetteRemoteDelayDays = 18
    /// Product decision: 18 days (AT-71) plus a week of buffer, so 6 Jan.
    public static let vignetteExpiryLeadDays = 25

    public var tyreLeadDays: Int { Self.defaultTyreLeadDays }

    public func tyreChangeDay(for season: TyreSeason) -> MonthDay {
        switch season {
        case .winter: Self.winterPeriodStart
        case .summer: Self.winterPeriodEnd
        }
    }

    public var vignette: VignetteDefaults? {
        VignetteDefaults(
            newVignetteAvailable: Self.vignetteNewAvailable,
            validUntil: Self.vignetteValidUntil,
            expiryLeadDays: Self.vignetteExpiryLeadDays,
            remotePurchaseDelayDays: Self.vignetteRemoteDelayDays)
    }
}

/// Maps a country to its reminder defaults.
public struct ReminderDefaultsRegistry: Sendable {
    private let defaults: [CountryCode: any ReminderDefaults]

    public init(defaults: [any ReminderDefaults]) {
        var map: [CountryCode: any ReminderDefaults] = [:]
        for entry in defaults { map[entry.country] = entry }
        self.defaults = map
    }

    public static let standard = ReminderDefaultsRegistry(defaults: [AustriaReminderDefaults()])

    public func defaults(for country: CountryCode) -> (any ReminderDefaults)? {
        defaults[country]
    }
}
