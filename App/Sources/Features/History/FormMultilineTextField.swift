import SwiftUI

/// Like `FormTextField`, for several lines: the label sits above the field, which grows with its text.
struct FormMultilineTextField: View {
    let title: Text
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            title
                .foregroundStyle(.primary)
            TextField(text: $text, prompt: Text(verbatim: ""), axis: .vertical) { title }
                .lineLimit(2...8)
                .accessibilityLabel(title)
        }
    }
}
