import Foundation
import PitlogCore

/// Both extractors' drafts, the merge and how long each took (for the debug comparison).
struct ReceiptExtraction: Sendable {
    var heuristic: ExtractedReceipt
    /// `nil`: the model is not available or produced nothing.
    var model: ExtractedReceipt?
    var modelAvailable: Bool
    var rksv: RKSVReceipt?
    var merge: ReceiptMerge
    var heuristicDuration: Duration
    var modelDuration: Duration?
}

/// ADR-10: the heuristic always runs; if the language model is available it runs too and the results are merged.
struct ReceiptExtractionService: Sendable {
    var heuristic = HeuristicReceiptExtractor()
    /// `nil` where Foundation Models does not exist or is not available.
    var model: (any ReceiptModelExtracting)?

    init(model: (any ReceiptModelExtracting)? = ReceiptModelProvider.systemModel()) {
        self.model = model
    }

    func extract(lines: [RecognizedLine], context: ReceiptContext) async -> ReceiptExtraction {
        let clock = ContinuousClock()
        var heuristicDraft = ExtractedReceipt()
        let heuristicDuration = clock.measure {
            heuristicDraft = heuristic.draft(lines: lines, context: context)
        }
        var modelDraft: ExtractedReceipt?
        var modelDuration: Duration?
        let available = model?.isAvailable ?? false
        if let model, available {
            let start = clock.now
            modelDraft = await model.extractDraft(lines: lines, context: context)
            modelDuration = clock.now - start
        }
        let rksv = HeuristicReceiptExtractor.findRKSV(lines: lines, context: context)
        return ReceiptExtraction(
            heuristic: heuristicDraft, model: modelDraft, modelAvailable: available, rksv: rksv,
            merge: ReceiptMerger.merge(heuristic: heuristicDraft, model: modelDraft, rksv: rksv),
            heuristicDuration: heuristicDuration, modelDuration: modelDuration)
    }

    /// What the receipt parser may use to check plausibility: today, the primary vehicle's registration and
    /// odometer, and the plates and VINs of all vehicles.
    static func context(
        today: DayDate, vehicles: [ReceiptVehicleInfo], primary: UUID?, rksvPayloads: [String]
    ) -> ReceiptContext {
        let primaryVehicle = vehicles.first { $0.id == primary }
        return ReceiptContext(
            today: today,
            firstRegistration: primaryVehicle?.firstRegistration,
            lastKnownOdometerKm: primaryVehicle?.lastKnownOdometerKm,
            knownPlates: vehicles.map(\.plate).filter { !$0.isEmpty },
            knownVINs: vehicles.compactMap(\.vin).filter { !$0.isEmpty },
            rksvPayloads: rksvPayloads)
    }
}
