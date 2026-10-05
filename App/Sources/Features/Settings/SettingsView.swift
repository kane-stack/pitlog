import SwiftUI

struct SettingsView: View {
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

            #if DEBUG
            Section {
                NavigationLink {
                    DeveloperView()
                } label: {
                    Label {
                        Text(verbatim: "Developer")
                    } icon: {
                        Image(systemName: "hammer")
                    }
                }
                .accessibilityIdentifier("settingsDeveloperRow")
            }
            #endif

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
            }
        }
        .navigationTitle(Text("Settings", comment: "Navigation title of the Settings tab"))
    }
}
