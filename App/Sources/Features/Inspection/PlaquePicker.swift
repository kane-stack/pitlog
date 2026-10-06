import PitlogCore
import SwiftUI

/// Texts the plaque picker exposes to VoiceOver. Pure so it can be tested.
enum PlaqueAccessibility {
    static func value(for plaque: YearMonth?, locale: Locale) -> String {
        guard let plaque else {
            return String(localized: "Not set", locale: locale, comment: "VoiceOver value of the inspection sticker picker when nothing is entered")
        }
        return plaque.displayString(locale: locale)
    }
}

/// Lets the user enter the month and year punched on the inspection sticker (ADR-5).
///
/// Looks like the Austrian sticker: months 1 to 12 around a circle, the year in the centre. The ring
/// is one adjustable accessibility element, the year stepper stays a separate control. At
/// accessibility Dynamic Type sizes the dial gives way to two standard pickers.
struct PlaquePicker: View {
    @Binding var plaque: YearMonth?
    /// Engine estimate to offer when nothing is entered yet.
    var suggestion: YearMonth?
    var today: DayDate = CalendarDay.today(in: CalendarDay.austria)

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @State private var draftYear: Int?

    private var shownYear: Int { plaque?.year ?? draftYear ?? suggestion?.year ?? today.year }
    private var yearRange: ClosedRange<Int> { (today.year - 30)...(today.year + 15) }

    var body: some View {
        VStack(spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                fallbackPickers
            } else {
                dial
            }
            if plaque == nil, let suggestion {
                suggestionRow(suggestion)
            }
        }
    }

    // MARK: Dial

    private var dial: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let buttonSize: CGFloat = 44
            let radius = side / 2 - buttonSize / 2 - 4
            ZStack {
                Circle()
                    .strokeBorder(.secondary, lineWidth: 2)
                    .accessibilityHidden(true)
                ring(radius: radius, buttonSize: buttonSize)
                yearControl
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 340)
    }

    private func ring(radius: CGFloat, buttonSize: CGFloat) -> some View {
        ZStack {
            ForEach(1...12, id: \.self) { month in
                let angle = Angle.degrees(Double(month - 1) * 30 - 90)
                monthButton(month, size: buttonSize)
                    .offset(x: radius * cos(angle.radians), y: radius * sin(angle.radians))
            }
        }
        // One adjustable element for VoiceOver instead of twelve buttons.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Inspection sticker", comment: "VoiceOver label of the inspection sticker picker"))
        .accessibilityValue(PlaqueAccessibility.value(for: plaque, locale: locale))
        .accessibilityHint(Text("Swipe up or down to change the month.", comment: "VoiceOver hint of the inspection sticker picker"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 1)
            case .decrement: step(by: -1)
            @unknown default: break
            }
        }
    }

    private func monthButton(_ month: Int, size: CGFloat) -> some View {
        let isSelected = plaque?.month == month && plaque?.year == shownYear
        return Button {
            select(month: month)
        } label: {
            Text(month, format: .number)
                .font(.body)
                .fontWeight(isSelected ? .heavy : .regular)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(width: size, height: size)
                .background {
                    if isSelected {
                        // Filled disc plus outer ring: selection is shape and weight, not only color.
                        Circle().fill(Color.accentColor)
                        Circle().strokeBorder(Color.primary, lineWidth: 3).padding(-4)
                    } else {
                        Circle().strokeBorder(.secondary, lineWidth: 1)
                    }
                }
        }
        // Borderless, not plain: inside a Form row only borderless buttons fire on their own.
        .buttonStyle(.borderless)
    }

    private var yearControl: some View {
        VStack(spacing: 6) {
            Text(shownYear, format: .number.grouping(.never))
                .font(.title)
                .fontWeight(.semibold)
                .monospacedDigit()
                .accessibilityIdentifier("plaqueYear")
            HStack(spacing: 16) {
                Button {
                    setYear(shownYear - 1)
                } label: {
                    Image(systemName: "minus.circle")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(shownYear <= yearRange.lowerBound)
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Previous year", comment: "VoiceOver label of the minus button of the sticker year"))
                .accessibilityIdentifier("plaquePreviousYear")
                Button {
                    setYear(shownYear + 1)
                } label: {
                    Image(systemName: "plus.circle")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .disabled(shownYear >= yearRange.upperBound)
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Next year", comment: "VoiceOver label of the plus button of the sticker year"))
                .accessibilityIdentifier("plaqueNextYear")
            }
            .font(.title2)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Large Dynamic Type fallback

    private var fallbackPickers: some View {
        VStack(alignment: .leading) {
            Picker(selection: monthSelection) {
                Text("Not set", comment: "Picker option for no inspection sticker month").tag(Int?.none)
                ForEach(1...12, id: \.self) { month in
                    Text(YearMonth.monthName(month, locale: locale)).tag(Int?.some(month))
                }
            } label: {
                Text("Month", comment: "Label of the month picker for the inspection sticker")
            }
            Picker(selection: yearSelection) {
                Text("Not set", comment: "Picker option for no inspection sticker year").tag(Int?.none)
                ForEach(Array(yearRange), id: \.self) { year in
                    Text(year, format: .number.grouping(.never)).tag(Int?.some(year))
                }
            } label: {
                Text("Year", comment: "Label of the year picker for the inspection sticker")
            }
        }
        .pickerStyle(.menu)
    }

    private var monthSelection: Binding<Int?> {
        Binding(
            get: { plaque?.month },
            set: { month in
                if let month { select(month: month) } else { plaque = nil }
            })
    }

    private var yearSelection: Binding<Int?> {
        Binding(
            get: { plaque?.year },
            set: { year in
                if let year { setYear(year) } else { plaque = nil }
            })
    }

    // MARK: Suggestion

    private func suggestionRow(_ suggestion: YearMonth) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                plaque = suggestion
            } label: {
                Label {
                    Text("Use suggestion: \(suggestion.displayString(locale: locale))", comment: "Button that fills the sticker picker with the estimated due month; the argument is the month")
                } icon: {
                    Image(systemName: "wand.and.stars")
                }
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("plaqueUseSuggestion")
            Text("Estimated from the first registration. Check it against your inspection sticker.", comment: "Caption below the suggestion button of the sticker picker")
                .font(.footnote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Changes

    private func select(month: Int) {
        plaque = YearMonth(year: shownYear, month: month)
    }

    private func setYear(_ year: Int) {
        let clamped = min(max(year, yearRange.lowerBound), yearRange.upperBound)
        if let current = plaque {
            plaque = YearMonth(year: clamped, month: current.month)
        } else {
            draftYear = clamped
        }
    }

    /// Month step with year rollover (December + 1 is January of the next year).
    private func step(by delta: Int) {
        guard let current = plaque else {
            plaque = suggestion ?? today.yearMonth
            return
        }
        let next = current.adding(months: delta)
        if yearRange.contains(next.year) { plaque = next }
    }
}

#Preview("Empty with suggestion") {
    @Previewable @State var plaque: YearMonth?
    Form {
        PlaquePicker(plaque: $plaque, suggestion: YearMonth(year: 2027, month: 3))
    }
}

#Preview("March 2027, accessibility size") {
    @Previewable @State var plaque: YearMonth? = YearMonth(year: 2027, month: 3)
    Form {
        PlaquePicker(plaque: $plaque)
    }
    .dynamicTypeSize(.accessibility3)
}
