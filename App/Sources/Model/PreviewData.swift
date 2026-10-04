import Foundation
import PitlogCore
import SwiftData

/// Sample vehicles for previews and UI tests (`-UITestSampleData`).
enum PreviewData {
    @MainActor
    static func container(withSamples: Bool = true) -> ModelContainer {
        let container = try! ModelContainerFactory.inMemory()
        if withSamples { insertSamples(into: container.mainContext) }
        return container
    }

    @MainActor
    static func insertSamples(into context: ModelContext) {
        let golf = Vehicle(
            name: "Golf",
            licensePlate: "W 12345 A",
            category: .passengerCar,
            firstRegistration: YearMonth(year: 2020, month: 6),
            plaque: YearMonth(year: 2027, month: 6)
        )
        golf.make = "Volkswagen"
        golf.model = "Golf"
        context.insert(golf)
        context.insert(OdometerReading(date: Date(timeIntervalSince1970: 1_780_000_000), kilometers: 68_400, vehicle: golf))

        let transporter = Vehicle(
            name: "Transporter",
            licensePlate: "L 777 BX",
            category: .lightCommercial,
            firstRegistration: YearMonth(year: 2022, month: 3),
            plaque: YearMonth(year: 2027, month: 3)
        )
        context.insert(transporter)

        let estimated = Vehicle(
            name: "Fiat 500",
            licensePlate: "G 4711 K",
            category: .passengerCar,
            firstRegistration: YearMonth(year: 2018, month: 9)
        )
        context.insert(estimated)

        let manual = Vehicle(name: "Traktor", licensePlate: "", category: .other)
        context.insert(manual)
    }
}
