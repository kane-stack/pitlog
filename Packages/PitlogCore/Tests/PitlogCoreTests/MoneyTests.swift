import Foundation
import Testing
@testable import PitlogCore

private func eur(_ minor: Int64) -> Money { Money(amountMinor: minor, currencyCode: "EUR") }

@Test func addingSameCurrencySums() {
    #expect(eur(1_050).adding(eur(250)) == eur(1_300))
    #expect(eur(100).adding(eur(-250)) == eur(-150))
}

@Test func addingDifferentCurrenciesIsRefused() {
    #expect(eur(100).adding(Money(amountMinor: 100, currencyCode: "CHF")) == nil)
}

@Test func currencyCodeIsNormalized() {
    #expect(Money(amountMinor: 1, currencyCode: " eur ") == eur(1))
}

@Test func additionSaturatesInsteadOfOverflowing() {
    #expect(eur(Int64.max).adding(eur(1)) == eur(Int64.max))
    #expect(eur(Int64.min).adding(eur(-1)) == eur(Int64.min))
    #expect(eur(Int64.max - 5).adding(eur(5)) == eur(Int64.max))
}

struct DigitsCase: Sendable {
    let code: String
    let digits: Int
}

@Test(arguments: [
    DigitsCase(code: "EUR", digits: 2), DigitsCase(code: "CHF", digits: 2), DigitsCase(code: "HUF", digits: 2),
    DigitsCase(code: "JPY", digits: 0), DigitsCase(code: "KWD", digits: 3), DigitsCase(code: "clf", digits: 4),
])
func minorUnitDigits(_ c: DigitsCase) {
    #expect(Money.minorUnitDigits(for: c.code) == c.digits)
}

struct AmountCase: Sendable {
    let minor: Int64
    let code: String
    let amount: Decimal
}

@Test(arguments: [
    AmountCase(minor: 1_234, code: "EUR", amount: Decimal(string: "12.34")!),
    AmountCase(minor: -50, code: "EUR", amount: Decimal(string: "-0.5")!),
    AmountCase(minor: 0, code: "EUR", amount: 0),
    AmountCase(minor: 1_500, code: "JPY", amount: 1_500),
    AmountCase(minor: 12_345, code: "KWD", amount: Decimal(string: "12.345")!),
])
func amountConversionRoundTrips(_ c: AmountCase) {
    let money = Money(amountMinor: c.minor, currencyCode: c.code)
    #expect(money.amount == c.amount)
    #expect(Money(amount: c.amount, currencyCode: c.code) == money)
}

@Test func amountRoundsHalfAwayFromZeroToMinorUnits() {
    #expect(Money(amount: Decimal(string: "12.345")!, currencyCode: "EUR") == eur(1_235))
    #expect(Money(amount: Decimal(string: "12.344")!, currencyCode: "EUR") == eur(1_234))
    #expect(Money(amount: Decimal(string: "-12.345")!, currencyCode: "EUR") == eur(-1_235))
}

@Test func amountBeyondInt64IsRefused() {
    #expect(Money(amount: Decimal(string: "99999999999999999999")!, currencyCode: "EUR") == nil)
}

@Test func largeAmountsKeepTheirExactDecimalValue() {
    let big = eur(9_000_000_000_000_000_001)
    #expect(big.amount == Decimal(string: "90000000000000000.01")!)
}
