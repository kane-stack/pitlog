import SwiftUI

/// The legal notice that must be visible wherever a Pickerl deadline is shown. Never collapsible.
struct LegalNoticeView: View {
    var body: some View {
        InfoRow(
            Text("Without guarantee. The date punched on your inspection sticker is authoritative.", comment: "Legal notice shown with every inspection deadline"),
            systemImage: "info.circle"
        )
        // Primary color on purpose: the notice must stay readable on any background (audit contrast).
        .font(.footnote)
        .foregroundStyle(.primary)
    }
}
