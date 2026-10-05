import PDFKit
import PitlogCore
import UIKit

/// A receipt file of an entry, as the renderer gets it (the app reads it from the `ReceiptDocument`).
struct ServiceRecordReceiptFile: Sendable {
    let data: Data
    let isPDF: Bool
}

/// Lays a `ServiceRecord` out as a multi-page A4 PDF with `UIGraphicsPDFRenderer`: heading, vehicle data, the
/// history as a table whose header repeats on every page, optional costs, optional receipt pages and a footer
/// with "Page x of y" on every page.
///
/// It works with fixed sizes and colors: the result is a printed document, not a screen. Rows are never split
/// across pages. The page count is not known up front, so the document is laid out twice: the first pass only
/// counts the pages, the second one draws the footers with the total.
///
/// The PDF is not tagged (no structure tree for screen readers); see `docs/service-record.md`.
struct ServiceRecordPDFRenderer: Sendable {
    let record: ServiceRecord
    let texts: ServiceRecordTexts
    /// Receipt files by entry ID (`ServiceRecordEntry.id`), in the order they are appended.
    let receipts: [String: [ServiceRecordReceiptFile]]

    struct Output: Sendable {
        let data: Data
        let pageCount: Int
    }

    func render() -> Output {
        let counting = renderPass(totalPages: 0, drawsAttachments: false)
        return renderPass(totalPages: counting.pageCount, drawsAttachments: true)
    }

    // MARK: Geometry

    /// A4 in points (595.28 × 841.89), rounded.
    static let pageSize = CGSize(width: 595, height: 842)
    static let marginLeft: CGFloat = 48
    static let marginRight: CGFloat = 48
    static let marginTop: CGFloat = 54
    /// The body ends here, the footer sits below.
    static let bodyBottom: CGFloat = 780
    static let contentWidth: CGFloat = pageSize.width - marginLeft - marginRight

    // MARK: Passes

    private func renderPass(totalPages: Int, drawsAttachments: Bool) -> Output {
        let format = UIGraphicsPDFRendererFormat()
        // Title and creator only. No author: the document must not carry the owner's name.
        format.documentInfo = [
            kCGPDFContextTitle as String: texts.title,
            kCGPDFContextCreator as String: "Pitlog",
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: Self.pageSize), format: format)
        var pageCount = 0
        let data = renderer.pdfData { context in
            let page = PageWriter(context: context, texts: texts, totalPages: totalPages)
            page.begin()
            drawDocument(on: page, drawsAttachments: drawsAttachments)
            pageCount = page.pageNumber
        }
        return Output(data: data, pageCount: pageCount)
    }

    private func drawDocument(on page: PageWriter, drawsAttachments: Bool) {
        drawTitle(on: page)
        drawVehicle(on: page)
        drawHistory(on: page)
        if !record.costs.isEmpty { drawCosts(on: page) }
        for item in record.attachmentItems {
            drawAttachments(of: item, on: page, drawsImages: drawsAttachments)
        }
    }

    // MARK: Title and vehicle

    private func drawTitle(on page: PageWriter) {
        page.draw(Style.text(texts.title, size: 22, weight: .bold))
        page.advance(2)
        page.draw(Style.text(texts.createdLine(record.createdOn), size: 10.5, color: Style.muted))
        page.advance(8)
        page.rule()
        page.advance(14)
    }

    private func drawVehicle(on page: PageWriter) {
        page.draw(Style.text(texts.vehicleHeading, size: 13, weight: .semibold))
        page.advance(6)
        let labelWidth: CGFloat = 140
        let gap: CGFloat = 10
        let valueWidth = Self.contentWidth - labelWidth - gap
        for row in texts.vehicleRows(record) {
            let label = Style.text(row.label, size: 10, weight: .semibold, color: Style.muted)
            let value = NSMutableAttributedString(attributedString: Style.text(row.value, size: 10.5))
            if let note = row.note {
                value.append(Style.text("\n" + note, size: 8.5, color: Style.muted))
            }
            let height = max(page.height(of: label, width: labelWidth), page.height(of: value, width: valueWidth)) + 5
            page.ensureSpace(height)
            page.draw(label, x: Self.marginLeft, width: labelWidth, advance: false)
            page.draw(value, x: Self.marginLeft + labelWidth + gap, width: valueWidth, advance: false)
            page.advance(height)
        }
        page.advance(14)
    }

    // MARK: History table

    private struct Column {
        let title: String
        let width: CGFloat
        let alignment: NSTextAlignment
    }

    private var columns: [Column] {
        let gutter = Self.gutter
        let number: CGFloat = 24
        let date: CGFloat = 56
        let kilometers: CGFloat = 56
        let category: CGFloat = 62
        let amount: CGFloat = 66
        let receipt: CGFloat = 44
        var fixed = number + date + kilometers + category + receipt
        var count = 6
        if record.options.includeAmounts {
            fixed += amount
            count += 1
        }
        let work = Self.contentWidth - fixed - gutter * CGFloat(count - 1)
        var result = [
            Column(title: texts.numberHeader, width: number, alignment: .left),
            Column(title: texts.dateHeader, width: date, alignment: .left),
            Column(title: texts.kilometersHeader, width: kilometers, alignment: .right),
            Column(title: texts.categoryHeader, width: category, alignment: .left),
            Column(title: texts.workHeader, width: work, alignment: .left),
        ]
        if record.options.includeAmounts {
            result.append(Column(title: texts.amountHeader, width: amount, alignment: .right))
        }
        result.append(Column(title: texts.receiptHeader, width: receipt, alignment: .left))
        return result
    }

    private static let gutter: CGFloat = 5
    private static let rowPadding: CGFloat = 3.5

    private func cellTexts(_ cells: ServiceRecordTexts.EntryCells) -> [NSAttributedString] {
        let size: CGFloat = 8.5
        let work = NSMutableAttributedString()
        if !cells.workshop.isEmpty {
            work.append(Style.text(cells.workshop, size: size, weight: .semibold))
        }
        if !cells.work.isEmpty {
            if work.length > 0 { work.append(Style.text("\n", size: size)) }
            work.append(Style.text(cells.work, size: size))
        }
        var result = [
            Style.text(cells.number, size: size),
            Style.text(cells.date, size: size),
            Style.text(cells.kilometers, size: size, alignment: .right),
            Style.text(cells.category, size: size),
            work,
        ]
        if let amount = cells.amount {
            result.append(Style.text(amount, size: size, alignment: .right))
        } else if record.options.includeAmounts {
            result.append(Style.text("–", size: size, alignment: .right))
        }
        result.append(Style.text(cells.receipt, size: size))
        return result
    }

    private func drawHistory(on page: PageWriter) {
        let heading = Style.text(texts.historyHeading, size: 13, weight: .semibold)
        let period = Style.text(texts.periodLine(record.options.period), size: 9.5, color: Style.muted)
        let headingHeight = page.height(of: heading) + 2 + page.height(of: period) + 8

        guard !record.items.isEmpty else {
            page.ensureSpace(headingHeight + 20)
            page.draw(heading)
            page.advance(2)
            page.draw(period)
            page.advance(8)
            page.draw(Style.text(texts.emptyHistory, size: 10.5))
            page.advance(14)
            return
        }

        let columns = self.columns
        let headerCells = columns.map {
            Style.text($0.title, size: 8, weight: .semibold, color: Style.muted, alignment: $0.alignment)
        }
        let headerHeight = tableHeight(headerCells, columns: columns, page: page) + 2

        // Measure every row first: the heading must stay with the table header and the first row.
        let rows = record.items.map { item in
            cellTexts(texts.cells(for: item, receiptsAttached: record.options.includeReceiptAttachments))
        }
        let maxRowHeight = Self.bodyBottom - Self.marginTop - headingHeight - headerHeight - 4
        let heights = rows.map { min(tableHeight($0, columns: columns, page: page) + 2 * Self.rowPadding, maxRowHeight) }

        page.ensureSpace(headingHeight + headerHeight + (heights.first ?? 0))
        page.draw(heading)
        page.advance(2)
        page.draw(period)
        page.advance(8)

        let drawHeader = {
            drawRow(headerCells, columns: columns, on: page, height: headerHeight - 2)
            page.advance(headerHeight - 2)
            page.rule(color: Style.ink, thickness: 0.8)
            page.advance(2)
        }
        drawHeader()

        for (index, cells) in rows.enumerated() {
            let height = heights[index]
            if page.remaining < height {
                page.newPage()
                drawHeader()
            }
            page.advance(Self.rowPadding)
            drawRow(cells, columns: columns, on: page, height: height - 2 * Self.rowPadding)
            page.advance(height - Self.rowPadding)
            page.rule(color: Style.hairline, thickness: 0.5)
        }
        page.advance(16)
    }

    private func tableHeight(_ cells: [NSAttributedString], columns: [Column], page: PageWriter) -> CGFloat {
        zip(cells, columns).map { page.height(of: $0, width: $1.width) }.max() ?? 0
    }

    /// Draws the cells side by side at the current position. Text longer than `height` is clipped.
    private func drawRow(_ cells: [NSAttributedString], columns: [Column], on page: PageWriter, height: CGFloat) {
        var x = Self.marginLeft
        for (cell, column) in zip(cells, columns) {
            page.draw(cell, x: x, width: column.width, clippedTo: height, advance: false)
            x += column.width + Self.gutter
        }
    }

    // MARK: Costs

    private func drawCosts(on page: PageWriter) {
        let heading = Style.text(texts.costsHeading, size: 13, weight: .semibold)
        let note = Style.text(texts.costsNote, size: 9.5, color: Style.muted)
        let rowHeight: CGFloat = 17
        for costs in record.costs {
            let blockHeight = page.height(of: heading) + 2 + page.height(of: note) + 8
                + rowHeight * CGFloat(min(costs.years.count, 2) + 1)
            page.ensureSpace(blockHeight)
            page.draw(heading)
            page.advance(2)
            page.draw(note)
            page.advance(8)
            let tableWidth: CGFloat = 240
            for year in costs.years {
                if page.remaining < rowHeight { page.newPage() }
                drawCostLine(
                    texts.yearText(year.year), texts.moneyText(year.total), width: tableWidth, height: rowHeight,
                    weight: .regular, on: page)
            }
            page.rule(color: Style.ink, thickness: 0.8, length: tableWidth)
            if page.remaining < rowHeight { page.newPage() }
            drawCostLine(
                texts.totalLabel, texts.moneyText(costs.total), width: tableWidth, height: rowHeight,
                weight: .semibold, on: page)
            page.advance(10)
        }
    }

    private func drawCostLine(
        _ label: String, _ value: String, width: CGFloat, height: CGFloat, weight: UIFont.Weight,
        on page: PageWriter
    ) {
        let labelText = Style.text(label, size: 10, weight: weight)
        let valueText = Style.text(value, size: 10, weight: weight, alignment: .right)
        page.draw(labelText, x: Self.marginLeft, width: width / 2, advance: false)
        page.draw(valueText, x: Self.marginLeft + width / 2, width: width / 2, advance: false)
        page.advance(height)
    }

    // MARK: Attachments

    private enum AttachmentPage {
        case image(UIImage)
        case pdf(PDFPage)
        case missing
    }

    /// One entry per PDF page that the receipts of an entry fill. Receipts the app counted but cannot show
    /// (no data on this device yet, unreadable file) get one placeholder page each.
    private func attachmentPages(of item: ServiceRecordItem) -> [(receipt: Int, page: Int, pages: Int, content: AttachmentPage)] {
        let files = receipts[item.entry.id] ?? []
        let count = max(files.count, item.entry.receiptCount)
        var result: [(receipt: Int, page: Int, pages: Int, content: AttachmentPage)] = []
        for index in 0..<count {
            guard index < files.count else {
                result.append((index + 1, 1, 1, .missing))
                continue
            }
            let file = files[index]
            if file.isPDF {
                if let document = PDFDocument(data: file.data), document.pageCount > 0 {
                    for pageIndex in 0..<document.pageCount {
                        if let pdfPage = document.page(at: pageIndex) {
                            result.append((index + 1, pageIndex + 1, document.pageCount, .pdf(pdfPage)))
                        }
                    }
                } else {
                    result.append((index + 1, 1, 1, .missing))
                }
            } else if let image = UIImage(data: file.data) {
                result.append((index + 1, 1, 1, .image(image)))
            } else {
                result.append((index + 1, 1, 1, .missing))
            }
        }
        return result
    }

    private func drawAttachments(of item: ServiceRecordItem, on page: PageWriter, drawsImages: Bool) {
        let count = max(receipts[item.entry.id]?.count ?? 0, item.entry.receiptCount)
        for entry in attachmentPages(of: item) {
            page.newPage()
            page.draw(Style.text(texts.attachmentsHeading, size: 9.5, color: Style.muted))
            page.advance(2)
            page.draw(Style.text(texts.attachmentCaption(item), size: 11, weight: .semibold))
            page.advance(2)
            page.draw(Style.text(
                texts.receiptPosition(entry.receipt, of: count, page: entry.page, of: entry.pages),
                size: 9.5, color: Style.muted))
            page.advance(10)
            let area = CGRect(
                x: Self.marginLeft, y: page.y, width: Self.contentWidth, height: Self.bodyBottom - page.y)
            switch entry.content {
            case .missing:
                page.draw(Style.text(texts.receiptUnavailable, size: 10.5))
            case .image(let image):
                if drawsImages { drawImage(image, in: area, on: page) }
            case .pdf(let pdfPage):
                if drawsImages { drawPDFPage(pdfPage, in: area, on: page) }
            }
        }
    }

    private func fitted(_ size: CGSize, in area: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        let scale = min(area.width / size.width, area.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: area.minX + (area.width - fitted.width) / 2, y: area.minY, width: fitted.width, height: fitted.height)
    }

    private func drawImage(_ image: UIImage, in area: CGRect, on page: PageWriter) {
        image.draw(in: fitted(image.size, in: area))
    }

    /// PDF pages are drawn as an image of the page (handles rotation and crop boxes), compressed as JPEG so the
    /// result does not grow with raw bitmaps.
    private func drawPDFPage(_ pdfPage: PDFPage, in area: CGRect, on page: PageWriter) {
        let bounds = pdfPage.bounds(for: .mediaBox)
        let rotated = pdfPage.rotation % 180 != 0
        let natural = rotated ? CGSize(width: bounds.height, height: bounds.width) : bounds.size
        let target = fitted(natural, in: area)
        guard target.width > 0 else { return }
        let pixelScale: CGFloat = 3
        let thumbnail = pdfPage.thumbnail(
            of: CGSize(width: target.width * pixelScale, height: target.height * pixelScale), for: .mediaBox)
        if let jpeg = thumbnail.jpegData(compressionQuality: 0.8), let compressed = UIImage(data: jpeg) {
            compressed.draw(in: target)
        } else {
            thumbnail.draw(in: target)
        }
    }
}

// MARK: - Styles

private enum Style {
    static let ink = UIColor(white: 0.08, alpha: 1)
    static let muted = UIColor(white: 0.30, alpha: 1)
    static let hairline = UIColor(white: 0.78, alpha: 1)

    static func text(
        _ string: String, size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = ink,
        alignment: NSTextAlignment = .left
    ) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byWordWrapping
        return NSAttributedString(
            string: string,
            attributes: [
                .font: UIFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color,
                .paragraphStyle: style,
            ])
    }
}

// MARK: - Page writer

private typealias Geometry = ServiceRecordPDFRenderer

/// The cursor on the current page: starts pages, draws text and rules, keeps the footer.
private final class PageWriter {
    let context: UIGraphicsPDFRendererContext
    let texts: ServiceRecordTexts
    let totalPages: Int
    private(set) var pageNumber = 0
    private(set) var y: CGFloat = ServiceRecordPDFRenderer.marginTop

    private static let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
    init(context: UIGraphicsPDFRendererContext, texts: ServiceRecordTexts, totalPages: Int) {
        self.context = context
        self.texts = texts
        self.totalPages = totalPages
    }

    var remaining: CGFloat { Geometry.bodyBottom - y }

    func begin() {
        newPage()
    }

    func newPage() {
        context.beginPage()
        pageNumber += 1
        y = Geometry.marginTop
        drawFooter()
    }

    /// Starts a new page unless `height` still fits.
    func ensureSpace(_ height: CGFloat) {
        if remaining < height { newPage() }
    }

    func advance(_ amount: CGFloat) {
        y += amount
    }

    func height(of text: NSAttributedString, width: CGFloat = Geometry.contentWidth) -> CGFloat {
        let box = text.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude), options: Self.options, context: nil)
        return ceil(box.height)
    }

    /// Draws `text` at the cursor. `clippedTo` cuts text that is taller than the space reserved for it.
    func draw(
        _ text: NSAttributedString, x: CGFloat = Geometry.marginLeft, width: CGFloat = Geometry.contentWidth,
        clippedTo limit: CGFloat? = nil, advance moves: Bool = true
    ) {
        let natural = height(of: text, width: width)
        let height = min(natural, limit ?? natural)
        let rect = CGRect(x: x, y: y, width: width, height: height)
        let cg = context.cgContext
        cg.saveGState()
        cg.clip(to: rect)
        text.draw(with: CGRect(x: x, y: y, width: width, height: natural), options: Self.options, context: nil)
        cg.restoreGState()
        if moves { y += height }
    }

    func rule(color: UIColor = Style.hairline, thickness: CGFloat = 0.5, length: CGFloat = Geometry.contentWidth) {
        let cg = context.cgContext
        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(thickness)
        cg.move(to: CGPoint(x: Geometry.marginLeft, y: y))
        cg.addLine(to: CGPoint(x: Geometry.marginLeft + length, y: y))
        cg.strokePath()
    }

    private func drawFooter() {
        let top = Geometry.pageSize.height - 44
        let cg = context.cgContext
        cg.setStrokeColor(Style.hairline.cgColor)
        cg.setLineWidth(0.5)
        cg.move(to: CGPoint(x: Geometry.marginLeft, y: top - 6))
        cg.addLine(to: CGPoint(x: Geometry.marginLeft + Geometry.contentWidth, y: top - 6))
        cg.strokePath()

        let numberWidth: CGFloat = 90
        let gap: CGFloat = 10
        let footerWidth = Geometry.contentWidth - numberWidth - gap
        let footer = Style.text(texts.footer, size: 8, color: Style.muted)
        footer.draw(
            with: CGRect(x: Geometry.marginLeft, y: top, width: footerWidth, height: 30),
            options: Self.options, context: nil)
        let number = Style.text(texts.pageNumber(pageNumber, of: totalPages), size: 8, color: Style.muted, alignment: .right)
        number.draw(
            with: CGRect(x: Geometry.marginLeft + footerWidth + gap, y: top, width: numberWidth, height: 30),
            options: Self.options, context: nil)
    }
}
