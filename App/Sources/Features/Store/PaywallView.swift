import PitlogCore
import SwiftUI

/// The Pitlog Pro paywall (ADR-11). It shows what Pro includes, both products with the price from StoreKit,
/// the free trial only for users who are eligible for it, the renewal terms (App Store Review Guideline
/// 3.1.2), "Restore purchases" and the links to the terms and the privacy policy.
struct PaywallView: View {
    let context: PaywallContext

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(StoreService.self) private var store

    private struct Benefit: Identifiable {
        let id: PaywallContext
        let systemImage: String
        let title: Text
        let detail: Text
    }

    private var benefits: [Benefit] {
        [
            Benefit(
                id: .vehicles, systemImage: "car.2",
                title: Text("More vehicles", comment: "Pitlog Pro benefit"),
                detail: Text("Keep as many vehicles as you like and edit all of them.", comment: "Pitlog Pro benefit: more vehicles")),
            Benefit(
                id: .reminders, systemImage: "bell.badge",
                title: Text("More reminders", comment: "Pitlog Pro benefit"),
                detail: Text("Tyre changes, service, vignette and your own reminders.", comment: "Pitlog Pro benefit: reminders")),
            Benefit(
                id: .receiptScan, systemImage: "doc.text.viewfinder",
                title: Text("Receipt scan", comment: "Pitlog Pro benefit"),
                detail: Text("Scan a workshop receipt and check the values before you save.", comment: "Pitlog Pro benefit: receipt scan")),
            Benefit(
                id: .costs, systemImage: "chart.bar",
                title: Text("Costs over the years", comment: "Pitlog Pro benefit"),
                detail: Text("Earlier years and the chart across all years.", comment: "Pitlog Pro benefit: costs over several years")),
            Benefit(
                id: .serviceRecordExport, systemImage: "doc.richtext",
                title: Text("Service record", comment: "Pitlog Pro benefit"),
                detail: Text("A PDF of the history of a vehicle, for example for selling it.", comment: "Pitlog Pro benefit: PDF service record")),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if let note = contextNote {
                        InfoRow(note, systemImage: "lock.fill")
                            .font(.subheadline.weight(.semibold))
                            .accessibilityIdentifier("paywallContextNote")
                    }
                    benefitList
                    freeNote
                    purchaseSection
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .navigationTitle(Text(verbatim: "Pitlog Pro"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close", comment: "Button that closes the paywall")
                    }
                    .accessibilityIdentifier("paywallCloseButton")
                }
            }
        }
        .task { await store.loadProducts() }
        .onChange(of: store.tier) { _, tier in
            if tier == .pro { dismiss() }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Pitlog Pro")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text("Everything for more than one vehicle. No ads, no tracking.", comment: "Paywall: one-line summary")
                .font(.title3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var contextNote: Text? {
        switch context {
        case .general:
            nil
        case .vehicles:
            Text("More than one vehicle is part of Pitlog Pro. Nothing is ever deleted, your other vehicles stay readable.", comment: "Paywall: shown when the user wanted to add or edit another vehicle")
        case .reminders:
            Text("Reminders for tyres, service, vignette and your own are part of Pitlog Pro. The inspection reminder stays free.", comment: "Paywall: shown when the user wanted a locked reminder")
        case .receiptScan:
            Text("Scanning receipts is part of Pitlog Pro. You can still attach receipts as photos or files.", comment: "Paywall: shown when the user wanted to scan a receipt")
        case .serviceRecordExport:
            Text("The service record as a PDF is part of Pitlog Pro. Your history stays free.", comment: "Paywall: shown when the user wanted to export the service record")
        case .costs:
            Text("Costs of earlier years and the chart across all years are part of Pitlog Pro. The current year stays free.", comment: "Paywall: shown when the user wanted the costs of earlier years")
        }
    }

    private var benefitList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What is included", comment: "Paywall: header of the list of Pro features")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(benefits) { benefit in
                let wanted = benefit.id == context
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: benefit.systemImage)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        benefit.title
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        benefit.detail
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(wanted ? 10 : 0)
                .overlay {
                    if wanted {
                        RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary, lineWidth: 2)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(wanted ? Text("The feature you wanted", comment: "VoiceOver: marks the Pro feature the user tried to use") : Text(verbatim: ""))
            }
        }
    }

    private var freeNote: some View {
        InfoRow(
            Text("Always free: the inspection deadline with reminders, the registration scan, your history, receipts as photos or files and the costs of the current year.", comment: "Paywall: what stays free"),
            systemImage: "checkmark.circle")
            .font(.subheadline)
    }

    @ViewBuilder
    private var purchaseSection: some View {
        switch store.productsState {
        case .idle, .loading:
            ProgressView {
                Text("Loading prices…", comment: "Paywall: shown while the products load")
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("paywallLoading")
        case .failed:
            VStack(alignment: .leading, spacing: 8) {
                Text("The prices could not be loaded. Check your connection and try again.", comment: "Paywall: the products could not be loaded")
                    .fixedSize(horizontal: false, vertical: true)
                ActionRow(
                    title: Text("Try again", comment: "Paywall: reload the products"), systemImage: "arrow.clockwise",
                    identifier: "paywallRetryRow"
                ) {
                    Task { await store.loadProducts() }
                }
            }
        case .loaded:
            ForEach(store.products) { product in
                card(product)
            }
        }
    }

    private func card(_ product: StoreProduct) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: product.displayName)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            priceText(product)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let trial = product.freeTrial {
                let duration = trial.localized(locale: locale)
                Text("\(duration) free, then \(product.displayPrice) per year. Cancel any time.", comment: "Paywall: free trial of the subscription. First argument: the length such as 14 days, second: the price")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if product.kind == .lifetime {
                Text("One purchase, no subscription. Yours for good.", comment: "Paywall: explains the lifetime purchase")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if product.isFamilyShareable {
                Text("Family Sharing included", comment: "Paywall: the product can be shared with the family")
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            buyButton(product)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("paywallCard-\(product.kind == .lifetime ? "lifetime" : "yearly")")
    }

    private func priceText(_ product: StoreProduct) -> Text {
        guard let period = product.period else { return Text(verbatim: product.displayPrice) }
        let price = product.displayPrice
        if period.value == 1 {
            switch period.unit {
            case .year: return Text("\(price) per year", comment: "Paywall: price of the yearly subscription. Argument: the price")
            case .month: return Text("\(price) per month", comment: "Paywall: price of a monthly subscription. Argument: the price")
            case .week: return Text("\(price) per week", comment: "Paywall: price of a weekly subscription. Argument: the price")
            case .day: return Text("\(price) per day", comment: "Paywall: price of a daily subscription. Argument: the price")
            }
        }
        let duration = period.localized(locale: locale)
        return Text("\(price) every \(duration)", comment: "Paywall: price of a subscription with a longer period. First argument: the price, second: the length such as 3 months")
    }

    @ViewBuilder
    private func buyButton(_ product: StoreProduct) -> some View {
        let busy = store.activity != .idle
        Button {
            Task { await store.purchase(product) }
        } label: {
            Group {
                switch product.kind {
                case .subscription where product.freeTrial != nil:
                    Text("Start free trial", comment: "Paywall: button that starts the free trial of the subscription")
                case .subscription:
                    Text("Subscribe", comment: "Paywall: button that starts the subscription")
                case .lifetime:
                    Text("Buy for \(product.displayPrice)", comment: "Paywall: button that buys the lifetime purchase. Argument: the price")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(busy)
        .accessibilityIdentifier("paywallBuy-\(product.kind == .lifetime ? "lifetime" : "yearly")")
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let message = store.message {
                InfoRow(messageText(message), systemImage: "info.circle")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("paywallMessage")
            }
            ActionRow(
                title: Text("Restore purchases", comment: "Paywall and settings: restores earlier purchases"),
                systemImage: "arrow.clockwise.circle", identifier: "restorePurchasesRow"
            ) {
                Task { await store.restore() }
            }
            Text(
                "Payment is charged to your Apple Account when you confirm the purchase. The subscription renews every year at the price shown unless you cancel at least 24 hours before the end of the current period. You can manage and cancel it in the settings of your Apple Account. The free trial ends automatically into the paid subscription unless you cancel before it ends. The lifetime purchase is paid once and does not renew.",
                comment: "Paywall: renewal terms required by the App Store (automatic renewal, cancellation, payment)"
            )
            .font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                if let terms = AppLinks.termsOfUse {
                    Link(destination: terms) {
                        Text("Terms of Use", comment: "Paywall: link to the terms of use (Apple's standard license agreement)")
                    }
                    .accessibilityIdentifier("termsLink")
                }
                if let privacy = AppLinks.privacyPolicy {
                    Link(destination: privacy) {
                        Text("Privacy Policy", comment: "Paywall: link to the privacy policy")
                    }
                    .accessibilityIdentifier("privacyLink")
                }
            }
            .font(.footnote)
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

#if DEBUG
#Preview {
    PaywallView(context: .receiptScan)
        .environment(StoreService(backend: StubStoreBackend.free, defaults: UserDefaults(suiteName: "preview") ?? .standard))
}
#endif
