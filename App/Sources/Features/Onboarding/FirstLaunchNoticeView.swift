import SwiftUI

/// Disclaimer sheet shown once; the user must acknowledge it.
struct FirstLaunchNoticeView: View {
    var onAcknowledge: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "checkmark.seal")
                        .font(.largeTitle)
                        .accessibilityHidden(true)
                    Text("Before you start", comment: "First launch notice: title")
                        .font(.title)
                        .fontWeight(.bold)
                        .wrapsText()
                    Text("Wagemo helps you keep track of inspection deadlines. The calculation is a suggestion based on the first registration and the rules known today.", comment: "First launch notice: what the app does")
                        .wrapsText()
                    LegalNoticeText.text
                        .accessibilityLabel(LegalNoticeText.spoken)
                        .fontWeight(.semibold)
                        .wrapsText()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Some rules of the 2027 inspection reform are still legally open. In doubt the app shows the earlier deadline.", comment: "First launch notice: open legal questions")
                        .wrapsText()
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: onAcknowledge) {
                    Text("I understand", comment: "First launch notice: button to acknowledge")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("acknowledgeButton")
                .padding()
                .background(.bar)
            }
        }
        .interactiveDismissDisabled()
    }
}

#Preview {
    FirstLaunchNoticeView {}
}
