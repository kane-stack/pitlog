import Foundation
import Testing
@testable import PitlogCore

// Constructed example following the documented structure (see `parseRKSVCode`); not a real receipt.
private let rksvExample =
    "_R1-AT1_KASSE01_2041_2026-10-02T14:23:11_74,92_0,00_0,00_0,00_0,00_eHl6Xw==_1A2B3C_dGVzdHNpZ25hdHVyZQ"

@Test func parsesAConstructedRKSVPayload() throws {
    let r = try #require(parseRKSVCode(rksvExample))
    #expect(r.algorithm == "R1-AT1")
    #expect(r.cashRegisterID == "KASSE01")
    #expect(r.receiptNumber == "2041")
    #expect(r.date == day(2026, 10, 2))
    #expect(r.hour == 14 && r.minute == 23 && r.second == 11)
    #expect(r.grossTotal == Money(amountMinor: 7_492, currencyCode: "EUR"))
    let rates: [Int] = r.amounts.map(\.ratePercent)
    #expect(rates == [20, 10, 13, 0, 19])
    #expect(r.amounts.first?.amount.amountMinor == 7_492)
    #expect(!r.isTraining && !r.isCancellation)
}

@Test func sumsAllTaxBucketsAndAcceptsNegativeAmounts() throws {
    let mixed = try #require(
        parseRKSVCode("_R1-AT1_K_1_2026-10-02T09:00:00_100,00_10,50_0,00_2,00_0,00_x_y_z"))
    #expect(mixed.grossTotal.amountMinor == 11_250)
    let negative = try #require(parseRKSVCode("_R1-AT1_K_1_2026-10-02T09:00:00_-12,50_0,00_0,00_0,00_0,00_x_y_z"))
    #expect(negative.grossTotal.amountMinor == -1_250)
}

@Test func marksTrainingAndCancellationReceipts() throws {
    let training = try #require(parseRKSVCode("_R1-AT1_K_1_2026-10-02T09:00:00_1,00_0,00_0,00_0,00_0,00_VFJB_y_z"))
    #expect(training.isTraining)
    let cancel = try #require(parseRKSVCode("_R1-AT1_K_1_2026-10-02T09:00:00_-1,00_0,00_0,00_0,00_0,00_U1RP_y_z"))
    #expect(cancel.isCancellation)
}

@Test(arguments: [
    "", "_", "__", "_R1-AT1_", "R1-AT1_K_1_2026-10-02T09:00:00_1,00_0,00_0,00_0,00_0,00", "hello world",
    "_R1-AT1_K_1_2026-10-02T09:00:00_1,00_0,00_0,00_0,00",
    "_R1-AT1_K_1_2026-13-45T09:00:00_1,00_0,00_0,00_0,00_0,00",
    "_R1-AT1_K_1_2026-02-30T09:00:00_1,00_0,00_0,00_0,00_0,00",
    "_R1-AT1_K_1_2026-10-02T25:00:00_1,00_0,00_0,00_0,00_0,00",
    "_R1-AT1_K_1_not-a-dateT09:00:00_1,00_0,00_0,00_0,00_0,00",
    "_R1-AT1_K_1_2026-10-02T09:00:00_abc_0,00_0,00_0,00_0,00",
    "_R1-AT1_K_1_2026-10-02T09:00:00_1,0_0,00_0,00_0,00_0,00",
    "_R1-AT1_K_1_2026-10-02T09:00:00_99999999999999999999,00_0,00_0,00_0,00_0,00",
    "_R1-AT1__1_2026-10-02T09:00:00_1,00_0,00_0,00_0,00_0,00",
    "_R2-AT1_K_1_2026-10-02T09:00:00_1,00_0,00_0,00_0,00_0,00",
])
func malformedRKSVPayloadsGiveNilAndNeverCrash(_ payload: String) {
    #expect(parseRKSVCode(payload) == nil, "\(payload)")
}

@Test func rksvCodeInTheLinesTakesPrecedenceOverPrintedText() {
    let ctx = ReceiptContext(today: day(2026, 10, 5), firstRegistration: ym(2018, 4))
    let lines = [
        "Datum: 01.10.2026", "Summe EUR 70,00", rksvExample,
    ].map { ReceiptLine($0) }
    let d = HeuristicReceiptExtractor().draft(lines: lines, context: ctx)
    #expect(d.grossTotal?.amountMinor == 7_492)
    #expect(d.confidence(of: .grossTotal) == .high)
    #expect(d.invoiceDate == day(2026, 10, 2))
    #expect(d.confidence(of: .invoiceDate) == .high)
}

@Test func rksvPayloadFromTheContextIsUsed() {
    let ctx = ReceiptContext(today: day(2026, 10, 5), rksvPayloads: ["garbage", rksvExample])
    let d = HeuristicReceiptExtractor().draft(lines: [ReceiptLine("Summe EUR 70,00")], context: ctx)
    #expect(d.grossTotal?.amountMinor == 7_492)
}

@Test func rksvCancellationIsACreditNote() {
    let payload = "_R1-AT1_K_1_2026-10-02T09:00:00_-1,00_0,00_0,00_0,00_0,00_U1RP_y_z"
    let ctx = ReceiptContext(today: day(2026, 10, 5), rksvPayloads: [payload])
    let d = HeuristicReceiptExtractor().draft(lines: [ReceiptLine("Summe EUR 1,00")], context: ctx)
    #expect(d.isCreditNote)
    #expect(d.grossTotal == nil)
}

@Test func rksvTrainingReceiptAndFutureDatesAreIgnored() {
    let training = "_R1-AT1_K_1_2026-10-02T09:00:00_1,00_0,00_0,00_0,00_0,00_VFJB_y_z"
    let future = "_R1-AT1_K_1_2026-11-02T09:00:00_1,00_0,00_0,00_0,00_0,00_x_y_z"
    let ctx = ReceiptContext(today: day(2026, 10, 5), rksvPayloads: [training, future])
    let d = HeuristicReceiptExtractor().draft(lines: [ReceiptLine("Summe EUR 70,00")], context: ctx)
    #expect(d.grossTotal?.amountMinor == 7_000)
    #expect(d.invoiceDate == nil)
}
