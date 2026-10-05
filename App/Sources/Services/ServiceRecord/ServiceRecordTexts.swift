import Foundation
import PitlogCore

/// All texts of the service record PDF, resolved for one locale. The renderer does not depend on the device
/// language this way, and the tests can render the same record in English and German. Dates, numbers and
/// amounts only go through `FormatStyle`.
struct ServiceRecordTexts: Sendable {
    let locale: Locale

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
        String(localized: "Service record", locale: locale, comment: "Title of the service record PDF and of its export screens. Also the start of the file name")
    }

    func createdLine(_ day: DayDate) -> String {
        let date = day.formatted(.long, locale: locale)
        return String(localized: "Created on \(date)", locale: locale, comment: "Service record PDF: creation date under the title. Argument: the date")
    }

    var footer: String {
        String(localized: "Entered by the vehicle owner, not verified. Created with Pitlog.", locale: locale, comment: "Service record PDF: footer on every page. States that the data was entered by the owner and not checked")
    }

    func pageNumber(_ page: Int, of total: Int) -> String {
        String(localized: "Page \(page) of \(total)", locale: locale, comment: "Service record PDF: page number in the footer. First argument: this page, second: number of pages")
    }

    // MARK: Vehicle

    var vehicleHeading: String {
        String(localized: "Vehicle", locale: locale, comment: "Service record PDF: heading of the vehicle data")
    }

    var notRecorded: String {
        String(localized: "Not recorded", locale: locale, comment: "Service record PDF: a vehicle value that the owner did not enter")
    }

    func vehicleRows(_ record: ServiceRecord) -> [Row] {
        let vehicle = record.vehicle
        var rows: [Row] = []
        rows.append(Row(
            label: String(localized: "License plate", locale: locale, comment: "Service record PDF: label of the license plate"),
            value: vehicle.licensePlate.isEmpty ? notRecorded : vehicle.licensePlate))

        if let name = makeAndModel(vehicle) {
            rows.append(Row(
                label: String(localized: "Make and model", locale: locale, comment: "Service record PDF: label of make and model"),
                value: name))
        }
        if record.options.includeVIN {
            rows.append(Row(
                label: String(localized: "VIN", locale: locale, comment: "Service record PDF: label of the vehicle identification number"),
                value: (vehicle.vin ?? "").isEmpty ? notRecorded : (vehicle.vin ?? "")))
        }
        rows.append(Row(
            label: String(localized: "First registration", locale: locale, comment: "Service record PDF: label of the month of the first registration"),
            value: vehicle.firstRegistration?.displayString(locale: locale) ?? notRecorded))
        rows.append(Row(
            label: String(localized: "Vehicle type", locale: locale, comment: "Service record PDF: label of the vehicle class such as passenger car"),
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
        return String(localized: resource)
    }

    private var odometerLabel: String {
        String(localized: "Odometer", locale: locale, comment: "Service record PDF: label of the latest known odometer value")
    }

    func kilometersText(_ kilometers: Int) -> String {
        String(localized: "\(kilometers.formatted(.number.locale(locale))) km", locale: locale, comment: "Odometer value with unit, shown in the vehicle header")
    }

    private func odometerValue(_ statement: OdometerStatement?) -> String {
        guard let statement else { return notRecorded }
        let km = kilometersText(statement.kilometers)
        let date = statement.date.formatted(.long, locale: locale)
        return String(localized: "\(km) (as of \(date))", locale: locale, comment: "Service record PDF: odometer value and the day it was read. First argument: the value with unit, second: the date")
    }

    private func plaqueRow(_ plaque: YearMonth?) -> Row {
        let label = String(localized: "Inspection sticker (Pickerl)", locale: locale, comment: "Service record PDF: label of the month punched on the inspection sticker")
        guard let plaque else { return Row(label: label, value: notRecorded) }
        let note = String(localized: "Month as entered from the sticker. The sticker on the vehicle is authoritative.", locale: locale, comment: "Service record PDF: note under the punched month of the inspection sticker. Not a calculated deadline")
        return Row(label: label, value: plaque.displayString(locale: locale), note: note)
    }

    // MARK: History

    var historyHeading: String {
        String(localized: "Maintenance history", locale: locale, comment: "Service record PDF: heading of the list of history entries")
    }

    func periodLine(_ period: ServiceRecordPeriod) -> String {
        let value: String
        switch period {
        case .all:
            value = String(localized: "all entries", locale: locale, comment: "Service record PDF: period value, all entries are listed. Lowercase, used inside a sentence")
        case .since(let day):
            let date = day.formatted(.long, locale: locale)
            value = String(localized: "from \(date)", locale: locale, comment: "Service record PDF: period value, entries from a date on. Lowercase, used inside a sentence. Argument: the date")
        }
        return String(localized: "Period: \(value)", locale: locale, comment: "Service record PDF: the period of the listed entries. Argument: all entries, or from a date")
    }

    var emptyHistory: String {
        String(localized: "No entries in the selected period.", locale: locale, comment: "Service record PDF: shown when the history has no entries in the period")
    }

    var numberHeader: String {
        String(localized: "No.", locale: locale, comment: "Service record PDF: table header, number of the entry. Keep it very short")
    }

    var dateHeader: String {
        String(localized: "Date", locale: locale, comment: "Service record PDF: table header, date of the work")
    }

    var kilometersHeader: String {
        String(localized: "km", locale: locale, comment: "Service record PDF: table header of the odometer column. Keep it very short")
    }

    var categoryHeader: String {
        String(localized: "Category", locale: locale, comment: "Service record PDF: table header, kind of work")
    }

    var workHeader: String {
        String(localized: "Workshop and work", locale: locale, comment: "Service record PDF: table header, workshop name and what was done")
    }

    var amountHeader: String {
        String(localized: "Amount", locale: locale, comment: "Service record PDF: table header, cost of the entry")
    }

    var receiptHeader: String {
        String(localized: "Receipt", locale: locale, comment: "Service record PDF: table header, whether a receipt exists. Keep it short")
    }

    func cells(for item: ServiceRecordItem, receiptsAttached: Bool) -> EntryCells {
        let entry = item.entry
        let receipt: String
        if entry.receiptCount == 0 {
            receipt = "–"
        } else if receiptsAttached {
            receipt = String(localized: "Attached", locale: locale, comment: "Service record PDF: table cell, the receipt is attached at the end of the document")
        } else {
            receipt = String(localized: "Yes", locale: locale, comment: "Service record PDF: table cell, a receipt exists for the entry")
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
        String(localized: "Costs", locale: locale, comment: "Chart axis: the amount of money")
    }

    var costsNote: String {
        String(localized: "Sums of the listed entries, per currency.", locale: locale, comment: "Service record PDF: note under the costs. Currencies are never converted")
    }

    var totalLabel: String {
        String(localized: "Total", locale: locale, comment: "Costs chart: the total of all categories")
    }

    func yearText(_ year: Int) -> String {
        year.formatted(.number.grouping(.never).locale(locale))
    }

    func moneyText(_ money: Money) -> String {
        MoneyFormat.string(money, locale: locale)
    }

    // MARK: Attachments

    var attachmentsHeading: String {
        String(localized: "Attached receipts", locale: locale, comment: "Service record PDF: heading of the receipts at the end of the document")
    }

    func attachmentCaption(_ item: ServiceRecordItem) -> String {
        let entry = item.entry
        let parts = [entry.date.formatted(.long, locale: locale), entry.category.title(locale: locale), entry.workshop]
            .filter { !$0.isEmpty }
        let summary = parts.joined(separator: ", ")
        return String(localized: "Receipt for entry \(item.number): \(summary)", locale: locale, comment: "Service record PDF: caption above an attached receipt. First argument: the number of the entry in the table, second: its date, category and workshop")
    }

    func receiptPosition(_ index: Int, of count: Int, page: Int, of pages: Int) -> String {
        let receipt = String(localized: "Receipt \(index) of \(count)", locale: locale, comment: "Service record PDF: position of an attached receipt among the receipts of one entry. First argument: this receipt, second: number of receipts")
        guard pages > 1 else { return receipt }
        let pageText = String(localized: "page \(page) of \(pages)", locale: locale, comment: "Service record PDF: page of a multi-page receipt, lowercase, after the receipt position. First argument: this page, second: number of pages")
        return "\(receipt), \(pageText)"
    }

    var receiptUnavailable: String {
        String(localized: "This receipt could not be shown.", locale: locale, comment: "Service record PDF: placeholder where an attached receipt cannot be read or is not on this device yet")
    }
}
