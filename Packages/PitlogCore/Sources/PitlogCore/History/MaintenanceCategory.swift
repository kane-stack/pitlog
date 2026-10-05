/// What a history entry is about. Workshop costs only: no vignette, insurance or fuel.
public enum MaintenanceCategory: String, Hashable, Codable, Sendable, CaseIterable {
    case service
    case repair
    /// Tyre change or purchase at a workshop.
    case tyres
    /// The § 57a inspection fee, paid at the workshop or inspection station.
    case inspection
    case otherWorkshop
}
