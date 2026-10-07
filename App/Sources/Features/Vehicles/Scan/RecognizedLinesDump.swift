#if DEBUG
import PitlogCore

/// Debug only (never compiled into Release): the recognized lines as plain text, one per line, with the normalized
/// box (`x y w h`, origin top left) in front, for diagnosing how a real certificate was read.
/// The text holds whatever the certificate shows, including the holder's name and address.
enum RecognizedLinesDump {
    static func text(from pages: [[RecognizedLine]]) -> String {
        var output: [String] = [
            "# Recognized lines per page: x y w h | text (origin top left, 0...1)",
            "# \(pages.count) page(s): " + pages.map { "\($0.count) lines" }.joined(separator: ", "),
        ]
        for (index, page) in pages.enumerated() {
            output.append("")
            output.append("## page \(index + 1) of \(pages.count) (\(page.count) lines)")
            if page.isEmpty { output.append("(no lines recognized)") }
            for line in page {
                if let box = line.box {
                    output.append("\(format(box.x)) \(format(box.y)) \(format(box.w)) \(format(box.h)) | \(line.text)")
                } else {
                    output.append("- - - - | \(line.text)")
                }
            }
        }
        return output.joined(separator: "\n")
    }

    /// Fixed three decimals without `String(format:)`, so the output does not depend on the locale.
    private static func format(_ value: Double) -> String {
        let thousandths = Int((value * 1000).rounded())
        let whole = thousandths / 1000
        let fraction = abs(thousandths % 1000)
        let padded = fraction < 10 ? "00\(fraction)" : (fraction < 100 ? "0\(fraction)" : "\(fraction)")
        return "\(thousandths < 0 && whole == 0 ? "-" : "")\(whole).\(padded)"
    }
}
#endif
