import Foundation
import SwiftData

/// A receipt (photo or PDF) attached to a history entry. Placeholder for M5: the scan pipeline fills
/// `recognizedText` and `pageCount` later; until then it only holds the file.
///
/// SchemaV1 may still change freely until the first TestFlight build (see `SchemaV1`).
@Model
final class ReceiptDocument {
    static let jpegType = "image/jpeg"
    static let pdfType = "application/pdf"

    var id: UUID = UUID()
    @Attribute(.externalStorage) var data: Data?
    /// `image/jpeg` or `application/pdf`.
    var contentType: String = ReceiptDocument.jpegType
    var pageCount: Int = 1
    /// OCR result (M5). Empty until then.
    var recognizedText: String = ""
    var createdAt: Date = Date()

    var entry: MaintenanceEntry?

    init(
        data: Data? = nil,
        contentType: String = ReceiptDocument.jpegType,
        pageCount: Int = 1,
        entry: MaintenanceEntry? = nil
    ) {
        self.data = data
        self.contentType = contentType
        self.pageCount = pageCount
        self.entry = entry
    }
}

extension ReceiptDocument {
    var isPDF: Bool { contentType == Self.pdfType }

    /// File extension for the temporary file QuickLook needs.
    var fileExtension: String { isPDF ? "pdf" : "jpg" }
}
