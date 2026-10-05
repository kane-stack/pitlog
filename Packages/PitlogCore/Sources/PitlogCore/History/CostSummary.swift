/// One history entry with a cost, as the summary sees it.
public struct CostEntry: Hashable, Sendable {
    public var date: DayDate
    public var category: MaintenanceCategory
    public var money: Money

    public init(date: DayDate, category: MaintenanceCategory, money: Money) {
        self.date = date
        self.category = category
        self.money = money
    }
}

/// The part of a total that belongs to one category.
public struct CategoryAmount: Hashable, Sendable {
    public var category: MaintenanceCategory
    public var money: Money

    public init(category: MaintenanceCategory, money: Money) {
        self.category = category
        self.money = money
    }
}

/// The costs of one calendar year in one currency. `categories` lists the categories with entries, in
/// the order of `MaintenanceCategory.allCases`.
public struct YearCosts: Hashable, Sendable {
    public var year: Int
    public var total: Money
    public var categories: [CategoryAmount]

    public init(year: Int, total: Money, categories: [CategoryAmount]) {
        self.year = year
        self.total = total
        self.categories = categories
    }
}

/// Workshop costs per calendar year and category. Each currency is summed on its own and never converted.
public struct CostSummary: Hashable, Sendable {
    private struct Key: Hashable {
        var currency: String
        var year: Int
    }

    /// currency, year -> category -> minor units. A year exists as soon as it has an entry, even a free one.
    private var cells: [Key: [MaintenanceCategory: Int64]] = [:]

    public init(entries: [CostEntry]) {
        for entry in entries {
            let key = Key(currency: entry.money.currencyCode, year: entry.date.year)
            let previous = cells[key, default: [:]][entry.category] ?? 0
            cells[key, default: [:]][entry.category] = Money.saturatingAdd(previous, entry.money.amountMinor)
        }
    }

    public var isEmpty: Bool { cells.isEmpty }

    /// Currency codes that occur, sorted alphabetically.
    public var currencies: [String] {
        Set(cells.keys.map(\.currency)).sorted()
    }

    /// First and last year with an entry in `currency`.
    public func yearRange(currency: String) -> ClosedRange<Int>? {
        let years = cells.keys.filter { $0.currency == currency }.map(\.year)
        guard let first = years.min(), let last = years.max() else { return nil }
        return first...last
    }

    public func costs(year: Int, currency: String) -> YearCosts {
        let code = Money.normalized(currency)
        let byCategory = cells[Key(currency: code, year: year)] ?? [:]
        var total: Int64 = 0
        var categories: [CategoryAmount] = []
        for category in MaintenanceCategory.allCases {
            guard let amount = byCategory[category] else { continue }
            total = Money.saturatingAdd(total, amount)
            categories.append(CategoryAmount(category: category, money: Money(amountMinor: amount, currencyCode: code)))
        }
        return YearCosts(year: year, total: Money(amountMinor: total, currencyCode: code), categories: categories)
    }

    /// Years ascending from the first to the last entry, with zero years in between (for a chart).
    public func series(currency: String) -> [YearCosts] {
        guard let range = yearRange(currency: Money.normalized(currency)) else { return [] }
        return range.map { costs(year: $0, currency: currency) }
    }

    /// Totals per category over all years, only categories with entries.
    public func categoryTotals(currency: String) -> [CategoryAmount] {
        let code = Money.normalized(currency)
        var sums: [MaintenanceCategory: Int64] = [:]
        for (key, byCategory) in cells where key.currency == code {
            for (category, amount) in byCategory {
                sums[category] = Money.saturatingAdd(sums[category] ?? 0, amount)
            }
        }
        return MaintenanceCategory.allCases.compactMap { category in
            sums[category].map { CategoryAmount(category: category, money: Money(amountMinor: $0, currencyCode: code)) }
        }
    }

    /// Total over all years.
    public func total(currency: String) -> Money {
        let code = Money.normalized(currency)
        let sum = categoryTotals(currency: code).reduce(Int64(0)) { Money.saturatingAdd($0, $1.money.amountMinor) }
        return Money(amountMinor: sum, currencyCode: code)
    }
}
