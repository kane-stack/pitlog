import SwiftUI

/// Menu-style picker row with a primary label and an accent-colored value. The system picker value is
/// secondary (fails the contrast audit) and truncates at large Dynamic Type sizes.
struct MenuPickerRow<Value: Hashable, Options: View>: View {
    let title: Text
    let valueText: Text
    @Binding var selection: Value
    @ViewBuilder let options: () -> Options

    var body: some View {
        Menu {
            Picker(selection: $selection) {
                options()
            } label: {
                title
            }
        } label: {
            HStack(alignment: .firstTextBaseline) {
                title
                    .foregroundStyle(.primary)
                Spacer()
                valueText
                    .foregroundStyle(Color.accentColor)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.up.chevron.down")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(valueText)
        .accessibilityAddTraits(.isButton)
    }
}
