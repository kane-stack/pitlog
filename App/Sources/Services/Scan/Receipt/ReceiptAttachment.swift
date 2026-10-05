import Foundation
import PDFKit
import UIKit

/// A scanned receipt as it is stored: JPEG for one page, PDF for several (or for an imported PDF), plus the
/// recognized text without the customer block.
struct ReceiptAttachment: Sendable, Equatable {
    let data: Data
    let contentType: String
    let pageCount: Int
    let recognizedText: String
}

enum ReceiptAttachmentBuilder {
    /// `nil` if nothing storable comes out (no readable page, or larger than `ReceiptImport.maximumBytes`).
    static func make(pages: [ScanPage], originalPDF: Data?, recognizedText: String) -> ReceiptAttachment? {
        if let originalPDF, originalPDF.count <= ReceiptImport.maximumBytes,
           let document = PDFDocument(data: originalPDF), document.pageCount > 0
        {
            return ReceiptAttachment(
                data: originalPDF, contentType: ReceiptDocument.pdfType, pageCount: document.pageCount,
                recognizedText: recognizedText)
        }
        // Smaller than the scan pages: they were made for recognition, not for keeping.
        let jpegs = pages.compactMap {
            PhotoDownscaler.jpegData(from: $0.data, maxPixel: ReceiptImport.maximumPixel, quality: 0.8)
        }
        guard let first = jpegs.first else { return nil }
        if jpegs.count == 1 {
            guard first.count <= ReceiptImport.maximumBytes else { return nil }
            return ReceiptAttachment(
                data: first, contentType: ReceiptDocument.jpegType, pageCount: 1, recognizedText: recognizedText)
        }
        let document = PDFDocument()
        for jpeg in jpegs {
            guard let image = UIImage(data: jpeg), let page = PDFPage(image: image) else { continue }
            document.insert(page, at: document.pageCount)
        }
        guard document.pageCount > 0, let data = document.dataRepresentation(),
              data.count <= ReceiptImport.maximumBytes
        else { return nil }
        return ReceiptAttachment(
            data: data, contentType: ReceiptDocument.pdfType, pageCount: document.pageCount,
            recognizedText: recognizedText)
    }
}
