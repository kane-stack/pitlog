import Foundation
import PitlogCore
import SwiftData

/// An odometer value in a history entry also becomes an odometer reading, but only if it is newer than
/// the latest reading. Back-dated entries must not disturb the mileage estimate of the reminders.
enum OdometerSync {
    /// `true` if an entry on `entryDay` at `km` is newer than the latest reading: a later day and an odometer
    /// that did not go backwards. Without any reading every value counts.
    static func shouldAddReading(
        entryDay: DayDate, km: Int, latestDay: DayDate?, latestKm: Int?
    ) -> Bool {
        guard km > 0 else { return false }
        guard let latestDay, let latestKm else { return true }
        return entryDay > latestDay && km >= latestKm
    }

    @MainActor
    @discardableResult
    static func addReadingIfNewer(
        for vehicle: Vehicle, day: DayDate, km: Int?, in context: ModelContext,
        timeZone: TimeZone = .current
    ) -> Bool {
        guard let km else { return false }
        let latest = vehicle.odometerReadings?.max { $0.date < $1.date }
        let latestDay = latest.map { CalendarDay.dayDate(from: $0.date, in: timeZone) }
        guard shouldAddReading(entryDay: day, km: km, latestDay: latestDay, latestKm: latest?.kilometers)
        else { return false }
        context.insert(OdometerReading(
            date: CalendarDay.date(from: day, in: timeZone), kilometers: km, vehicle: vehicle))
        return true
    }
}
