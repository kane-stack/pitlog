import Foundation
import ImageIO
import PitlogCore
import Vision

/// Core's receipt draft. The app has its own `ReceiptDraft` (an attachment in the entry editor), which would
/// shadow it, so the extraction code uses this name.
typealias ExtractedReceipt = PitlogCore.ReceiptDraft

/// Reads QR codes from a page image. Everything runs on the device.
protocol BarcodeReading: Sendable {
    func payloads(in page: ScanPage) async -> [String]
}

/// Vision barcode detection, QR only (the RKSV code of cash register receipts).
struct VisionBarcodeReader: BarcodeReading {
    func payloads(in page: ScanPage) async -> [String] {
        guard let source = CGImageSourceCreateWithData(page.data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return [] }
        var request = DetectBarcodesRequest()
        request.symbologies = [.qr]
        guard let observations = try? await request.perform(on: image) else { return [] }
        return observations.compactMap { $0.payloadString }
    }
}

/// The recognized content of a scanned receipt.
struct ReceiptScan: Sendable, Equatable {
    /// All pages in reading order, rows joined, each line with its 1-based page number.
    var lines: [RecognizedLine]
    /// Payloads of RKSV QR codes (`_R1-AT…`), for `ReceiptContext.rksvPayloads`.
    var rksvPayloads: [String]
    var pageCount: Int

    /// The text kept with the stored receipt (`ReceiptDocument.recognizedText`). The customer's name and address
    /// never leave the scan (privacy), and the QR payload is not text.
    var storedText: String {
        var pages: [[String]] = []
        for number in 1...max(pageCount, 1) {
            let texts = lines.filter { ($0.page ?? 1) == number }.map(\.text)
            pages.append(CustomerBlock.removing(from: texts))
        }
        return pages
            .map { $0.filter { !$0.contains("_R1-AT") }.joined(separator: "\n") }
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Scan pipeline for receipts: recognize the text of every page (the same `TextRecognizing` as the registration
/// scan), look for the RKSV QR code, join table rows. Extraction happens afterwards (`ReceiptExtractionService`).
struct ReceiptScanService: Sendable {
    var recognizer: any TextRecognizing = VisionTextRecognizer()
    var barcodes: any BarcodeReading = VisionBarcodeReader()

    func read(_ pages: [ScanPage]) async throws -> ReceiptScan {
        var lines: [RecognizedLine] = []
        var payloads: [String] = []
        for (offset, page) in pages.enumerated() {
            var recognized = try await recognizer.recognizeLines(in: page)
            for index in recognized.indices { recognized[index].page = offset + 1 }
            lines.append(contentsOf: LineJoiner.joinRows(recognized))
            for payload in await barcodes.payloads(in: page) where payload.hasPrefix("_R1-AT") {
                if !payloads.contains(payload) { payloads.append(payload) }
            }
        }
        return ReceiptScan(lines: lines, rksvPayloads: payloads, pageCount: pages.count)
    }
}
