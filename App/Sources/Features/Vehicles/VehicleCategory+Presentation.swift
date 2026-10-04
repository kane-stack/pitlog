import PitlogCore
import SwiftUI

extension VehicleCategory {
    var title: LocalizedStringResource {
        switch self {
        case .passengerCar:
            LocalizedStringResource("Passenger car", comment: "Vehicle category")
        case .motorcycle:
            LocalizedStringResource("Motorcycle or moped (class L)", comment: "Vehicle category, EU class L")
        case .lightTrailer:
            LocalizedStringResource("Light trailer (up to 3.5 t)", comment: "Vehicle category, trailer O1/O2")
        case .lightCommercial:
            LocalizedStringResource("Light commercial vehicle (N1)", comment: "Vehicle category, N1")
        case .taxiOrAmbulance:
            LocalizedStringResource("Taxi, ambulance or patient transport", comment: "Vehicle category")
        case .historic:
            LocalizedStringResource("Historic vehicle", comment: "Vehicle category")
        case .other:
            LocalizedStringResource("Other (enter date manually)", comment: "Vehicle category for vehicles the app cannot calculate; the user enters the inspection date")
        }
    }

    var symbolName: String {
        switch self {
        case .passengerCar, .historic: "car"
        case .motorcycle: "motorcycle"
        case .lightTrailer: "box.truck"
        case .lightCommercial: "box.truck"
        case .taxiOrAmbulance: "cross.case"
        case .other: "questionmark.square.dashed"
        }
    }
}

extension InspectionService.UnavailableReason {
    func text(locale: Locale) -> String {
        switch self {
        case .missingFirstRegistration:
            String(localized: "Add the first registration to see the deadline.", locale: locale, comment: "Shown when no inspection deadline can be calculated because the first registration is missing")
        case .unsupportedCategory:
            String(localized: "Not calculated for this vehicle type. Enter the date manually.", locale: locale, comment: "Shown for vehicle types without a rule set")
        case .unsupportedCountry:
            String(localized: "Not calculated for this country yet.", locale: locale, comment: "Shown when the country has no rule set")
        case .invalidInput:
            String(localized: "The entered dates do not fit together. Check the first registration and the sticker.", locale: locale, comment: "Shown when the rule engine rejects the input")
        }
    }
}
