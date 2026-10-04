/// Vehicle classes the rule sets distinguish. Country modules map them to their own classes.
public enum VehicleCategory: String, Hashable, Codable, Sendable, CaseIterable {
    /// Passenger car (M1), without taxi, ambulance and patient transport.
    case passengerCar
    /// Class L, including moped and quad.
    case motorcycle
    /// Trailer up to 3.5 t (O1/O2).
    case lightTrailer
    /// Light commercial vehicle (N1).
    case lightCommercial
    case taxiOrAmbulance
    case historic
    /// Heavy vehicles, tractors and everything else. Not supported by the rule sets yet.
    case other
}
