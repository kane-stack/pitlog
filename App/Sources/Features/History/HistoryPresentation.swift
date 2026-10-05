import Foundation
import PitlogCore
import SwiftUI

extension MaintenanceCategory {
    var iconName: String {
        switch self {
        case .service: "wrench.and.screwdriver"
        case .repair: "hammer"
        case .tyres: "circle.circle"
        case .inspection: "checkmark.seal"
        case .otherWorkshop: "ellipsis.circle"
        }
    }

    /// Chart color. Never the only cue: the legend and the chart rows always add the icon and the name.
    var color: Color {
        switch self {
        case .service: .blue
        case .repair: .red
        case .tyres: .green
        case .inspection: .purple
        case .otherWorkshop: .gray
        }
    }

    func title(locale: Locale) -> String {
        switch self {
        case .service:
            String(localized: "Service", locale: locale, comment: "Reminder type: vehicle service")
        case .repair:
            String(localized: "Repair", locale: locale, comment: "History category: a repair at a workshop")
        case .tyres:
            String(localized: "Tyres", locale: locale, comment: "History category: tyre change or purchase at a workshop")
        case .inspection:
            String(localized: "Inspection", locale: locale, comment: "Notification title part: the periodic vehicle inspection (Pickerl)")
        case .otherWorkshop:
            String(localized: "Other workshop", locale: locale, comment: "History category: any other workshop work")
        }
    }
}

enum MoneyFormat {
    /// "€1,234.56" / "1.234,56 €": only via `FormatStyle.Currency`.
    static func string(_ money: Money, locale: Locale) -> String {
        money.amount.formatted(.currency(code: money.currencyCode).locale(locale))
    }

    /// Whole units for chart axes.
    static func wholeUnits(_ value: Double, currency: String, locale: Locale) -> String {
        value.formatted(.currency(code: currency).precision(.fractionLength(0)).locale(locale))
    }

    /// The currency of the device's region ("EUR" for Austria).
    static func defaultCurrency(locale: Locale) -> String {
        locale.currency?.identifier ?? "EUR"
    }

    /// Currencies offered in the editor: common ones for the markets of the app, plus `extra`.
    static func choices(including extra: [String], locale: Locale) -> [String] {
        var codes = [defaultCurrency(locale: locale), "EUR", "CHF", "GBP", "USD", "CZK", "HUF", "PLN"]
        codes.append(contentsOf: extra)
        var seen = Set<String>()
        return codes.filter { seen.insert($0).inserted }
    }

    static func name(of code: String, locale: Locale) -> String {
        let name = locale.localizedString(forCurrencyCode: code) ?? code
        return "\(name) (\(code))"
    }

    /// The amount as plain digits for an edit field, in the locale's decimal separator.
    static func editText(_ money: Money, locale: Locale) -> String {
        let digits = Money.minorUnitDigits(for: money.currencyCode)
        return money.amount.formatted(
            .number.grouping(.never).precision(.fractionLength(digits)).locale(locale))
    }

    enum Parsed: Equatable {
        case empty
        case invalid
        case value(Money)
    }

    /// Parses what the user typed. Negative amounts are refused.
    static func parse(_ text: String, currency: String, locale: Locale) -> Parsed {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        guard let decimal = try? Decimal(trimmed, format: .number.locale(locale), lenient: true),
              decimal >= 0,
              let money = Money(amount: decimal, currencyCode: currency)
        else { return .invalid }
        return .value(money)
    }
}

/// A new entry with some fields filled in (from the inspection or service flows).
struct EntryPrefill {
    var category: MaintenanceCategory
    var date: DayDate
    var km: Int?
    var workItems = ""
}

/// What the entry editor sheet opens: an existing entry, a new empty one or a new prefilled one.
struct EntryEditorTarget: Identifiable {
    let id = UUID()
    let entry: MaintenanceEntry?
    let prefill: EntryPrefill?

    static func new() -> EntryEditorTarget { EntryEditorTarget(entry: nil, prefill: nil) }
    static func edit(_ entry: MaintenanceEntry) -> EntryEditorTarget { EntryEditorTarget(entry: entry, prefill: nil) }
    static func prefilled(_ prefill: EntryPrefill) -> EntryEditorTarget { EntryEditorTarget(entry: nil, prefill: prefill) }
}

/// Entries of a vehicle, filtered and grouped by year, newest first.
enum HistoryTimeline {
    struct YearGroup: Identifiable {
        let year: Int
        let entries: [MaintenanceEntry]
        var id: Int { year }
    }

    static func sorted(_ entries: [MaintenanceEntry]) -> [MaintenanceEntry] {
        entries.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.createdAt > rhs.createdAt
        }
    }

    static func groups(_ entries: [MaintenanceEntry], filter: MaintenanceCategory?) -> [YearGroup] {
        let kept = sorted(entries).filter { filter == nil || $0.category == filter }
        var result: [YearGroup] = []
        for entry in kept {
            if let last = result.last, last.year == entry.date.year {
                result[result.count - 1] = YearGroup(year: last.year, entries: last.entries + [entry])
            } else {
                result.append(YearGroup(year: entry.date.year, entries: [entry]))
            }
        }
        return result
    }
}

/// Texts and the VoiceOver label of one history row. Dates are spelled out; nothing relies on color.
struct HistoryRowPresentation {
    let entry: MaintenanceEntry
    let locale: Locale

    var categoryTitle: String { entry.category.title(locale: locale) }
    var dateText: String { entry.date.formatted(.abbreviated, locale: locale) }
    var longDateText: String { entry.date.formatted(.long, locale: locale) }
    var workshop: String? { entry.workshop.isEmpty ? nil : entry.workshop }
    var amountText: String? { entry.money.map { MoneyFormat.string($0, locale: locale) } }

    var kmText: String? {
        entry.odometerKm.map {
            String(localized: "\($0.formatted(.number.locale(locale))) km", locale: locale, comment: "Odometer value with unit, shown in the vehicle header")
        }
    }

    /// The first work items as a list ("Oil change, filter and brake fluid"), more are counted.
    var workSummary: String? {
        let lines = entry.workLines
        guard !lines.isEmpty else { return nil }
        let shown = Array(lines.prefix(3))
        let list = shown.formatted(.list(type: .and).locale(locale))
        let more = lines.count - shown.count
        guard more > 0 else { return list }
        return String(localized: "\(list) and \(more) more", locale: locale, comment: "History row: the first work items, then how many more there are. First argument: a list of work items, second: the number of further items")
    }

    var receiptCount: Int { entry.receipts?.count ?? 0 }

    var accessibilityLabel: String {
        var parts = [categoryTitle, longDateText]
        if let workshop { parts.append(workshop) }
        if let workSummary { parts.append(workSummary) }
        if let amountText { parts.append(amountText) }
        if let kmText { parts.append(kmText) }
        if receiptCount > 0 {
            parts.append(String(localized: "\(receiptCount) receipts attached", locale: locale, comment: "VoiceOver: a history entry has receipts attached, plural"))
        }
        return parts.joined(separator: ". ")
    }
}

/// Amount next to its label: side by side normally, stacked at accessibility sizes so neither is squeezed.
struct AmountLayout<Leading: View, Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let leading: Leading
    let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                leading
                trailing
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                leading
                Spacer(minLength: 8)
                trailing
            }
        }
    }
}

extension View {
    /// "Add to history?" after finishing an inspection or a service. "Add to history" opens the editor with
    /// the prefilled entry in `editor`; "Not now" drops the offer.
    func historyOfferAlert(
        isPresented: Binding<Bool>, offer: Binding<EntryPrefill?>, editor: Binding<EntryEditorTarget?>,
        message: Text
    ) -> some View {
        alert(
            Text("Add to history?", comment: "Alert title after an inspection or service: offer to log it in the history"),
            isPresented: isPresented
        ) {
            Button {
                if let prefill = offer.wrappedValue { editor.wrappedValue = .prefilled(prefill) }
                offer.wrappedValue = nil
            } label: {
                Text("Add to history", comment: "Alert button: open the new history entry")
            }
            .accessibilityIdentifier("addToHistoryButton")
            Button(role: .cancel) {
                offer.wrappedValue = nil
            } label: {
                Text("Not now", comment: "Alert button: decline an offer for now")
            }
        } message: {
            message
        }
    }
}
