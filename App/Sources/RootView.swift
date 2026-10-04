import SwiftUI

/// Top-level navigation. Each tab is a placeholder until its milestone lands.
struct RootView: View {
    var body: some View {
        TabView {
            Tab {
                NavigationStack {
                    ContentUnavailableView {
                        Label {
                            Text("Nothing due", comment: "Empty state title on the Upcoming tab")
                        } icon: {
                            Image(systemName: "calendar")
                        }
                    } description: {
                        Text(
                            "Upcoming inspections and reminders for all your vehicles will appear here.",
                            comment: "Empty state description on the Upcoming tab"
                        )
                    }
                    .navigationTitle(Text("Upcoming", comment: "Navigation title of the Upcoming tab"))
                }
            } label: {
                Label {
                    Text("Upcoming", comment: "Tab bar item for upcoming deadlines")
                } icon: {
                    Image(systemName: "calendar")
                }
            }

            Tab {
                NavigationStack {
                    ContentUnavailableView {
                        Label {
                            Text("No vehicles", comment: "Empty state title on the Vehicles tab")
                        } icon: {
                            Image(systemName: "car")
                        }
                    } description: {
                        Text(
                            "Add a vehicle to keep track of inspections, service and costs.",
                            comment: "Empty state description on the Vehicles tab"
                        )
                    }
                    .navigationTitle(Text("Vehicles", comment: "Navigation title of the Vehicles tab"))
                }
            } label: {
                Label {
                    Text("Vehicles", comment: "Tab bar item for the vehicle list")
                } icon: {
                    Image(systemName: "car")
                }
            }

            Tab {
                NavigationStack {
                    List {}
                        .navigationTitle(Text("Settings", comment: "Navigation title of the Settings tab"))
                }
            } label: {
                Label {
                    Text("Settings", comment: "Tab bar item for settings")
                } icon: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }
}

#Preview {
    RootView()
}

#Preview("German") {
    RootView()
        .environment(\.locale, Locale(identifier: "de_AT"))
}
