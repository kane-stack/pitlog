import Foundation
import PitlogCore

/// Scan pipeline for registration certificates: recognize the text of every page, then parse it
/// (ADR-13). The pages are not kept; the draft holds only the values and their snippets.
struct RegistrationScanService: Sendable {
    var recognizer: any TextRecognizing = VisionTextRecognizer()

    /// The draft plus the recognized lines it was parsed from (the lines are only for the debug diagnosis).
    func read(_ pages: [ScanPage], today: DayDate) async throws -> (draft: RegistrationDraft, lines: [[RecognizedLine]]) {
        var recognized: [[RecognizedLine]] = []
        for page in pages {
            recognized.append(try await recognizer.recognizeLines(in: page))
        }
        return (RegistrationDocumentParser().parse(pages: recognized, today: today), recognized)
    }

    /// The draft for already recognized lines. Used by the UI tests, where the simulator has no camera.
    static func draft(from pages: [[RecognizedLine]], today: DayDate) -> RegistrationDraft {
        RegistrationDocumentParser().parse(pages: pages, today: today)
    }
}
