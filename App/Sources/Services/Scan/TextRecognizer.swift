import Foundation
import ImageIO
import PitlogCore
import Vision

/// Turns a page image into text lines with their positions. Everything runs on the device.
protocol TextRecognizing: Sendable {
    func recognizeLines(in page: ScanPage) async throws -> [RecognizedLine]
}

enum TextRecognitionError: Error {
    case unreadableImage
}

/// Vision text recognition in accurate mode, German first, then English.
///
/// `RecognizeDocumentsRequest` would add table structure, but the parser does not need it: it joins the cells of a
/// table row from the line boxes itself (`RowBuilder` in PitlogCore), and the plain text request is the one whose
/// behaviour on certificates is easy to reason about. Language correction is off: it "corrects" VINs and codes.
struct VisionTextRecognizer: TextRecognizing {
    func recognizeLines(in page: ScanPage) async throws -> [RecognizedLine] {
        guard let source = CGImageSourceCreateWithData(page.data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw TextRecognitionError.unreadableImage }

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let supported = request.supportedRecognitionLanguages
        let german = supported.filter { $0.languageCode?.identifier == "de" }
        let english = supported.filter { $0.languageCode?.identifier == "en" }
        if !german.isEmpty || !english.isEmpty {
            request.recognitionLanguages = german + english
        }

        let observations = try await request.perform(on: image)
        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox.cgRect
            // Vision's origin is bottom left, the parser's is top left.
            return RecognizedLine(
                text: candidate.string,
                box: Rect(x: box.minX, y: 1 - box.maxY, w: box.width, h: box.height))
        }
    }
}
