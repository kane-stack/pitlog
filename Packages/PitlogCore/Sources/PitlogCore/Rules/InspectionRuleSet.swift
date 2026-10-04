/// A country module (ADR-6). Implementations are pure: `today` is injected.
public protocol InspectionRuleSet: Sendable {
    var country: CountryCode { get }
    var ruleVersion: String { get }
    var supportedCategories: Set<VehicleCategory> { get }

    func status(for input: InspectionInput, today: DayDate) throws(InspectionRuleError) -> InspectionStatus

    /// Due month after an inspection on `inspection` for a vehicle whose current due month is `dueMonth`.
    func nextDue(
        after inspection: DayDate,
        dueMonth: YearMonth,
        input: InspectionInput
    ) throws(InspectionRuleError) -> NextInspectionDue
}

/// Maps a country to its rule set.
public struct InspectionRuleRegistry: Sendable {
    private let ruleSets: [CountryCode: any InspectionRuleSet]

    public init(ruleSets: [any InspectionRuleSet]) {
        var map: [CountryCode: any InspectionRuleSet] = [:]
        for ruleSet in ruleSets {
            map[ruleSet.country] = ruleSet
        }
        self.ruleSets = map
    }

    public static let standard = InspectionRuleRegistry(ruleSets: [AustriaInspectionRules()])

    public func ruleSet(for country: CountryCode) -> (any InspectionRuleSet)? {
        ruleSets[country]
    }

    public var countries: [CountryCode] {
        ruleSets.keys.sorted { $0.rawValue < $1.rawValue }
    }
}
