import Foundation

/// An amount in minor units (cents) of one currency. Never a floating point value.
///
/// Amounts of different currencies are never converted or mixed: `adding(_:)` refuses them.
/// Sums saturate at the `Int64` limits instead of overflowing.
public struct Money: Hashable, Comparable, Codable, Sendable {
    public var amountMinor: Int64
    /// ISO 4217 code, upper case ("EUR").
    public let currencyCode: String

    public init(amountMinor: Int64, currencyCode: String) {
        self.amountMinor = amountMinor
        self.currencyCode = Self.normalized(currencyCode)
    }

    public static func zero(_ currencyCode: String) -> Money {
        Money(amountMinor: 0, currencyCode: currencyCode)
    }

    /// Rounds `amount` (in major units, e.g. 12.345) to the currency's minor units, half away from zero.
    /// `nil` if the result does not fit into `Int64`.
    public init?(amount: Decimal, currencyCode: String) {
        let code = Self.normalized(currencyCode)
        var scaled = amount * Decimal(sign: .plus, exponent: Self.minorUnitDigits(for: code), significand: 1)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        let limit = Decimal(Int64.max)
        guard rounded.isFinite, rounded <= limit, rounded >= -limit else { return nil }
        self.amountMinor = NSDecimalNumber(decimal: rounded).int64Value
        self.currencyCode = code
    }

    /// The amount in major units, exact (12.34 for 1234 minor units of EUR).
    public var amount: Decimal {
        Decimal(
            sign: amountMinor < 0 ? .minus : .plus,
            exponent: -Self.minorUnitDigits(for: currencyCode),
            significand: Decimal(amountMinor.magnitude))
    }

    /// Sum of two amounts of the same currency; `nil` for different currencies. Saturates on overflow.
    public func adding(_ other: Money) -> Money? {
        guard currencyCode == other.currencyCode else { return nil }
        return Money(amountMinor: Self.saturatingAdd(amountMinor, other.amountMinor), currencyCode: currencyCode)
    }

    /// Ordering is only meaningful within one currency; across currencies the code decides.
    public static func < (lhs: Money, rhs: Money) -> Bool {
        if lhs.currencyCode != rhs.currencyCode { return lhs.currencyCode < rhs.currencyCode }
        return lhs.amountMinor < rhs.amountMinor
    }

    static func saturatingAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        guard overflow else { return sum }
        return lhs < 0 ? Int64.min : Int64.max
    }

    static func normalized(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespaces).uppercased()
    }

    /// Digits after the decimal point (ISO 4217). Two unless listed.
    public static func minorUnitDigits(for currencyCode: String) -> Int {
        switch normalized(currencyCode) {
        case "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG", "RWF", "UGX", "UYI", "VND", "VUV",
            "XAF", "XOF", "XPF":
            0
        case "BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND":
            3
        case "CLF", "UYW":
            4
        default:
            2
        }
    }
}
