import Foundation
import PDFKit
import UIKit

/// A scanned or imported page as encoded image data. It exists in memory only: the scan flow never writes it
/// anywhere and drops it after recognition.
struct ScanPage: Sendable {
    let data: Data
}

enum ScanPageImport {
    /// Long edge of the pages handed to text recognition. Large enough for the small print of a certificate.
    static let maximumPixel = 3000
    /// A certificate has at most a few pages (two sides of a card, a folded sheet).
    static let maximumPages = 4
    static let quality = 0.95

    /// Pages from the bytes of an image or a PDF. Empty if the data is neither.
    static func pages(from data: Data) -> [ScanPage] {
        if data.prefix(5) == Data("%PDF-".utf8) { return pdfPages(from: data) }
        guard let jpeg = PhotoDownscaler.jpegData(from: data, maxPixel: maximumPixel, quality: quality) else {
            return []
        }
        return [ScanPage(data: jpeg)]
    }

    /// Pages from the images of the document camera.
    static func pages(from images: [UIImage]) -> [ScanPage] {
        images.prefix(maximumPages).compactMap { image in
            guard let jpeg = image.jpegData(compressionQuality: quality) else { return nil }
            return PhotoDownscaler.jpegData(from: jpeg, maxPixel: maximumPixel, quality: quality).map(ScanPage.init)
        }
    }

    private static func pdfPages(from data: Data) -> [ScanPage] {
        guard let document = PDFDocument(data: data) else { return [] }
        var pages: [ScanPage] = []
        for index in 0..<min(document.pageCount, maximumPages) {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width > 0, bounds.height > 0 else { continue }
            let scale = CGFloat(maximumPixel) / max(bounds.width, bounds.height)
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let image = page.thumbnail(of: size, for: .mediaBox)
            if let jpeg = image.jpegData(compressionQuality: quality) { pages.append(ScanPage(data: jpeg)) }
        }
        return pages
    }
}
