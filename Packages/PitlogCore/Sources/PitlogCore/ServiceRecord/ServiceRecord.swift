import Foundation

/// The vehicle data a service record shows. Plain values, so the record can be built and tested without the app.
public struct ServiceRecordVehicle: Hashable, Sendable {
    public var licensePlate: String
    public var name: String
    public var make: String?
    public var model: String?
    public var vin: String?
    public var category: VehicleCategory
    public var firstRegistration: YearMonth?
    /// Month and year punched on the inspection sticker (ADR-5). The record never shows a calculated deadline.
    public var plaque: YearMonth?

    public init(
        licensePlate: String, name: String = "", make: String? = nil, model: String? = nil, vin: String? = nil,
        category: VehicleCategory = .passengerCar, firstRegistration: YearMonth? = nil, plaque: YearMonth? = nil
    ) {
        self.licensePlate = licensePlate
        self.name = name
        self.make = make
        self.model = model
        self.vin = vin
        self.category = category
        self.firstRegistration = firstRegistration
        self.plaque = plaque
    }
}

/// An odometer value on a day.
public struct OdometerStatement: Hashable, Sendable {
    public var kilometers: Int
    public var date: DayDate

    public init(kilometers: Int, date: DayDate) {
        self.kilometers = kilometers
        self.date = date
    }
}

/// One history entry as the service record gets it from the app. `id` is opaque: the app uses it to find the
/// receipts of the entry when they are appended.
public struct ServiceRecordEntry: Hashable, Sendable {
    public var id: String
    public var date: DayDate
    public var odometerKm: Int?
    public var category: MaintenanceCategory
    public var workshop: String
    /// What was done, one item per element.
    public var workItems: [String]
    /// `nil`: no cost entered.
    public var money: Money?
    public var receiptCount: Int

    public init(
        id: String, date: DayDate, odometerKm: Int? = nil, category: MaintenanceCategory = .service,
        workshop: String = "", workItems: [String] = [], money: Money? = nil, receiptCount: Int = 0
    ) {
        self.id = id
        self.date = date
        self.odometerKm = odometerKm
        self.category = category
        self.workshop = workshop
        self.workItems = workItems
        self.money = money
        self.receiptCount = receiptCount
    }
}

/// Which entries the record contains.
public enum ServiceRecordPeriod: Hashable, Sendable {
    case all
    /// Entries on or after this day.
    case since(DayDate)
}

/// What the user chose in the sheet before the export. The defaults protect privacy: no amounts, no receipt
/// images, but the VIN, because a buyer wants to check it against the vehicle.
public struct ServiceRecordOptions: Hashable, Sendable {
    public var period: ServiceRecordPeriod
    public var includeAmounts: Bool
    public var includeVIN: Bool
    public var includeReceiptAttachments: Bool

    public init(
        period: ServiceRecordPeriod = .all, includeAmounts: Bool = false, includeVIN: Bool = true,
        includeReceiptAttachments: Bool = false
    ) {
        self.period = period
        self.includeAmounts = includeAmounts
        self.includeVIN = includeVIN
        self.includeReceiptAttachments = includeReceiptAttachments
    }
}

/// An entry in the record with its number. The number is the position in the list (1 is the newest entry);
/// the attachments and the "Receipt" column refer to it.
public struct ServiceRecordItem: Hashable, Sendable {
    public var number: Int
    public var entry: ServiceRecordEntry

    public init(number: Int, entry: ServiceRecordEntry) {
        self.number = number
        self.entry = entry
    }
}

/// The costs of one currency: years newest first (only years with entries) and the total over the listed entries.
public struct ServiceRecordCosts: Hashable, Sendable {
    public var currencyCode: String
    public var years: [YearCosts]
    public var total: Money

    public init(currencyCode: String, years: [YearCosts], total: Money) {
        self.currencyCode = currencyCode
        self.years = years
        self.total = total
    }
}

/// The content of a service record (the PDF "Servicenachweis"), computed from plain values: filter by period,
/// sort, number, sums per year and currency, and the choice of fields. The renderer in the app only lays it out.
///
/// Order: newest entry first. A buyer wants the latest work first, and a long history stays useful when the
/// first page is all that gets read. It is also the order of the history screen.
public struct ServiceRecord: Hashable, Sendable {
    public let createdOn: DayDate
    public let options: ServiceRecordOptions
    /// Without the VIN if `options.includeVIN` is off.
    public let vehicle: ServiceRecordVehicle
    /// The latest known odometer value, from the whole history and the readings, not only from the listed period.
    public let odometer: OdometerStatement?
    /// The entries of the period, newest first, numbered from 1. Without amounts if `options.includeAmounts` is off.
    public let items: [ServiceRecordItem]
    /// Sums per currency, empty unless amounts are included. Currencies are never converted or mixed.
    public let costs: [ServiceRecordCosts]

    public init(
        vehicle: ServiceRecordVehicle,
        odometerReadings: [OdometerStatement],
        entries: [ServiceRecordEntry],
        options: ServiceRecordOptions,
        today: DayDate
    ) {
        self.createdOn = today
        self.options = options

        var shownVehicle = vehicle
        if !options.includeVIN { shownVehicle.vin = nil }
        self.vehicle = shownVehicle

        self.odometer = Self.latestOdometer(readings: odometerReadings, entries: entries)

        let sorted = Self.sortedNewestFirst(Self.filter(entries, period: options.period))
        let visible = sorted.map { entry -> ServiceRecordEntry in
            var copy = entry
            if !options.includeAmounts { copy.money = nil }
            copy.receiptCount = max(0, entry.receiptCount)
            return copy
        }
        self.items = visible.enumerated().map { ServiceRecordItem(number: $0.offset + 1, entry: $0.element) }
        self.costs = options.includeAmounts ? Self.costs(of: visible) : []
    }

    /// `true` if no entry is in the period.
    public var isEmpty: Bool { items.isEmpty }

    /// Entries whose receipts are appended: only with `includeReceiptAttachments`, only those that have receipts.
    public var attachmentItems: [ServiceRecordItem] {
        guard options.includeReceiptAttachments else { return [] }
        return items.filter { $0.entry.receiptCount > 0 }
    }

    // MARK: Building blocks

    static func filter(_ entries: [ServiceRecordEntry], period: ServiceRecordPeriod) -> [ServiceRecordEntry] {
        switch period {
        case .all:
            return entries
        case .since(let start):
            return entries.filter { $0.date >= start }
        }
    }

    /// Newest day first; on the same day the higher odometer value first, then the order of the input.
    static func sortedNewestFirst(_ entries: [ServiceRecordEntry]) -> [ServiceRecordEntry] {
        entries.enumerated().sorted { lhs, rhs in
            if lhs.element.date != rhs.element.date { return lhs.element.date > rhs.element.date }
            let lhsKm = lhs.element.odometerKm ?? -1
            let rhsKm = rhs.element.odometerKm ?? -1
            if lhsKm != rhsKm { return lhsKm > rhsKm }
            return lhs.offset < rhs.offset
        }.map { $0.element }
    }

    /// The statement on the latest day; on the same day the higher value. Values of zero or less are ignored.
    static func latestOdometer(readings: [OdometerStatement], entries: [ServiceRecordEntry]) -> OdometerStatement? {
        var candidates = readings
        for entry in entries {
            if let km = entry.odometerKm { candidates.append(OdometerStatement(kilometers: km, date: entry.date)) }
        }
        return candidates.filter { $0.kilometers > 0 }.max { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.kilometers < rhs.kilometers
        }
    }

    static func costs(of entries: [ServiceRecordEntry]) -> [ServiceRecordCosts] {
        let costEntries = entries.compactMap { entry in
            entry.money.map { CostEntry(date: entry.date, category: entry.category, money: $0) }
        }
        let summary = CostSummary(entries: costEntries)
        return summary.currencies.map { currency in
            let years = Set(costEntries.filter { $0.money.currencyCode == currency }.map { $0.date.year })
            let perYear = years.sorted(by: >).map { summary.costs(year: $0, currency: currency) }
            return ServiceRecordCosts(currencyCode: currency, years: perYear, total: summary.total(currency: currency))
        }
    }
}

/// File names for the exported PDF.
public enum ServiceRecordFileName {
    static let invalidCharacters: Set<Character> = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", "%"]
    static let maximumLength = 100

    /// "Servicenachweis W-12345-A 2027-03-01.pdf". `title` is the localized word, `plate` the license plate (or
    /// the vehicle name). Characters that are invalid in file names are replaced, spaces inside the plate become
    /// hyphens, and the result is cut to a sane length.
    public static func make(title: String, plate: String, date: DayDate, fileExtension: String = "pdf") -> String {
        let cleanTitle = sanitized(title, spaceReplacement: " ")
        let cleanPlate = sanitized(plate, spaceReplacement: "-")
        var parts = [cleanTitle.isEmpty ? "Pitlog" : cleanTitle]
        if !cleanPlate.isEmpty { parts.append(cleanPlate) }
        parts.append(date.description)
        var base = parts.joined(separator: " ")
        if base.count > maximumLength { base = String(base.prefix(maximumLength)) }
        return "\(base).\(fileExtension)"
    }

    static func sanitized(_ text: String, spaceReplacement: Character) -> String {
        var result = ""
        for character in text.trimmingCharacters(in: .whitespacesAndNewlines) {
            if character.isNewline || character.isWhitespace {
                result.append(spaceReplacement)
            } else if invalidCharacters.contains(character) || character.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) {
                result.append("-")
            } else {
                result.append(character)
            }
        }
        // Collapse repeated separators and trim them and leading dots (hidden files).
        var collapsed = ""
        for character in result {
            if character == "-" || character == " ", collapsed.last == character { continue }
            collapsed.append(character)
        }
        let trimSet: Set<Character> = ["-", " ", "."]
        while let first = collapsed.first, trimSet.contains(first) { collapsed.removeFirst() }
        while let last = collapsed.last, trimSet.contains(last) { collapsed.removeLast() }
        return collapsed
    }
}
