import Foundation

/// Puts cells of one table row back together for parsers that need label and value in the same line.
///
/// Vision returns a receipt row such as `Gesamtbetrag ........ 120,00` as two separate lines when the gap is wide.
/// Lines on the same height (and the same page) are joined left to right. Without a box on every line the input
/// is returned unchanged: no geometry, no guessing.
public enum LineJoiner {
    public static func joinRows(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        let boxed = lines.compactMap { line -> (line: RecognizedLine, box: Rect)? in
            line.box.map { (line, $0) }
        }
        guard lines.count > 1, boxed.count == lines.count else { return lines }

        var result: [RecognizedLine] = []
        let pages = Set(boxed.map { $0.line.page ?? 0 }).sorted()
        for page in pages {
            let onPage = boxed.filter { ($0.line.page ?? 0) == page }
            result.append(contentsOf: joinPage(onPage, page: page == 0 ? nil : page))
        }
        return result
    }

    private struct Row {
        var middle: Double
        var height: Double
        var cells: [(line: RecognizedLine, box: Rect)]
    }

    private static func joinPage(_ cells: [(line: RecognizedLine, box: Rect)], page: Int?) -> [RecognizedLine] {
        let sorted = cells.sorted { ($0.box.midY, $0.box.x) < ($1.box.midY, $1.box.x) }
        var rows: [Row] = []
        for cell in sorted {
            if let last = rows.last, abs(cell.box.midY - last.middle) <= 0.5 * min(cell.box.h, last.height) {
                var row = last
                let count = Double(row.cells.count)
                row.middle = (row.middle * count + cell.box.midY) / (count + 1)
                row.height = (row.height * count + cell.box.h) / (count + 1)
                row.cells.append(cell)
                rows[rows.count - 1] = row
            } else {
                rows.append(Row(middle: cell.box.midY, height: cell.box.h, cells: [cell]))
            }
        }
        return rows.map { row in
            if row.cells.count == 1, let only = row.cells.first { return only.line }
            let ordered = row.cells.sorted { $0.box.x < $1.box.x }
            let text = ordered.map { $0.line.text }.joined(separator: " ")
            let minX = ordered.map { $0.box.x }.min() ?? 0
            let minY = ordered.map { $0.box.y }.min() ?? 0
            let maxX = ordered.map { $0.box.x + $0.box.w }.max() ?? minX
            let maxY = ordered.map { $0.box.y + $0.box.h }.max() ?? minY
            return RecognizedLine(
                text: text, box: Rect(x: minX, y: minY, w: maxX - minX, h: maxY - minY), page: page)
        }
    }
}
