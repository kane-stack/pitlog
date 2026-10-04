import Foundation
import SwiftData

@Model
final class OdometerReading {
    var date: Date = Date()
    var kilometers: Int = 0
    var vehicle: Vehicle?

    init(date: Date = Date(), kilometers: Int = 0, vehicle: Vehicle? = nil) {
        self.date = date
        self.kilometers = kilometers
        self.vehicle = vehicle
    }
}
