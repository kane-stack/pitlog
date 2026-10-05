/// How sure the parser is about a field. Anything below `.high` needs a look from the user.
public enum ScanConfidence: Int, Comparable, Hashable, Sendable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2

    public static func < (lhs: ScanConfidence, rhs: ScanConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A value read from the document, with the text it came from.
public struct ScannedField<Value: Hashable & Sendable>: Hashable, Sendable {
    public var value: Value
    /// The text of this field only. Never a whole line, so nothing of neighbouring fields can leak into it.
    public var rawText: String
    public var confidence: ScanConfidence

    public init(value: Value, rawText: String, confidence: ScanConfidence) {
        self.value = value
        self.rawText = rawText
        self.confidence = confidence
    }
}

/// Things the user should be told about the scanned document.
public enum RegistrationScanNotice: String, Hashable, Sendable, CaseIterable {
    /// The scan shows registration certificate part II (A21/A22), which is not carried in the car.
    case partTwo
    /// The scan shows a transfer permit ("Transport Permit"), not a registration certificate.
    case transferPermit
    /// Front of a chip card without the back, which carries VIN, class, make and weight.
    case cardBackSideMissing
    /// Back of a chip card without the front, which carries the plate and the first registration.
    case cardFrontSideMissing
}

/// The result of reading a registration certificate (Zulassungsschein). Holder name, address and date of birth
/// are never read (C.1.x, A.3), so they cannot appear here.
public struct RegistrationDraft: Hashable, Sendable {
    /// A: license plate.
    public var plate: ScannedField<String>?
    /// B: date of the first registration (not I, the current registration).
    public var firstRegistration: ScannedField<DayDate>?
    /// E: vehicle identification number.
    public var vin: ScannedField<String>?
    /// J: vehicle class as printed, e.g. `M1` or `L3e-A1`.
    public var vehicleClass: ScannedField<String>?
    /// J (and A.4) mapped to the app's categories.
    public var category: ScannedField<VehicleCategory>?
    /// D.1: make.
    public var make: ScannedField<String>?
    /// D.2: type / variant / version.
    public var type: ScannedField<String>?
    /// D.3: commercial name.
    public var commercialName: ScannedField<String>?
    /// F.2: maximum permissible mass in kilograms.
    public var maxMassKg: ScannedField<Int>?
    /// A.4: intended use as a code (`01`, `25` taxi, `62`/`64` ambulance).
    public var usageCode: ScannedField<String>?
    public var notices: Set<RegistrationScanNotice>

    public init(
        plate: ScannedField<String>? = nil,
        firstRegistration: ScannedField<DayDate>? = nil,
        vin: ScannedField<String>? = nil,
        vehicleClass: ScannedField<String>? = nil,
        category: ScannedField<VehicleCategory>? = nil,
        make: ScannedField<String>? = nil,
        type: ScannedField<String>? = nil,
        commercialName: ScannedField<String>? = nil,
        maxMassKg: ScannedField<Int>? = nil,
        usageCode: ScannedField<String>? = nil,
        notices: Set<RegistrationScanNotice> = []
    ) {
        self.plate = plate
        self.firstRegistration = firstRegistration
        self.vin = vin
        self.vehicleClass = vehicleClass
        self.category = category
        self.make = make
        self.type = type
        self.commercialName = commercialName
        self.maxMassKg = maxMassKg
        self.usageCode = usageCode
        self.notices = notices
    }

    /// No field was read.
    public var isEmpty: Bool {
        plate == nil && firstRegistration == nil && vin == nil && vehicleClass == nil && category == nil
            && make == nil && type == nil && commercialName == nil && maxMassKg == nil && usageCode == nil
    }

    /// Combines two scans of the same document (e.g. front and back of a chip card). A field only one side has is
    /// taken over; the same value twice keeps the higher confidence; two different values cancel out unless
    /// exactly one of them is at least `.medium`.
    public func merging(_ other: RegistrationDraft) -> RegistrationDraft {
        RegistrationDraft(
            plate: Self.merge(plate, other.plate),
            firstRegistration: Self.merge(firstRegistration, other.firstRegistration),
            vin: Self.merge(vin, other.vin),
            vehicleClass: Self.merge(vehicleClass, other.vehicleClass),
            category: Self.merge(category, other.category),
            make: Self.merge(make, other.make),
            type: Self.merge(type, other.type),
            commercialName: Self.merge(commercialName, other.commercialName),
            maxMassKg: Self.merge(maxMassKg, other.maxMassKg),
            usageCode: Self.merge(usageCode, other.usageCode),
            notices: notices.union(other.notices))
    }

    private static func merge<Value: Hashable & Sendable>(
        _ lhs: ScannedField<Value>?, _ rhs: ScannedField<Value>?
    ) -> ScannedField<Value>? {
        guard let lhs else { return rhs }
        guard let rhs else { return lhs }
        if lhs.value == rhs.value { return lhs.confidence >= rhs.confidence ? lhs : rhs }
        if lhs.confidence >= .medium, rhs.confidence == .low { return lhs }
        if rhs.confidence >= .medium, lhs.confidence == .low { return rhs }
        return nil
    }
}
