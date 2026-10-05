import Testing
@testable import PitlogCore

private func cell(_ text: String, x: Double, y: Double, page: Int? = nil, h: Double = 0.02) -> RecognizedLine {
    RecognizedLine(text: text, box: Rect(x: x, y: y, w: 0.2, h: h), page: page)
}

struct LineJoinerTests {
    @Test func joinsCellsOnTheSameHeightLeftToRight() {
        let lines = [
            cell("120,00", x: 0.7, y: 0.50),
            cell("Gesamtbetrag", x: 0.1, y: 0.501),
            cell("Werkstatt GmbH", x: 0.1, y: 0.1),
        ]
        let joined = LineJoiner.joinRows(lines)
        #expect(joined.map(\.text) == ["Werkstatt GmbH", "Gesamtbetrag 120,00"])
    }

    @Test func keepsRowsApartThatDifferInHeight() {
        let lines = [cell("Summe netto", x: 0.1, y: 0.40), cell("100,00", x: 0.7, y: 0.45)]
        #expect(LineJoiner.joinRows(lines).map(\.text) == ["Summe netto", "100,00"])
    }

    @Test func neverJoinsAcrossPages() {
        let lines = [cell("Seite", x: 0.1, y: 0.5, page: 1), cell("zwei", x: 0.5, y: 0.5, page: 2)]
        let joined = LineJoiner.joinRows(lines)
        #expect(joined.map(\.text) == ["Seite", "zwei"])
        #expect(joined.map(\.page) == [1, 2])
    }

    @Test func returnsTheInputWithoutBoxes() {
        let lines = [RecognizedLine("Gesamtbetrag"), RecognizedLine("120,00")]
        #expect(LineJoiner.joinRows(lines) == lines)
    }

    @Test func returnsTheInputIfOneBoxIsMissing() {
        let lines = [cell("A", x: 0.1, y: 0.5), RecognizedLine("B")]
        #expect(LineJoiner.joinRows(lines) == lines)
    }

    @Test func joinedRowCarriesTheUnionBoxAndThePage() throws {
        let joined = LineJoiner.joinRows([cell("a", x: 0.1, y: 0.5, page: 3), cell("b", x: 0.5, y: 0.5, page: 3)])
        #expect(joined.count == 1)
        #expect(joined.first?.page == 3)
        let box = try #require(joined.first?.box)
        #expect(abs(box.x - 0.1) < 1e-9)
        #expect(abs(box.w - 0.6) < 1e-9)
        #expect(abs(box.h - 0.02) < 1e-9)
    }
}
