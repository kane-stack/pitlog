import PitlogCore
import SwiftUI

/// What the review's confirm button does.
enum ReceiptReviewMode {
    /// Creates a new history entry (the history screen).
    case saveEntry
    /// Copies the values into the entry editor, which saves on its own (ADR-5 style: nothing is saved behind the
    /// user's back).
    case fillForm
}

extension ReceiptReviewField {
    var title: LocalizedStringResource {
        switch self {
        case .date: LocalizedStringResource("Date", comment: "Reminder editor: date of the reminder")
        case .amount: LocalizedStringResource("Amount", comment: "Entry editor: what the visit cost")
        case .workshop: LocalizedStringResource("Workshop", comment: "Entry editor: name of the workshop")
        case .category: LocalizedStringResource("Category", comment: "History: category filter and entry editor field")
        case .workItems: LocalizedStringResource("Work done", comment: "Entry editor: what the workshop did, one item per line")
        case .odometer: LocalizedStringResource("Odometer (km)", comment: "Entry editor: odometer reading at the visit, with unit")
        }
    }

    /// The label of the switch that takes the value over.
    var useTitle: LocalizedStringResource {
        switch self {
        case .date: LocalizedStringResource("Use date", comment: "Receipt review: switch to take the scanned date over into the entry")
        case .amount: LocalizedStringResource("Use amount", comment: "Receipt review: switch to take the scanned total over into the entry")
        case .workshop: LocalizedStringResource("Use workshop", comment: "Receipt review: switch to take the scanned workshop name over into the entry")
        case .category: LocalizedStringResource("Use category", comment: "Receipt review: switch to take the guessed category over into the entry")
        case .workItems: LocalizedStringResource("Use work done", comment: "Receipt review: switch to take the scanned work items over into the entry")
        case .odometer: LocalizedStringResource("Use odometer reading", comment: "Receipt review: switch to take the scanned odometer reading over into the entry")
        }
    }
}

extension FieldConfidence {
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

extension ReceiptAgreement {
    /// An extra sentence under the confidence, `nil` when there is nothing to add.
    var note: LocalizedStringResource? {
        switch self {
        case .single:
            nil
        case .agreed:
            LocalizedStringResource("Two independent readings agree.", comment: "Receipt review: the rules and the on-device model read the same value")
        case .conflict:
            LocalizedStringResource("The two readings differ. Choose the right one below.", comment: "Receipt review: the rules and the on-device model read different values")
        case .qrCode:
            LocalizedStringResource("Taken from the QR code of the cash register receipt.", comment: "Receipt review: the value comes from the RKSV QR code")
        }
    }
}

extension ReceiptSource {
    var title: LocalizedStringResource {
        switch self {
        case .heuristic: LocalizedStringResource("Receipt text", comment: "Receipt review: name of the reader that works with the printed text and labels")
        case .model: LocalizedStringResource("Apple Intelligence", comment: "Receipt review: name of the on-device language model")
        case .qrCode: LocalizedStringResource("QR code", comment: "Receipt review: name of the cash register QR code as a source")
        }
    }
}

extension ReceiptReviewValue {
    /// The value as text for a list of readings.
    func displayText(locale: Locale) -> String {
        switch self {
        case .day(let day):
            return day.formatted(.long, locale: locale)
        case .money(let money):
            return MoneyFormat.string(money, locale: locale)
        case .text(let text):
            return text
        case .kilometers(let km):
            return String(localized: "\(km.formatted(.number.locale(locale))) km", locale: locale, comment: "Odometer value with unit, shown in the vehicle header")
        case .category(let category):
            return category.title(locale: locale)
        case .lines(let lines):
            return lines.joined(separator: ", ")
        }
    }
}

extension ReceiptReviewItem {
    /// The sentence that says where the selected value came from.
    func sourceText(locale: Locale) -> String? {
        guard choices.indices.contains(selectedChoice) else { return nil }
        switch choices[selectedChoice].source {
        case .model:
            return String(localized: "Read by the on-device language model.", locale: locale, comment: "Receipt review: the value comes from the language model, which has no source line")
        case .qrCode:
            return nil
        case .heuristic:
            guard let snippet, !snippet.isEmpty else { return nil }
            return String(localized: "Read as “\(snippet)”", locale: locale, comment: "Receipt review: the printed text a value was read from")
        }
    }
}
