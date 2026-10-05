import Foundation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// A receipt in the entry editor, before "Save". It either wraps a stored `ReceiptDocument` or is new.
struct EditorReceiptDraft: Identifiable {
    let id = UUID()
    let data: Data
    let contentType: String
    let pageCount: Int
    /// The stored receipt this draft stands for, `nil` for a new one.
    let existing: ReceiptDocument?
    /// OCR text of a scanned receipt (without the customer block); empty for a plain attachment.
    var recognizedText: String = ""

    var isPDF: Bool { contentType == ReceiptDocument.pdfType }

    /// A temporary file with the right extension, as QuickLook needs one.
    func previewFile() -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("receipt-\(id.uuidString)")
            .appendingPathExtension(isPDF ? "pdf" : "jpg")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

enum ReceiptImport {
    /// Receipts larger than this are refused, so the entry stays quick to sync.
    static let maximumBytes = 20 * 1024 * 1024
    /// Long edge of stored photos. Legible receipts, small files.
    static let maximumPixel = 2400

    /// A draft from file or photo data: PDFs are kept as they are, images become JPEG. `nil` if the data is
    /// neither or too large.
    static func draft(from data: Data) -> EditorReceiptDraft? {
        guard data.count <= maximumBytes else { return nil }
        if data.prefix(5) == Data("%PDF-".utf8) {
            guard let document = PDFDocument(data: data), document.pageCount > 0 else { return nil }
            return EditorReceiptDraft(
                data: data, contentType: ReceiptDocument.pdfType, pageCount: document.pageCount, existing: nil)
        }
        guard let jpeg = PhotoDownscaler.jpegData(from: data, maxPixel: maximumPixel) else { return nil }
        return EditorReceiptDraft(data: jpeg, contentType: ReceiptDocument.jpegType, pageCount: 1, existing: nil)
    }
}
