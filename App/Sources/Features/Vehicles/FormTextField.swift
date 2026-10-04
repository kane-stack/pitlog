import SwiftUI

/// Text field with a visible label in the primary color. The system placeholder is too light for the
/// contrast audit and disappears while typing, so it is not used.
struct FormTextField: View {
    let title: Text
    @Binding var text: String

    var body: some View {
        LabeledContent {
            TextField(text: $text, prompt: Text(verbatim: "")) { title }
                .multilineTextAlignment(.trailing)
        } label: {
            title
                .foregroundStyle(.primary)
        }
    }
}

struct FormNumberField: View {
    let title: Text
    @Binding var value: Int?

    var body: some View {
        LabeledContent {
            TextField(value: $value, format: .number, prompt: Text(verbatim: "")) { title }
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
        } label: {
            title
                .foregroundStyle(.primary)
        }
    }
}
