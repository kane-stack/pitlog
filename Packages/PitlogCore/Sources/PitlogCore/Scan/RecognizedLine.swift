/// A rectangle in normalized image coordinates: 0...1 in both axes, origin at the top left, y grows downwards.
/// The text recognizer in the app converts from Vision's bottom-left origin.
public struct Rect: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    var midY: Double { y + h / 2 }
}

/// One line of recognized text, the single line type of the scan pipeline (registration documents and receipts).
///
/// The box is optional: the parsers work with text alone and the registration parser uses the geometry, when every
/// line has one, to put cells of the same table row back together. The page index is optional as well: it is only
/// set when several pages are passed as one concatenated list (receipts); the page-wise registration API takes
/// `[[RecognizedLine]]` instead.
public struct RecognizedLine: Hashable, Sendable {
    public var text: String
    public var box: Rect?
    /// 1-based page number, if the line belongs to a multi-page document passed as a flat list.
    public var page: Int?

    public init(text: String, box: Rect? = nil, page: Int? = nil) {
        self.text = text
        self.box = box
        self.page = page
    }

    /// Text-only line, e.g. for fixtures and for the receipt parser's plain input.
    public init(_ text: String, page: Int? = nil) {
        self.init(text: text, box: nil, page: page)
    }
}
