import SwiftUI

/// Label above a stepper. The stepper's own label is drawn by UIKit and fails the Dynamic Type audit, so the
/// text is plain SwiftUI and the stepper control carries only the accessibility label.
struct LeadStepper: View {
    let title: Text
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            title
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
            Stepper(value: $value, in: range, step: step) {
                title
            }
            .labelsHidden()
            .accessibilityLabel(title)
            .accessibilityValue(Text(value, format: .number))
        }
    }
}
