import SwiftUI

/// The legal notice that must be visible wherever a Pickerl deadline is shown. Never collapsible.
struct LegalNoticeView: View {
    var body: some View {
        Label {
            Text("Without guarantee. The date punched on your inspection sticker is authoritative.", comment: "Legal notice shown with every inspection deadline")
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
