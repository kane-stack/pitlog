import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var paywall: PaywallContext?
    @State private var showingManageSubscription = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    Label {
                        Text("Notifications", comment: "Settings row for the notification settings")
                    } icon: {
                        Image(systemName: "bell")
                    }
                }
                .accessibilityIdentifier("settingsNotificationsRow")
            }

            Section {
                NavigationLink {
                    LegalView()
                } label: {
                    Label {
                        Text("Legal", comment: "Settings row for the legal notice screen")
                    } icon: {
                        Image(systemName: "scroll")
                    }
                }
                NavigationLink {
                    ArchivedVehiclesView()
                } label: {
                    Label {
                        Text("Archived vehicles", comment: "Settings row for archived vehicles")
                    } icon: {
                        Image(systemName: "archivebox")
                    }
                }
                NavigationLink {
                    AboutView()
                } label: {
                    Label {
                        Text("About", comment: "Settings row for the about screen")
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                }
                // Last in the section on purpose: the UI tests pick the rows above by position.
                if let privacy = AppLinks.privacyPolicy {
                    // The tap row of the app instead of `Link`: a `Link` in a list failed the audit (contrast, clipped text).
                    ActionRow(
                        title: Text("Privacy Policy", comment: "Link to the privacy policy (paywall and settings)"),
                        systemImage: "hand.raised",
                        identifier: "settingsPrivacyRow",
                        action: { openURL(privacy) })
                }
            }

            // After the rows above on purpose: the UI tests pick those by position.
            ProSettingsSection(
                onShowPaywall: { paywall = .general },
                onManageSubscription: { showingManageSubscription = true })

            // Last on purpose: the UI tests pick the rows above by position.
            #if DEBUG
            Section {
                NavigationLink {
                    DeveloperView()
                } label: {
                    Label {
                        Text(verbatim: "Developer")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "hammer")
                    }
                }
                .accessibilityIdentifier("settingsDeveloperRow")
            }
            #endif
        }
        .navigationTitle(Text("Settings", comment: "Navigation title of the Settings tab"))
        .paywall($paywall)
        .manageSubscriptionsSheet(isPresented: $showingManageSubscription)
    }
}
