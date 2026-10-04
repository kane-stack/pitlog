import SwiftUI

/// Top-level navigation: Upcoming, Vehicles, Settings.
struct RootView: View {
    @AppStorage("legalNoticeAcknowledged") private var acknowledged = false

    var body: some View {
        TabView {
            Tab {
                NavigationStack { UpcomingView() }
            } label: {
                Label {
                    Text("Upcoming", comment: "Tab bar item for upcoming deadlines")
                } icon: {
                    Image(systemName: "calendar")
                }
            }

            Tab {
                NavigationStack { VehicleListView() }
            } label: {
                Label {
                    Text("Vehicles", comment: "Tab bar item for the vehicle list")
                } icon: {
                    Image(systemName: "car")
                }
            }

            Tab {
                NavigationStack { SettingsView() }
            } label: {
                Label {
                    Text("Settings", comment: "Tab bar item for settings")
                } icon: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: Binding(get: { !acknowledged }, set: { _ in })) {
            FirstLaunchNoticeView { acknowledged = true }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container())
}

#Preview("German") {
    RootView()
        .modelContainer(PreviewData.container())
        .environment(\.locale, Locale(identifier: "de_AT"))
}
