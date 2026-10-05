import Foundation
import PitlogCore
import SwiftData

/// Turns a `Vehicle` and the user's options into the values the pure `ServiceRecord` and the renderer work on.
enum ServiceRecordFactory {
    /// Everything the export needs, as plain values. Only this crosses to the background task.
    struct Prepared: Sendable {
        let record: ServiceRecord
        let receipts: [String: [ServiceRecordReceiptFile]]
    }

    @MainActor
    static func prepare(
        vehicle: Vehicle, options: ServiceRecordOptions, today: DayDate, timeZone: TimeZone = .current
    ) -> Prepared {
        let shownVehicle = ServiceRecordVehicle(
            licensePlate: vehicle.licensePlate.trimmingCharacters(in: .whitespacesAndNewlines),
            name: vehicle.name,
            make: vehicle.make,
            model: vehicle.model,
            vin: vehicle.vin?.trimmingCharacters(in: .whitespacesAndNewlines),
            category: vehicle.category,
            firstRegistration: vehicle.firstRegistration,
            plaque: vehicle.plaque)
        let readings = (vehicle.odometerReadings ?? []).map {
            OdometerStatement(kilometers: $0.kilometers, date: CalendarDay.dayDate(from: $0.date, in: timeZone))
        }
        let stored = vehicle.maintenanceEntries ?? []
        let entries = stored.map { entry in
            ServiceRecordEntry(
                id: entry.id.uuidString,
                date: entry.date,
                odometerKm: entry.odometerKm,
                category: entry.category,
                workshop: entry.workshop.trimmingCharacters(in: .whitespacesAndNewlines),
                workItems: entry.workLines,
                money: entry.money,
                receiptCount: (entry.receipts ?? []).filter { $0.data != nil }.count)
        }
        let record = ServiceRecord(
            vehicle: shownVehicle, odometerReadings: readings, entries: entries, options: options, today: today)

        var receipts: [String: [ServiceRecordReceiptFile]] = [:]
        if options.includeReceiptAttachments {
            let wanted = Set(record.attachmentItems.map(\.entry.id))
            for entry in stored where wanted.contains(entry.id.uuidString) {
                let files = (entry.receipts ?? [])
                    .sorted { $0.createdAt < $1.createdAt }
                    .compactMap { receipt in
                        receipt.data.map { ServiceRecordReceiptFile(data: $0, isPDF: receipt.isPDF) }
                    }
                receipts[entry.id.uuidString] = files
            }
        }
        return Prepared(record: record, receipts: receipts)
    }
}

/// A finished PDF on disk, ready to preview and share.
struct ExportedServiceRecord: Hashable, Sendable, Identifiable {
    let id = UUID()
    let url: URL
    let fileName: String
    let pageCount: Int
}

enum ServiceRecordExporter {
    /// Renders on a background task and writes the file into the temporary folder.
    static func export(_ prepared: ServiceRecordFactory.Prepared, locale: Locale) async throws -> ExportedServiceRecord {
        try await Task.detached(priority: .userInitiated) {
            let texts = ServiceRecordTexts(locale: locale)
            let output = ServiceRecordPDFRenderer(
                record: prepared.record, texts: texts, receipts: prepared.receipts
            ).render()
            let vehicle = prepared.record.vehicle
            let name = ServiceRecordFileName.make(
                title: texts.title,
                plate: vehicle.licensePlate.isEmpty ? vehicle.name : vehicle.licensePlate,
                date: prepared.record.createdOn)
            let url = try ServiceRecordTempFiles.write(output.data, named: name)
            return ExportedServiceRecord(url: url, fileName: name, pageCount: output.pageCount)
        }.value
    }
}

/// The exported PDFs live in the temporary folder only. They are removed when the export sheet closes and
/// whenever the app starts, so no copy of a (possibly personal) document stays behind.
enum ServiceRecordTempFiles {
    static var root: URL {
        FileManager.default.temporaryDirectory.appending(path: "ServiceRecords", directoryHint: .isDirectory)
    }

    static func write(_ data: Data, named name: String) throws -> URL {
        let folder = root.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: name, directoryHint: .notDirectory)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return url
    }

    /// Removes everything this feature wrote.
    static func sweep() {
        try? FileManager.default.removeItem(at: root)
    }
}
