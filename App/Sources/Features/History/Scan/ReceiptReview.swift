import Foundation
import PitlogCore

/// The fields of the entry a receipt scan can fill, in the order of the review screen.
enum ReceiptReviewField: String, CaseIterable, Identifiable, Sendable {
    case date, amount, workshop, category, workItems, odometer

    var id: String { rawValue }
}

/// One reading of a field, as the review shows and applies it.
enum ReceiptReviewValue: Hashable, Sendable {
    case day(DayDate)
    case money(Money)
    case text(String)
    case kilometers(Int)
    case category(MaintenanceCategory)
    case lines([String])
}

struct ReceiptReviewChoice: Hashable, Sendable {
    let source: ReceiptSource
    let value: ReceiptReviewValue
}

/// One scanned value on the review screen: what was read, how sure we are, and whether the user wants it.
struct ReceiptReviewItem: Identifiable, Equatable {
    let field: ReceiptReviewField
    /// Switched on = copied into the entry.
    var included: Bool
    let confidence: FieldConfidence
    let agreement: ReceiptAgreement
    /// The line the value was read from; `nil` for the language model, which has no source line.
    let snippet: String?
    /// All readings. More than one means the readers disagree (or the QR code overruled another reading).
    let choices: [ReceiptReviewChoice]
    var selectedChoice = 0

    // The editable value. Only the member for `field` is used.
    var text = ""
    var day: DayDate?
    var kilometers: Int?
    var category: MaintenanceCategory = .otherWorkshop
    var currency = "EUR"

    var id: ReceiptReviewField { field }

    mutating func assign(_ value: ReceiptReviewValue, locale: Locale) {
        switch value {
        case .day(let day): self.day = day
        case .money(let money):
            currency = money.currencyCode
            text = MoneyFormat.editText(money, locale: locale)
        case .text(let text): self.text = text
        case .kilometers(let km): kilometers = km
        case .category(let category): self.category = category
        case .lines(let lines): text = lines.joined(separator: "\n")
        }
    }
}

/// What "Save" or "Apply" hands over: only the values the user left switched on.
struct ReceiptApplication: Equatable {
    var vehicleID: UUID?
    var date: DayDate?
    var category: MaintenanceCategory?
    var workshop: String?
    var workItems: String?
    var amount: Money?
    var odometerKm: Int?

    var isEmpty: Bool {
        date == nil && category == nil && workshop == nil && workItems == nil && amount == nil && odometerKm == nil
    }
}

/// How the receipt's plate or VIN relates to the vehicle the entry goes to.
enum ReceiptVehicleStatus: Equatable {
    case matches(ReceiptVehicleMatcher.Evidence)
    /// The receipt names another vehicle (or a plate no vehicle has).
    case differs
    /// No plate and no VIN on the receipt.
    case unknown
}

/// The review screen's state: the merge turned into items the user can accept, edit or discard. Nothing leaves
/// this type except the application; saving is the caller's job.
struct ReceiptReview: Equatable {
    var items: [ReceiptReviewItem]
    var vehicleID: UUID?
    let vehicles: [ReceiptVehicleInfo]
    /// The entry belongs to this vehicle already (the editor): no picker.
    let vehicleIsFixed: Bool
    let isCreditNote: Bool
    let suggestedPlaque: YearMonth?
    let receiptPlate: MergedField<String>?
    let receiptVIN: MergedField<String>?
    let locale: Locale

    init(
        merge: ReceiptMerge, vehicles: [ReceiptVehicleInfo], contextVehicleID: UUID?, vehicleIsFixed: Bool,
        locale: Locale
    ) {
        self.vehicles = vehicles
        self.vehicleIsFixed = vehicleIsFixed
        self.isCreditNote = merge.isCreditNote
        self.suggestedPlaque = merge.suggestedPlaque
        self.receiptPlate = merge.plate
        self.receiptVIN = merge.vin
        self.locale = locale

        var items: [ReceiptReviewItem] = []
        func add<V: Hashable & Sendable>(
            _ field: ReceiptReviewField, _ merged: MergedField<V>?, wrap: (V) -> ReceiptReviewValue
        ) {
            guard let merged else { return }
            var item = ReceiptReviewItem(
                field: field, included: merged.isIncludedByDefault, confidence: merged.confidence,
                agreement: merged.agreement, snippet: merged.snippet,
                choices: merged.candidates.map { ReceiptReviewChoice(source: $0.source, value: wrap($0.value)) })
            item.assign(wrap(merged.value), locale: locale)
            items.append(item)
        }
        add(.date, merge.date) { .day($0) }
        add(.amount, merge.gross) { .money($0) }
        add(.workshop, merge.workshop) { .text($0) }
        add(.category, merge.category) { .category($0) }
        add(.workItems, merge.workItems) { .lines($0) }
        add(.odometer, merge.odometerKm) { .kilometers($0) }
        self.items = items

        if vehicleIsFixed {
            self.vehicleID = contextVehicleID
        } else {
            let found = Self.match(plate: merge.plate, vin: merge.vin, in: vehicles)
            self.vehicleID = found?.vehicleID ?? contextVehicleID
        }
    }

    /// Every reading of plate and VIN is tried, the VIN first.
    private static func match(
        plate: MergedField<String>?, vin: MergedField<String>?, in vehicles: [ReceiptVehicleInfo]
    ) -> ReceiptVehicleMatcher.Match? {
        for candidate in vin?.candidates ?? [] {
            if let found = ReceiptVehicleMatcher.match(plate: nil, vin: candidate.value, in: vehicles) { return found }
        }
        for candidate in plate?.candidates ?? [] {
            if let found = ReceiptVehicleMatcher.match(plate: candidate.value, vin: nil, in: vehicles) { return found }
        }
        return nil
    }

    // MARK: Vehicle

    var vehicleStatus: ReceiptVehicleStatus {
        if receiptPlate == nil, receiptVIN == nil { return .unknown }
        if let found = Self.match(plate: receiptPlate, vin: receiptVIN, in: vehicles), found.vehicleID == vehicleID {
            return .matches(found.evidence)
        }
        return .differs
    }

    // MARK: Items

    func item(_ field: ReceiptReviewField) -> ReceiptReviewItem? {
        items.first { $0.field == field }
    }

    /// Picks another reading of a field (a conflict, or a reading the QR code overruled). Choosing is a decision
    /// to use it: the switch turns on.
    mutating func choose(_ index: Int, for field: ReceiptReviewField) {
        guard let position = items.firstIndex(where: { $0.field == field }),
              items[position].choices.indices.contains(index)
        else { return }
        items[position].selectedChoice = index
        items[position].assign(items[position].choices[index].value, locale: locale)
        items[position].included = true
    }

    // MARK: Result

    /// The amount switch is on, but the text is not a number.
    var hasInvalidAmount: Bool {
        guard let item = item(.amount), item.included else { return false }
        return MoneyFormat.parse(item.text, currency: item.currency, locale: locale) == .invalid
    }

    var hasSelection: Bool { !application.isEmpty }

    /// Entry can be created: a vehicle is chosen, something is switched on, and the amount is a number.
    var canApply: Bool { vehicleID != nil && hasSelection && !hasInvalidAmount }

    var application: ReceiptApplication {
        var result = ReceiptApplication(vehicleID: vehicleID)
        for item in items where item.included {
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            switch item.field {
            case .date: result.date = item.day
            case .amount:
                if case .value(let money) = MoneyFormat.parse(item.text, currency: item.currency, locale: locale) {
                    result.amount = money
                }
            case .workshop: result.workshop = text.isEmpty ? nil : text
            case .category: result.category = item.category
            case .workItems: result.workItems = text.isEmpty ? nil : text
            case .odometer: result.odometerKm = item.kilometers.flatMap { $0 > 0 ? $0 : nil }
            }
        }
        return result
    }
}
