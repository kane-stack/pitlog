import PitlogCore
import SwiftUI

extension RegistrationReviewField {
    /// Field name as in the vehicle form.
    var title: LocalizedStringResource {
        switch self {
        case .licensePlate: LocalizedStringResource("License plate", comment: "Vehicle form: license plate field")
        case .category: LocalizedStringResource("Type", comment: "Vehicle form: vehicle category picker")
        case .make: LocalizedStringResource("Make", comment: "Vehicle form: make field")
        case .model: LocalizedStringResource("Model", comment: "Vehicle form: model field")
        case .vin: LocalizedStringResource("VIN", comment: "Registration review: vehicle identification number")
        case .firstRegistration:
            LocalizedStringResource("First registration", comment: "Registration review: date of the first registration")
        }
    }

    /// The label of the switch that takes the value over.
    var useTitle: LocalizedStringResource {
        switch self {
        case .licensePlate: LocalizedStringResource("Use license plate", comment: "Registration review: switch to copy the scanned license plate into the form")
        case .category: LocalizedStringResource("Use vehicle type", comment: "Registration review: switch to copy the scanned vehicle type into the form")
        case .make: LocalizedStringResource("Use make", comment: "Registration review: switch to copy the scanned make into the form")
        case .model: LocalizedStringResource("Use model", comment: "Registration review: switch to copy the scanned model into the form")
        case .vin: LocalizedStringResource("Use VIN", comment: "Registration review: switch to copy the scanned vehicle identification number into the form")
        case .firstRegistration:
            LocalizedStringResource("Use first registration", comment: "Registration review: switch to copy the scanned first registration into the form")
        }
    }
}

extension ScanConfidence {
    var title: LocalizedStringResource {
        switch self {
        case .high: LocalizedStringResource("Read clearly", comment: "Registration review: the scanned value is reliable")
        case .medium: LocalizedStringResource("Please check", comment: "Registration review: the scanned value may contain a reading error")
        case .low: LocalizedStringResource("Uncertain", comment: "Registration review: the scanned value is doubtful and not used unless switched on")
        }
    }

    /// Never colour alone: every level has its own symbol.
    var symbolName: String {
        switch self {
        case .high: "checkmark.circle"
        case .medium: "exclamationmark.circle"
        case .low: "questionmark.circle"
        }
    }
}

extension RegistrationScanNotice {
    var text: LocalizedStringResource {
        switch self {
        case .partTwo:
            LocalizedStringResource("This is part II of the registration certificate. Its data is usually the same as in part I, which you carry in the car.", comment: "Registration review: notice when part II was scanned")
        case .transferPermit:
            LocalizedStringResource("A transfer permit does not contain the vehicle data. Scan the registration certificate (part I) instead.", comment: "Registration scan: a transfer permit was scanned")
        case .cardBackSideMissing:
            LocalizedStringResource("Only the front of the card was read. Scan the back as well for VIN, make and model.", comment: "Registration review: notice when only the front of the chip card was scanned")
        case .cardFrontSideMissing:
            LocalizedStringResource("Only the back of the card was read. Scan the front as well for the license plate and the first registration.", comment: "Registration review: notice when only the back of the chip card was scanned")
        case .cardFrontUnreadable:
            LocalizedStringResource("The license plate and the first registration could not be read from the front of the card. Try again with better light, or enter them yourself.", comment: "Registration review: notice when the front of the chip card was scanned but plate and first registration could not be read")
        case .cardBackUnreadable:
            LocalizedStringResource("VIN, make and model could not be read from the back of the card. Try again with better light, or enter them yourself.", comment: "Registration review: notice when the back of the chip card was scanned but VIN, make and model could not be read")
        }
    }
}
