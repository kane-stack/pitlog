import Foundation

/// One recognized line of text of a receipt, in reading order.
///
/// Deliberately independent of the scan pipeline's own line type (the two get unified later).
public struct ReceiptLine: Hashable, Sendable {
    public var text: String
    /// 1-based page number. Multi-page receipts are passed as one concatenated list.
    public var page: Int

    public init(_ text: String, page: Int = 1) {
        self.text = text
        self.page = page
    }
}

/// What the app already knows. Used only for plausibility checks, never to change a value.
public struct ReceiptContext: Hashable, Sendable {
    public var today: DayDate
    public var firstRegistration: YearMonth?
    public var lastKnownOdometerKm: Int?
    public var knownPlates: [String]
    public var knownVINs: [String]
    /// Decoded RKSV QR code payloads found by the scanner (see `parseRKSVCode`). QR codes printed
    /// as text in `lines` are found as well.
    public var rksvPayloads: [String]

    public init(
        today: DayDate,
        firstRegistration: YearMonth? = nil,
        lastKnownOdometerKm: Int? = nil,
        knownPlates: [String] = [],
        knownVINs: [String] = [],
        rksvPayloads: [String] = []
    ) {
        self.today = today
        self.firstRegistration = firstRegistration
        self.lastKnownOdometerKm = lastKnownOdometerKm
        self.knownPlates = knownPlates
        self.knownVINs = knownVINs
        self.rksvPayloads = rksvPayloads
    }
}

public enum FieldConfidence: Int, Hashable, Comparable, Sendable {
    case low = 0
    case medium = 1
    case high = 2

    public static func < (lhs: FieldConfidence, rhs: FieldConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum ReceiptField: String, Hashable, CaseIterable, Sendable {
    case grossTotal
    case netTotal
    case vatAmount
    case vatRate
    case serviceDate
    case invoiceDate
    case workshopName
    case workshopUID
    case odometerKm
    case plate
    case vin
    case category
    case plaque
    case workItems
}

/// Why a field has its value (or why it is empty): confidence and the text it came from.
public struct FieldEvidence: Hashable, Sendable {
    public var confidence: FieldConfidence
    /// The line (or a short description) the value was taken from.
    public var source: String

    public init(confidence: FieldConfidence, source: String) {
        self.confidence = confidence
        self.source = source
    }
}

/// The extraction result. Every field is a suggestion the user confirms. Principle: better `nil`
/// than a wrong value.
public struct ReceiptDraft: Hashable, Sendable {
    /// Gross invoice total (decision E-1), never the amount due after a deposit.
    public var grossTotal: Money?
    public var netTotal: Money?
    public var vatAmount: Money?
    /// Percent, e.g. 20.
    public var vatRate: Int?
    public var serviceDate: DayDate?
    public var invoiceDate: DayDate?
    public var workshopName: String?
    /// Compact form, e.g. "ATU12345678". Never the customer's UID.
    public var workshopUID: String?
    public var odometerKm: Int?
    public var plate: String?
    public var vin: String?
    public var suggestedCategory: MaintenanceCategory?
    /// Short position descriptions without prices.
    public var workItems: [String]
    /// The new punch, only if a § 57a receipt states it explicitly. A suggestion only (ADR-5).
    public var suggestedPlaque: YearMonth?
    public var isSmallAmountInvoice: Bool
    public var isVATExempt: Bool
    /// Credit note or cancellation: `grossTotal` stays `nil`.
    public var isCreditNote: Bool
    public var evidence: [ReceiptField: FieldEvidence]

    /// Date for the history entry (decision E-2): service date, otherwise invoice date.
    public var historyDate: DayDate? { serviceDate ?? invoiceDate }

    public init() {
        workItems = []
        isSmallAmountInvoice = false
        isVATExempt = false
        isCreditNote = false
        evidence = [:]
    }

    public func confidence(of field: ReceiptField) -> FieldConfidence? {
        evidence[field]?.confidence
    }
}

/// ADR-10: receipt extraction behind a protocol. The heuristic implementation lives in Core;
/// a Foundation Models implementation can be added in the app.
public protocol ReceiptExtractor: Sendable {
    func extract(lines: [ReceiptLine], context: ReceiptContext) async -> ReceiptDraft
}
