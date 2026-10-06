import SwiftUI

/// Icon plus multi-line text. Unlike `Label` the text is never squeezed: it wraps at any Dynamic Type size.
struct InfoRow: View {
    let text: Text
    let systemImage: String

    init(_ text: Text, systemImage: String) {
        self.text = text
        self.systemImage = systemImage
    }

    init(verbatim string: String, systemImage: String) {
        self.init(Text(verbatim: string), systemImage: systemImage)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            text
                .wrapsText()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
