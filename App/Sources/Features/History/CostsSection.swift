import Accessibility
import Charts
import PitlogCore
import SwiftUI

/// Workshop costs: the total of the current year with its categories, then a chart or, as an alternative
/// for people who cannot use the chart, a table of all years. Costs are always summed per currency and
/// never converted.
struct CostsSection: View {
    let entries: [MaintenanceEntry]
    /// Called when the user taps the Pro hint for the earlier years.
    var onUpgrade: () -> Void = {}

    enum Display: Hashable { case chart, table }

    @Environment(\.locale) private var locale
    @Environment(\.entitlements) private var entitlements
    @State private var display: Display = .chart
    @State private var chosenCurrency: String?

    private var thisYear: Int { CalendarDay.today(in: .current).year }

    /// Free: only the current year is summed and shown (ADR-11). The entries themselves stay in the history.
    private var summary: CostSummary {
        let costs = entries.compactMap(\.costEntry)
        if entitlements.canViewMultiYearCosts { return CostSummary(entries: costs) }
        return CostSummary(entries: costs.filter { $0.date.year == thisYear })
    }

    /// Costs of other years exist that the free plan does not show.
    private var hasHiddenYears: Bool {
        !entitlements.canViewMultiYearCosts && entries.compactMap(\.costEntry).contains { $0.date.year != thisYear }
    }

    private func currency(in summary: CostSummary) -> String? {
        let available = summary.currencies
        if let chosenCurrency, available.contains(chosenCurrency) { return chosenCurrency }
        let local = MoneyFormat.defaultCurrency(locale: locale)
        if available.contains(local) { return local }
        return available.first
    }

    var body: some View {
        let summary = summary
        let currency = currency(in: summary)
        Text("Workshop costs", comment: "History: header of the costs section")
            .font(.title3.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
            .listRowSeparator(.hidden)
        if let currency {
            if summary.currencies.count > 1 {
                MenuPickerRow(
                    title: Text("Currency", comment: "Entry editor and costs: the currency of an amount"),
                    valueText: Text(verbatim: MoneyFormat.name(of: currency, locale: locale)),
                    selection: Binding(get: { currency }, set: { chosenCurrency = $0 })
                ) {
                    ForEach(summary.currencies, id: \.self) { code in
                        Text(verbatim: MoneyFormat.name(of: code, locale: locale)).tag(code)
                    }
                }
                .accessibilityIdentifier("costsCurrency")
            }
            currentYear(summary: summary, currency: currency)
            if entitlements.canViewMultiYearCosts {
                multiYear(summary: summary, currency: currency)
            }
        } else if hasHiddenYears {
            Text("No costs this year yet.", comment: "Costs: empty state for the current year when only earlier years have costs")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("No costs yet. Add an amount to an entry to see your workshop costs per year.", comment: "Costs: empty state")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        if !entitlements.canViewMultiYearCosts {
            earlierYearsHint
        }
    }

    /// Free plan: where the chart would be, a note that earlier years need Pitlog Pro.
    @ViewBuilder
    private var earlierYearsHint: some View {
        ActionRow(
            title: Text("Costs of earlier years and chart", comment: "Costs: locked row for the costs of earlier years and the chart across the years"),
            systemImage: "chart.bar", showsProBadge: true, identifier: "costsEarlierYearsRow",
            accessibilityLabelText: hasHiddenYears
                ? Text("Costs of earlier years and chart, requires Pitlog Pro. Costs from earlier years are not shown.", comment: "VoiceOver label of the locked costs row when entries of earlier years exist")
                : Text("Costs of earlier years and chart, requires Pitlog Pro", comment: "VoiceOver label of the locked costs row"),
            action: onUpgrade)
    }

    @ViewBuilder
    private func multiYear(summary: CostSummary, currency: String) -> some View {
        Picker(selection: $display) {
            Text("Chart", comment: "Costs: show the costs as a chart").tag(Display.chart)
            Text("Table", comment: "Costs: show the costs as a table").tag(Display.table)
        } label: {
            Text("Show costs as", comment: "Costs: accessibility label of the switch between chart and table")
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("costsDisplayPicker")
        switch display {
        case .chart:
            CostsChartView(series: summary.series(currency: currency), currency: currency)
        case .table:
            CostsTable(summary: summary, currency: currency)
        }
    }

    // MARK: Current year

    @ViewBuilder
    private func currentYear(summary: CostSummary, currency: String) -> some View {
        let year = CalendarDay.today(in: .current).year
        let costs = summary.costs(year: year, currency: currency)
        AmountLayout {
            Text("Total \(String(year))", comment: "Costs: total of the current year. Argument: the year")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        } trailing: {
            Text(verbatim: MoneyFormat.string(costs.total, locale: locale))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("costsCurrentYearTotal")
        ForEach(costs.categories, id: \.category) { part in
            CategoryAmountRow(part: part)
        }
    }
}

/// Category with icon and name, and its amount.
struct CategoryAmountRow: View {
    let part: CategoryAmount
    @Environment(\.locale) private var locale

    var body: some View {
        AmountLayout {
            Label {
                Text(verbatim: part.category.title(locale: locale))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: part.category.iconName)
            }
            .font(.subheadline)
        } trailing: {
            Text(verbatim: MoneyFormat.string(part.money, locale: locale))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(part.category.title(locale: locale)), \(MoneyFormat.string(part.money, locale: locale))"))
    }
}

// MARK: Chart

/// Stacked bars per year with a legend. The categories are told apart by color, by the icon inside
/// larger segments, by the legend entries (icon and name) and by the table alternative.
struct CostsChartView: View {
    let series: [YearCosts]
    let currency: String

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var categories: [MaintenanceCategory] {
        MaintenanceCategory.allCases.filter { category in
            series.contains { $0.categories.contains { $0.category == category } }
        }
    }

    private var largestTotal: Double {
        max(series.map { $0.total.doubleAmount }.max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            chart
            legend
        }
        .listRowSeparator(.hidden)
    }

    private var chart: some View {
        Chart {
            ForEach(series, id: \.year) { year in
                if year.categories.isEmpty {
                    // A year without costs still gets its place on the axis.
                    BarMark(
                        x: .value(String(localized: "Year", locale: locale, comment: "Chart axis: the calendar year"), String(year.year)),
                        y: .value(String(localized: "Costs", locale: locale, comment: "Chart axis: the amount of money"), 0))
                        .foregroundStyle(.clear)
                } else {
                    ForEach(year.categories, id: \.category) { part in
                        BarMark(
                            x: .value(String(localized: "Year", locale: locale, comment: "Chart axis: the calendar year"), String(year.year)),
                            y: .value(String(localized: "Costs", locale: locale, comment: "Chart axis: the amount of money"), part.money.doubleAmount))
                            .foregroundStyle(by: .value(
                                String(localized: "Category", locale: locale, comment: "History: category filter and entry editor field"),
                                part.category.title(locale: locale)))
                            .annotation(position: .overlay) {
                                if part.money.doubleAmount >= largestTotal * 0.12 {
                                    Image(systemName: part.category.iconName)
                                        .font(.caption2)
                                        .foregroundStyle(.primary)
                                        .padding(3)
                                        .background(.regularMaterial, in: Circle())
                                }
                            }
                    }
                }
            }
        }
        .chartForegroundStyleScale(
            domain: categories.map { $0.title(locale: locale) },
            range: categories.map(\.color))
        .chartLegend(.hidden)
        .chartXScale(domain: series.map { String($0.year) })
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(verbatim: MoneyFormat.wholeUnits(amount, currency: currency, locale: locale))
                    }
                }
            }
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 320 : 220)
        .accessibilityChartDescriptor(CostsChartDescriptor(series: series, currency: currency, locale: locale))
        .accessibilityIdentifier("costsChart")
    }

    /// Icon, color and name of every category in the chart.
    private var legend: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 240 : 130), alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(categories, id: \.self) { category in
                HStack(spacing: 6) {
                    Image(systemName: category.iconName)
                        .foregroundStyle(category.color)
                        .accessibilityHidden(true)
                    Text(verbatim: category.title(locale: locale))
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Legend", comment: "Costs chart: accessibility label of the legend"))
        .accessibilityValue(Text(verbatim: categories.map { $0.title(locale: locale) }.formatted(.list(type: .and).locale(locale))))
        .accessibilityIdentifier("costsLegend")
    }
}

extension Money {
    /// For plotting only. Amounts are stored and summed as integers.
    var doubleAmount: Double { Double(truncating: amount as NSDecimalNumber) }
}

/// Audio Graph: one series per category and one for the total, over the years.
struct CostsChartDescriptor: AXChartDescriptorRepresentable {
    let series: [YearCosts]
    let currency: String
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let years = series.map { String($0.year) }
        let largest = max(series.map { $0.total.doubleAmount }.max() ?? 0, 1)
        let currency = currency
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: String(localized: "Year", locale: locale, comment: "Chart axis: the calendar year"),
            categoryOrder: years)
        let yAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Costs", locale: locale, comment: "Chart axis: the amount of money"),
            range: 0...largest,
            gridlinePositions: []
        ) { value in
            value.formatted(.currency(code: currency).locale(locale))
        }
        var descriptors = [
            AXDataSeriesDescriptor(
                name: String(localized: "Total", locale: locale, comment: "Costs chart: the total of all categories"),
                isContinuous: false,
                dataPoints: series.map { AXDataPoint(x: String($0.year), y: $0.total.doubleAmount) })
        ]
        for category in MaintenanceCategory.allCases
        where series.contains(where: { $0.categories.contains { $0.category == category } }) {
            descriptors.append(AXDataSeriesDescriptor(
                name: category.title(locale: locale),
                isContinuous: false,
                dataPoints: series.map { year in
                    let amount = year.categories.first { $0.category == category }?.money.doubleAmount ?? 0
                    return AXDataPoint(x: String(year.year), y: amount)
                }))
        }
        return AXChartDescriptor(
            title: String(localized: "Workshop costs per year", locale: locale, comment: "Costs chart: title for the audio graph"),
            summary: String(localized: "Workshop costs in \(MoneyFormat.name(of: currency, locale: locale)), stacked by category", locale: locale, comment: "Costs chart: summary for the audio graph. Argument: the currency"),
            xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: descriptors)
    }
}

// MARK: Table

/// The costs of all years as text: the alternative to the chart.
struct CostsTable: View {
    let summary: CostSummary
    let currency: String

    @Environment(\.locale) private var locale

    var body: some View {
        let years = summary.series(currency: currency).reversed()
        ForEach(Array(years), id: \.year) { year in
            AmountLayout {
                Text(verbatim: String(year.year))
                    .font(.headline)
            } trailing: {
                Text(verbatim: MoneyFormat.string(year.total, locale: locale))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("costsTableYear")
            .listRowSeparator(.hidden)
            if year.categories.isEmpty {
                Text("No costs", comment: "Costs table: a year without any costs")
                    .font(.subheadline)
            }
            ForEach(year.categories, id: \.category) { part in
                CategoryAmountRow(part: part)
            }
        }
    }
}
