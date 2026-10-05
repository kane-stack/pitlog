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

/// One line of recognized text. The box is optional: the parser works with text alone and uses the
/// geometry, when every line has one, to put cells of the same table row back together.
public struct RecognizedLine: Hashable, Sendable {
    public var text: String
    public var box: Rect?

    public init(text: String, box: Rect? = nil) {
        self.text = text
        self.box = box
    }
}
