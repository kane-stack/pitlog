/// ISO 3166-1 alpha-2 country code that selects an `InspectionRuleSet`.
public struct CountryCode: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let austria = CountryCode(rawValue: "AT")
}
