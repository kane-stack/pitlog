import Foundation

/// One tax bucket of an RKSV receipt: the gross turnover at a VAT rate.
public struct RKSVAmount: Hashable, Sendable {
    /// VAT rate in percent (20, 10, 13, 0 or 19).
    public let ratePercent: Int
    public let amount: Money
}

/// The parsed content of an RKSV QR code (Registrierkassensicherheitsverordnung, Anlage 1).
public struct RKSVReceipt: Hashable, Sendable {
    /// Algorithm identifier, e.g. "R1-AT1".
    public let algorithm: String
    public let cashRegisterID: String
    public let receiptNumber: String
    public let date: DayDate
    public let hour: Int
    public let minute: Int
    public let second: Int
    public let amounts: [RKSVAmount]
    /// Sum of all buckets (gross).
    public let grossTotal: Money
    /// Training receipt ("TRA"). Not a real sale.
    public let isTraining: Bool
    /// Cancellation receipt ("STO").
    public let isCancellation: Bool
}

/// Parses the payload of an RKSV QR code. Never traps: malformed input gives `nil`.
///
/// Structure as reproduced from RKSV Anlage 1 (README, open point 1: the full text was not checked
/// against the primary source), fields separated by `_`, starting with `_`:
///
///     _R1-AT1_<Kassen-ID>_<Belegnummer>_<yyyy-MM-ddTHH:mm:ss>_<Normal>_<Ermäßigt 1>_<Ermäßigt 2>_<Null>_<Besonders>_<Umsatzzähler AES>_<Zertifikat>_<Signatur>
///
/// ASSUMPTIONS, all unverified:
/// - the five amounts are gross amounts for 20 %, 10 %, 13 %, 0 % and 19 %, with a decimal comma;
/// - the cash register ID contains no `_` (otherwise the fields shift and the payload is rejected);
/// - the encrypted turnover counter is the Base64 text of "TRA" (`VFJB`) for training receipts and
///   "STO" (`U1RP`) for cancellations.
public func parseRKSVCode(_ payload: String) -> RKSVReceipt? {
    let text = payload.trimmingCharacters(in: .whitespacesAndNewlines)
    guard text.hasPrefix("_R1-AT") else { return nil }
    let parts = text.split(separator: "_", omittingEmptySubsequences: false).map { String($0) }
    // parts[0] is empty (leading "_"); algorithm, register, number, time, five amounts.
    guard parts.count >= 10, parts[0].isEmpty else { return nil }
    let algorithm = parts[1]
    guard algorithm.hasPrefix("R1-AT"), !parts[2].isEmpty, !parts[3].isEmpty else { return nil }
    guard let (date, hour, minute, second) = parseRKSVDateTime(parts[4]) else { return nil }
    let rates = [20, 10, 13, 0, 19]
    var amounts: [RKSVAmount] = []
    var total = Money.zero("EUR")
    for (offset, rate) in rates.enumerated() {
        guard let minor = parseRKSVAmount(parts[5 + offset]) else { return nil }
        let money = Money(amountMinor: minor, currencyCode: "EUR")
        amounts.append(RKSVAmount(ratePercent: rate, amount: money))
        guard let sum = total.adding(money) else { return nil }
        total = sum
    }
    let counter = parts.count > 10 ? parts[10] : ""
    return RKSVReceipt(
        algorithm: algorithm,
        cashRegisterID: parts[2],
        receiptNumber: parts[3],
        date: date,
        hour: hour,
        minute: minute,
        second: second,
        amounts: amounts,
        grossTotal: total,
        isTraining: counter == "VFJB",
        isCancellation: counter == "U1RP")
}

private func parseRKSVDateTime(_ s: String) -> (DayDate, Int, Int, Int)? {
    let halves = s.split(separator: "T", omittingEmptySubsequences: false).map { String($0) }
    guard halves.count == 2 else { return nil }
    let d = halves[0].split(separator: "-", omittingEmptySubsequences: false).map { String($0) }
    let t = halves[1].split(separator: ":", omittingEmptySubsequences: false).map { String($0) }
    guard d.count == 3, t.count == 2 || t.count == 3 else { return nil }
    let all = d + t
    guard all.allSatisfy({ ReceiptText.allDigits($0) && $0.count <= 4 }) else { return nil }
    guard let year = Int(d[0]), let month = Int(d[1]), let day = Int(d[2]), let hour = Int(t[0]),
        let minute = Int(t[1])
    else { return nil }
    let second = t.count == 3 ? (Int(t[2]) ?? -1) : 0
    guard (0...23).contains(hour), (0...59).contains(minute), (0...60).contains(second),
        let date = DayDate(year: year, month: month, day: day)
    else { return nil }
    return (date, hour, minute, second)
}

/// "-12,50", "0,00", "12.50": exactly two decimals.
private func parseRKSVAmount(_ s: String) -> Int64? {
    var text = s
    var negative = false
    if text.hasPrefix("-") {
        negative = true
        text.removeFirst()
    }
    let pieces = text.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "," || $0 == "." }).map { String($0) }
    guard pieces.count == 2, pieces[1].count == 2, ReceiptText.allDigits(pieces[0]), pieces[0].count <= 12,
        ReceiptText.allDigits(pieces[1]), let whole = Int64(pieces[0]), let cents = Int64(pieces[1])
    else { return nil }
    let minor = whole * 100 + cents
    return negative ? -minor : minor
}
