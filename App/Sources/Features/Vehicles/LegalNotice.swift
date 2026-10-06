import SwiftUI

/// The legal notice that must be visible wherever a Pickerl deadline is shown. Never collapsible.
struct LegalNoticeView: View {
    var body: some View {
        InfoRow(LegalNoticeText.text, systemImage: "info.circle")
            // One element with a spoken label without soft hyphens (see `LegalNoticeText`).
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(LegalNoticeText.spoken)
            // Primary color on purpose: the notice must stay readable on any background (audit contrast).
            .font(.footnote)
            .foregroundStyle(.primary)
    }
}

/// The wording of the legal notice, shared by the notice view and the first launch sheet.
enum LegalNoticeText {
    private static let resource = LocalizedStringResource("Without guarantee. The date punched on your inspection sticker is authoritative.", comment: "Legal notice shown with every inspection deadline")

    static var text: Text { Text(resource) }

    /// The German text carries soft hyphens for line breaking; VoiceOver gets the plain string.
    static var spoken: Text { Text(verbatim: String(localized: resource).withoutSoftHyphens) }
}
