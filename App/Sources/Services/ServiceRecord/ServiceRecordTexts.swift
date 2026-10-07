import Foundation
import PitlogCore

/// All texts of the service record PDF, resolved for one locale. The renderer does not depend on the device
/// language this way, and the tests can render the same record in English and German. Dates, numbers and
/// amounts only go through `FormatStyle`.
struct ServiceRecordTexts: Sendable {
    let locale: Locale

    /// Looks the string up in the language of `locale`. `String(localized:locale:)` only formats with the locale
    /// and keeps the device language for the lookup; a `LocalizedStringResource` carries the locale into both.
    private func string(_ value: String.LocalizationValue, _ comment: StaticString) -> String {
        String(localized: LocalizedStringResource(value, locale: locale, comment: comment)).withoutSoftHyphens
    }

    /// One line of the vehicle block: label, value and an optional small note under the value.
    struct Row: Equatable, Sendable {
        let label: String
        let value: String
        var note: String?
    }

    /// The cells of one history row.
    struct EntryCells: Equatable, Sendable {
        let number: String
        let date: String
        let kilometers: String
        let category: String
        /// Workshop first, then the work items, one per line.
        let workshop: String
        let work: String
        let amount: String?
        let receipt: String
    }

    // MARK: Document

    var title: String {
        string("Service record", "Title of the service record PDF and of its export screens. Also the start of the file name")
    }

    func createdLine(_ day: DayDate) -> String {
        let date = day.formatted(.long, locale: locale)
        return string("Created on \(date)", "Service record PDF: creation date under the title. Argument: the date")
    }

    var footer: String {
        string("Entered by the vehicle owner, not verified. Created with Wagemo.", "Service record PDF: footer on every page. States that the data was entered by the owner and not checked")
    }

    func pageNumber(_ page: Int, of total: Int) -> String {
        string("Page \(page) of \(total)", "Service record PDF: page number in the footer. First argument: this page, second: number of pages")
    }

    // MARK: Vehicle

    var vehicleHeading: String {
        string("Vehicle", "Service record PDF: heading of the vehicle data")
    }

    var notRecorded: String {
        string("Not recorded", "Service record PDF: a vehicle value that the owner did not enter")
    }

    func vehicleRows(_ record: ServiceRecord) -> [Row] {
        let vehicle = record.vehicle
        var rows: [Row] = []
        rows.append(Row(
            label: string("License plate", "Service record PDF: label of the license plate"),
            value: vehicle.licensePlate.isEmpty ? notRecorded : vehicle.licensePlate))

        if let name = makeAndModel(vehicle) {
            rows.append(Row(
                label: string("Make and model", "Service record PDF: label of make and model"),
                value: name))
        }
        if record.options.includeVIN {
            rows.append(Row(
                label: string("VIN", "Service record PDF: label of the vehicle identification number"),
                value: (vehicle.vin ?? "").isEmpty ? notRecorded : (vehicle.vin ?? "")))
        }
        rows.append(Row(
            label: string("First registration", "Service record PDF: label of the month of the first registration"),
            value: vehicle.firstRegistration?.displayString(locale: locale) ?? notRecorded))
        rows.append(Row(
            label: string("Vehicle type", "Service record PDF: label of the vehicle class such as passenger car"),
            value: categoryTitle(vehicle.category)))
        rows.append(Row(label: odometerLabel, value: odometerValue(record.odometer)))
        rows.append(plaqueRow(vehicle.plaque))
        return rows
    }

    private func makeAndModel(_ vehicle: ServiceRecordVehicle) -> String? {
        let parts = [vehicle.make, vehicle.model].compactMap { $0 }.filter { !$0.isEmpty }
        let described = parts.joined(separator: " ")
        let name = vehicle.name.trimmingCharacters(in: .whitespaces)
        if described.isEmpty { return name.isEmpty ? nil : name }
        if name.isEmpty || name == described || name == vehicle.licensePlate { return described }
        return "\(described) (\(name))"
    }

    private func categoryTitle(_ category: VehicleCategory) -> String {
        var resource = category.title
        resource.locale = locale
        return String(localized: resource).withoutSoftHyphens
    }

    private var odometerLabel: String {
        string("Odometer", "Service record PDF: label of the latest known odometer value")
    }

    func kilometersText(_ kilometers: Int) -> String {
        string("\(kilometers.formatted(.number.locale(locale))) km", "Odometer value with unit, shown in the vehicle header")
    }

    private func odometerValue(_ statement: OdometerStatement?) -> String {
        guard let statement else { return notRecorded }
        let km = kilometersText(statement.kilometers)
        let date = statement.date.formatted(.long, locale: locale)
        return string("\(km) (as of \(date))", "Service record PDF: odometer value and the day it was read. First argument: the value with unit, second: the date")
    }

    private func plaqueRow(_ plaque: YearMonth?) -> Row {
        let label = string("Inspection sticker (Pickerl)", "Service record PDF: label of the month punched on the inspection sticker")
        guard let plaque else { return Row(label: label, value: notRecorded) }
        let note = string("Month as entered from the sticker. The sticker on the vehicle is authoritative.", "Service record PDF: note under the punched month of the inspection sticker. Not a calculated deadline")
        return Row(label: label, value: plaque.displayString(locale: locale), note: note)
    }

    // MARK: History

    var historyHeading: String {
        string("Maintenance history", "Service record PDF: heading of the list of history entries")
    }

    func periodLine(_ period: ServiceRecordPeriod) -> String {
        let value: String
        switch period {
        case .all:
            value = string("all entries", "Service record PDF: period value, all entries are listed. Lowercase, used inside a sentence")
        case .since(let day):
            let date = day.formatted(.long, locale: locale)
            value = string("from \(date)", "Service record PDF: period value, entries from a date on. Lowercase, used inside a sentence. Argument: the date")
        }
        return string("Period: \(value)", "Service record PDF: the period of the listed entries. Argument: all entries, or from a date")
    }

    var emptyHistory: String {
        string("No entries in the selected period.", "Service record PDF: shown when the history has no entries in the period")
    }

    var numberHeader: String {
        string("No.", "Service record PDF: table header, number of the entry. Keep it very short")
    }

    var dateHeader: String {
        string("Date", "Service record PDF: table header, date of the work")
    }

    var kilometersHeader: String {
        string("km", "Service record PDF: table header of the odometer column. Keep it very short")
    }

    var categoryHeader: String {
        string("Category", "Service record PDF: table header, kind of work")
    }

    var workHeader: String {
        string("Workshop and work", "Service record PDF: table header, workshop name and what was done")
    }

    var amountHeader: String {
        string("Amount", "Service record PDF: table header, cost of the entry")
    }

    var receiptHeader: String {
        string("Receipt", "Service record PDF: table header, whether a receipt exists. Keep it short")
    }

    func cells(for item: ServiceRecordItem, receiptsAttached: Bool) -> EntryCells {
        let entry = item.entry
        let receipt: String
        if entry.receiptCount == 0 {
            receipt = "–"
        } else if receiptsAttached {
            receipt = string("Attached", "Service record PDF: table cell, the receipt is attached at the end of the document")
        } else {
            receipt = string("Yes", "Service record PDF: table cell, a receipt exists for the entry")
        }
        return EntryCells(
            number: item.number.formatted(.number.grouping(.never).locale(locale)),
            date: entry.date.formatted(.numeric, locale: locale),
            kilometers: entry.odometerKm.map(kilometersText) ?? "–",
            category: entry.category.title(locale: locale),
            workshop: entry.workshop,
            work: entry.workItems.joined(separator: "\n"),
            amount: entry.money.map { MoneyFormat.string($0, locale: locale) },
            receipt: receipt)
    }

    // MARK: Costs

    var costsHeading: String {
        string("Costs", "Chart axis: the amount of money")
    }

    var costsNote: String {
        string("Sums of the listed entries, per currency.", "Service record PDF: note under the costs. Currencies are never converted")
    }

    var totalLabel: String {
        string("Total", "Costs chart: the total of all categories")
    }

    func yearText(_ year: Int) -> String {
        year.formatted(.number.grouping(.never).locale(locale))
    }

    func moneyText(_ money: Money) -> String {
        MoneyFormat.string(money, locale: locale)
    }

    // MARK: Attachments

    var attachmentsHeading: String {
        string("Attached receipts", "Service record PDF: heading of the receipts at the end of the document")
    }

    func attachmentCaption(_ item: ServiceRecordItem) -> String {
        let entry = item.entry
        let parts = [entry.date.formatted(.long, locale: locale), entry.category.title(locale: locale), entry.workshop]
            .filter { !$0.isEmpty }
        let summary = parts.joined(separator: ", ")
        return string("Receipt for entry \(item.number): \(summary)", "Service record PDF: caption above an attached receipt. First argument: the number of the entry in the table, second: its date, category and workshop")
    }

    func receiptPosition(_ index: Int, of count: Int, page: Int, of pages: Int) -> String {
        let receipt = string("Receipt \(index) of \(count)", "Service record PDF: position of an attached receipt among the receipts of one entry. First argument: this receipt, second: number of receipts")
        guard pages > 1 else { return receipt }
        let pageText = string("page \(page) of \(pages)", "Service record PDF: page of a multi-page receipt, lowercase, after the receipt position. First argument: this page, second: number of pages")
        return "\(receipt), \(pageText)"
    }

    var receiptUnavailable: String {
        string("This receipt could not be shown.", "Service record PDF: placeholder where an attached receipt cannot be read or is not on this device yet")
    }
}
