import PitlogCore

/// Maps a `Vehicle` to the rule engine's input and calls the country module.
struct InspectionService: Sendable {
    enum UnavailableReason: Hashable, Sendable {
        case missingFirstRegistration
        /// Category not covered by the country module: the user enters the date manually.
        case unsupportedCategory
        case unsupportedCountry
        case invalidInput(String)
    }

    enum Outcome: Sendable {
        case available(InspectionStatus)
        case unavailable(UnavailableReason)

        var status: InspectionStatus? {
            if case .available(let status) = self { return status }
            return nil
        }

        var unavailableReason: UnavailableReason? {
            if case .unavailable(let reason) = self { return reason }
            return nil
        }
    }

    let registry: InspectionRuleRegistry

    init(registry: InspectionRuleRegistry = .standard) {
        self.registry = registry
    }

    /// `nil` if the first registration is missing.
    func input(for vehicle: Vehicle) -> InspectionInput? {
        guard let firstRegistration = vehicle.firstRegistration else { return nil }
        return InspectionInput(
            category: vehicle.category,
            firstRegistration: firstRegistration,
            plaque: vehicle.plaque,
            lastInspection: vehicle.lastInspection
        )
    }

    /// Estimated due month from the first registration alone, to prefill the plaque picker.
    /// `nil` if the country, category or first registration is not supported.
    func estimatedDueMonth(
        countryCode: String,
        category: VehicleCategory,
        firstRegistration: YearMonth?,
        today: DayDate
    ) -> YearMonth? {
        guard let firstRegistration,
              let ruleSet = registry.ruleSet(for: CountryCode(rawValue: countryCode)),
              ruleSet.supportedCategories.contains(category)
        else { return nil }
        let input = InspectionInput(category: category, firstRegistration: firstRegistration)
        guard let status = try? ruleSet.status(for: input, today: today),
              status.dueMonthSource == .estimatedFromFirstRegistration
        else { return nil }
        return status.dueMonth
    }

    func evaluate(_ vehicle: Vehicle, today: DayDate) -> Outcome {
        guard let ruleSet = registry.ruleSet(for: CountryCode(rawValue: vehicle.countryCode)) else {
            return .unavailable(.unsupportedCountry)
        }
        guard ruleSet.supportedCategories.contains(vehicle.category) else {
            return .unavailable(.unsupportedCategory)
        }
        guard let input = input(for: vehicle) else {
            return .unavailable(.missingFirstRegistration)
        }
        do {
            return .available(try ruleSet.status(for: input, today: today))
        } catch let error as InspectionRuleError {
            return .unavailable(Self.reason(for: error))
        } catch {
            return .unavailable(.invalidInput(String(describing: error)))
        }
    }

    /// Due month after an inspection on `inspection`, or `nil` with a reason.
    func nextDue(
        for vehicle: Vehicle,
        inspectedOn inspection: DayDate,
        today: DayDate
    ) -> Result<NextInspectionDue, UnavailableReason> {
        let outcome = evaluate(vehicle, today: today)
        guard case .available(let status) = outcome else {
            return .failure(outcome.unavailableReason ?? .missingFirstRegistration)
        }
        guard let ruleSet = registry.ruleSet(for: CountryCode(rawValue: vehicle.countryCode)),
              let input = input(for: vehicle)
        else { return .failure(.unsupportedCountry) }
        do {
            return .success(
                try ruleSet.nextDue(after: inspection, dueMonth: status.dueMonth, input: input))
        } catch let error as InspectionRuleError {
            return .failure(Self.reason(for: error))
        } catch {
            return .failure(.invalidInput(String(describing: error)))
        }
    }

    private static func reason(for error: InspectionRuleError) -> UnavailableReason {
        switch error {
        case .unsupportedCategory: .unsupportedCategory
        case .invalidInput(let message): .invalidInput(message)
        }
    }
}
