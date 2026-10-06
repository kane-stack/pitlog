import SwiftUI

extension View {
    /// Multi-line text that never gets clipped: it wraps and grows vertically at any Dynamic Type size.
    /// Long German compounds break at the soft hyphens (U+00AD) of the `de` strings; the text is never scaled down.
    func wrapsText() -> some View {
        self.fixedSize(horizontal: false, vertical: true)
    }
}

extension String {
    /// The string without soft hyphens (U+00AD). Use it wherever a localized string is not drawn by a SwiftUI
    /// view: notifications, the PDF, file names and spoken labels.
    var withoutSoftHyphens: String {
        replacing("\u{00AD}", with: "")
    }
}
