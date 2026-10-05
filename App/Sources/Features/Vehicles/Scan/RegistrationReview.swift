import Foundation
import PitlogCore

/// The vehicle form fields a scan can fill. The order is the order on the review screen.
enum RegistrationReviewField: String, CaseIterable, Identifiable, Sendable {
    case licensePlate, category, make, model, vin, firstRegistration

    var id: String { rawValue }
}

/// One scanned value on the review screen: what was read, how sure the parser is, and whether the user wants it.
struct RegistrationReviewItem: Identifiable, Equatable {
    let field: RegistrationReviewField
    /// Switched on = copied into the form on "Apply".
    var included: Bool
    /// The editable value of plate, make, model and VIN.
    var text = ""
    var month: Int?
    var year: Int?
    var category: VehicleCategory = .other
    let confidence: ScanConfidence
    /// The text the value was read from, as a snippet.
    let rawText: String
    /// The field code(s) as printed on the certificate, for the snippet.
    let source: String

    var id: RegistrationReviewField { field }
}

/// What "Apply" puts into the form. Only the values the user left switched on.
struct RegistrationPrefill: Equatable {
    var licensePlate: String?
    var category: VehicleCategory?
    var make: String?
    var model: String?
    var vin: String?
    var firstRegistration: YearMonth?
}

/// The review screen's state: a draft of the parser, turned into items the user can accept, edit or discard.
/// Nothing leaves this type except the prefill; the form saves only on its own "Save".
struct RegistrationReview: Equatable {
    var items: [RegistrationReviewItem]
    let notices: Set<RegistrationScanNotice>

    /// High and medium confidence are switched on, low confidence is off until the user turns it on.
    static func isIncludedByDefault(_ confidence: ScanConfidence) -> Bool {
        confidence != .low
    }

    init(draft: RegistrationDraft) {
        notices = draft.notices
        var items: [RegistrationReviewItem] = []

        func add<Value: Hashable & Sendable>(
            _ field: RegistrationReviewField, _ scanned: ScannedField<Value>?, source: String,
            configure: (inout RegistrationReviewItem, Value) -> Void
        ) {
            guard let scanned else { return }
            var item = RegistrationReviewItem(
                field: field, included: Self.isIncludedByDefault(scanned.confidence),
                confidence: scanned.confidence, rawText: scanned.rawText, source: source)
            configure(&item, scanned.value)
            items.append(item)
        }

        add(.licensePlate, draft.plate, source: "A") { $0.text = $1 }
        add(.category, draft.category, source: draft.usageCode == nil ? "J" : "J, A.4") { $0.category = $1 }
        add(.make, draft.make, source: "D.1") { $0.text = $1 }
        // The form has one model field: the commercial name (D.3), else type/variant/version (D.2).
        if draft.commercialName != nil {
            add(.model, draft.commercialName, source: "D.3") { $0.text = $1 }
        } else {
            add(.model, draft.type, source: "D.2") { $0.text = $1 }
        }
        add(.vin, draft.vin, source: "E") { $0.text = $1 }
        add(.firstRegistration, draft.firstRegistration, source: "B") {
            $0.month = $1.month
            $0.year = $1.year
        }
        self.items = items
    }

    var isEmpty: Bool { items.isEmpty }

    /// At least one value is switched on and usable.
    var hasSelection: Bool { prefill != RegistrationPrefill() }

    var prefill: RegistrationPrefill {
        var result = RegistrationPrefill()
        for item in items where item.included {
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            switch item.field {
            case .licensePlate: result.licensePlate = text.isEmpty ? nil : text
            case .category: result.category = item.category
            case .make: result.make = text.isEmpty ? nil : text
            case .model: result.model = text.isEmpty ? nil : text
            case .vin:
                let vin = text.uppercased().filter { !$0.isWhitespace }
                result.vin = vin.isEmpty ? nil : vin
            case .firstRegistration:
                if let year = item.year, let month = item.month {
                    result.firstRegistration = YearMonth(year: year, month: month)
                }
            }
        }
        return result
    }

    /// The vehicle class is one the inspection rules cannot calculate (heavy vehicles, tractors, ...).
    var categoryIsUnsupported: Bool {
        items.first { $0.field == .category }?.category == .other
    }
}
