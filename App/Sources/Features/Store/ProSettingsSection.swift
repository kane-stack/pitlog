import SwiftUI

/// The "Pitlog Pro" section of the settings: status, buy, restore, manage the subscription.
/// The sheets (paywall, subscription management) hang on the list, so this section only reports taps.
struct ProSettingsSection: View {
    let onShowPaywall: () -> Void
    let onManageSubscription: () -> Void

    @Environment(\.locale) private var locale
    @Environment(StoreService.self) private var store

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Label {
                    Text(verbatim: "Pitlog Pro")
                        .font(.headline)
                } icon: {
                    Image(systemName: "sparkles")
                }
                statusText
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("proStatusRow")

            if store.status.source == .none {
                ActionRow(
                    title: Text("Get Pitlog Pro", comment: "Settings: opens the paywall"),
                    systemImage: "lock.open", identifier: "getProRow", action: onShowPaywall)
            }
            if store.status.source == .subscription {
                ActionRow(
                    title: Text("Manage subscription", comment: "Settings: opens the App Store subscription management"),
                    systemImage: "creditcard", identifier: "manageSubscriptionRow", action: onManageSubscription)
            }
            ActionRow(
                title: Text("Restore purchases", comment: "Paywall and settings: restores earlier purchases"),
                systemImage: "arrow.clockwise.circle", identifier: "settingsRestorePurchasesRow"
            ) {
                Task { await store.restore() }
            }
            if let message = store.message {
                InfoRow(messageText(message), systemImage: "info.circle")
                    .font(.subheadline)
                    .accessibilityIdentifier("proMessage")
            }
        }
    }

    private var statusText: Text {
        let status = store.status
        switch status.source {
        case .none:
            return Text("Free plan: one vehicle, the inspection reminder and the costs of the current year.", comment: "Settings: status of the free plan")
        case .lifetime:
            return status.isFamilyShared
                ? Text("Lifetime, shared by a family member.", comment: "Settings: status when Pro comes from a lifetime purchase of a family member")
                : Text("Lifetime. Thank you for your support.", comment: "Settings: status of the lifetime purchase")
        case .subscription:
            let date = status.expiresAt.map { $0.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(locale)) } ?? ""
            if status.isInGracePeriod {
                return Text("The subscription could not be renewed. Pro stays on while the App Store retries the payment. Check your payment method.", comment: "Settings: status of a subscription in its grace period")
            }
            return status.isFamilyShared
                ? Text("Subscription shared by a family member, active until \(date).", comment: "Settings: status of a shared subscription. Argument: the end of the current period")
                : Text("Subscription active until \(date).", comment: "Settings: status of the subscription. Argument: the end of the current period")
        }
    }

    private func messageText(_ message: StoreService.Message) -> Text {
        switch message {
        case .purchasePending:
            Text("Your purchase is waiting for approval. Pro starts as soon as it goes through.", comment: "Paywall: the purchase is pending, for example Ask to Buy")
        case .purchaseFailed:
            Text("The purchase did not go through. You have not been charged. Try again.", comment: "Paywall: the purchase failed")
        case .restoreFailed:
            Text("Purchases could not be restored. Check your connection and try again.", comment: "Paywall: restoring failed")
        case .nothingToRestore:
            Text("No earlier purchase of Pitlog Pro was found for this Apple Account.", comment: "Paywall: restoring found nothing")
        }
    }
}
