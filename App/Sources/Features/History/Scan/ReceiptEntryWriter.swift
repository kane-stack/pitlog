import Foundation
import PitlogCore
import SwiftData

/// Creates the history entry for a confirmed receipt scan ("Add from receipt"). The scan becomes a
/// `ReceiptDocument` with its recognized text.
enum ReceiptEntryWriter {
    /// A new entry for `vehicle` with the values the user kept. A switched-off date becomes today, a switched-off
    /// category "other workshop". The odometer reading follows the M4 rule (`OdometerSync`): only if the value is
    /// newer than the latest reading.
    @MainActor
    @discardableResult
    static func createEntry(
        from application: ReceiptApplication, attachment: ReceiptAttachment?, vehicle: Vehicle,
        in context: ModelContext, today: DayDate = CalendarDay.today(in: .current)
    ) -> MaintenanceEntry {
        let day = application.date ?? today
        let entry = MaintenanceEntry(date: day, category: application.category ?? .otherWorkshop)
        context.insert(entry)
        entry.vehicle = vehicle
        entry.workshop = application.workshop ?? ""
        entry.workItems = application.workItems ?? ""
        entry.odometerKm = application.odometerKm
        if let amount = application.amount {
            entry.amountMinor = Int(clamping: amount.amountMinor)
            entry.currencyCode = amount.currencyCode
        }
        if let attachment {
            let stored = ReceiptDocument(
                data: attachment.data, contentType: attachment.contentType, pageCount: attachment.pageCount)
            stored.recognizedText = attachment.recognizedText
            context.insert(stored)
            stored.entry = entry
        }
        OdometerSync.addReadingIfNewer(for: vehicle, day: day, km: application.odometerKm, in: context)
        return entry
    }
}
