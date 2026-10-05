import Foundation
import PitlogCore

/// What the receipt scan needs to know about a vehicle: enough to match and to check plausibility, no model object.
struct ReceiptVehicleInfo: Hashable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let plate: String
    let vin: String?
    let firstRegistration: YearMonth?
    let lastKnownOdometerKm: Int?

    init(
        id: UUID, displayName: String, plate: String, vin: String? = nil,
        firstRegistration: YearMonth? = nil, lastKnownOdometerKm: Int? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.plate = plate
        self.vin = vin
        self.firstRegistration = firstRegistration
        self.lastKnownOdometerKm = lastKnownOdometerKm
    }

    @MainActor
    init(_ vehicle: Vehicle) {
        self.init(
            id: vehicle.id, displayName: vehicle.displayName, plate: vehicle.licensePlate, vin: vehicle.vin,
            firstRegistration: vehicle.firstRegistration, lastKnownOdometerKm: vehicle.currentOdometerKm)
    }
}

/// Finds the vehicle a receipt belongs to. The VIN is the stronger evidence, the plate the fallback. A plate or VIN
/// shared by several vehicles (an archived duplicate) is no match: the user picks.
enum ReceiptVehicleMatcher {
    enum Evidence: Hashable, Sendable {
        case vin
        case plate
    }

    struct Match: Hashable, Sendable {
        let vehicleID: UUID
        let evidence: Evidence
    }

    static func match(plate: String?, vin: String?, in vehicles: [ReceiptVehicleInfo]) -> Match? {
        if let vin = vin.map(ReceiptDraftValidator.compact), vin.count >= 11 {
            let hits = vehicles.filter { $0.vin.map(ReceiptDraftValidator.compact) == vin }
            if hits.count == 1, let hit = hits.first { return Match(vehicleID: hit.id, evidence: .vin) }
        }
        if let plate = plate.map(ReceiptDraftValidator.compact), plate.count >= 3 {
            let hits = vehicles.filter { ReceiptDraftValidator.compact($0.plate) == plate }
            if hits.count == 1, let hit = hits.first { return Match(vehicleID: hit.id, evidence: .plate) }
        }
        return nil
    }
}
