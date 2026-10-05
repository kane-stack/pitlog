import SwiftUI

/// Menu picker for a number (days, km, months). Steppers and numeric text fields fail the Dynamic Type audit
/// in these forms; the menu row is the pattern the vehicle form already uses.
struct LeadPicker: View {
    let title: Text
    @Binding var value: Int
    /// Offered values. A stored value outside the list stays selectable.
    let options: [Int]
    let valueText: (Int) -> Text

    private var allOptions: [Int] {
        options.contains(value) ? options : (options + [value]).sorted()
    }

    var body: some View {
        MenuPickerRow(title: title, valueText: valueText(value), selection: $value) {
            ForEach(allOptions, id: \.self) { option in
                valueText(option).tag(option)
            }
        }
    }
}

/// Common value formats and option lists.
enum LeadOptions {
    static let days = [0, 1, 2, 3, 5, 7, 10, 14, 21, 28, 30, 45, 60, 90]
    static let leadKm = [0, 100, 250, 500, 750, 1_000, 1_500, 2_000]
    static let repeatMonths = [1, 2, 3, 6, 9, 12, 18, 24, 36, 48, 60]
    static let repeatKm = [5_000, 7_500, 10_000, 15_000, 20_000, 25_000, 30_000]

    static func days(_ value: Int) -> Text {
        Text("\(value) days", comment: "Number of days in a picker value, plural")
    }

    static func months(_ value: Int) -> Text {
        Text("\(value) months", comment: "Number of months in a picker value, plural")
    }

    static func kilometers(_ value: Int) -> Text {
        Text("\(value) km", comment: "Number of kilometres in a picker value")
    }
}
