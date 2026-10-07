import SwiftUI

/// The "Pro" mark on locked features: a lock, the word and an outline, so it never depends on color.
struct ProBadge: View {
    var body: some View {
        Label {
            Text("Pro", comment: "Badge on a feature that needs Wagemo Pro. Keep it short.")
        } icon: {
            Image(systemName: "lock.fill")
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .overlay(Capsule().strokeBorder(Color.primary, lineWidth: 1))
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Requires Wagemo Pro", comment: "VoiceOver label of the Pro badge on a locked feature"))
    }
}

/// A row that does something on tap: icon and wrapping text, optionally with the Pro badge. Like the other
/// action rows of the app it is a tappable row with the button trait (see docs/accessibility-audit.md).
struct ActionRow: View {
    let title: Text
    let systemImage: String
    var showsProBadge = false
    var identifier: String
    var accessibilityLabelText: Text?
    let action: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Label {
                title.fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: systemImage)
            }
            .foregroundStyle(Color.accentColor)
            if showsProBadge {
                Spacer(minLength: 8)
                ProBadge()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityElement(children: showsProBadge ? .ignore : .combine)
        .accessibilityLabel(accessibilityLabelText ?? title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
        .accessibilityIdentifier(identifier)
    }
}

/// Tells that a vehicle is beyond the free limit: it stays readable, changes need Pro. Text and symbol, not color.
struct ReadOnlyBanner: View {
    let onUnlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Read only", comment: "Title of the notice on a vehicle that is over the free limit")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "lock.fill")
            }
            Text(
                "The free plan lets you edit one vehicle. This vehicle stays here and you can read everything. Wagemo Pro unlocks editing for all your vehicles.",
                comment: "Notice on a vehicle that is over the free limit"
            )
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            ActionRow(
                title: Text("About Wagemo Pro", comment: "Row that opens the paywall"),
                systemImage: "sparkles", identifier: "readOnlyUnlockRow", action: onUnlock)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
