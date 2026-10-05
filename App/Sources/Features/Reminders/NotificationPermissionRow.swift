import SwiftUI
import UIKit

/// Explains first, then shows the system prompt. Attach to the view that triggers the permission request.
struct NotificationPermissionPrompt: ViewModifier {
    @Binding var isPresented: Bool
    /// Called after the user chose, whatever the system answered.
    var onFinished: () -> Void = {}

    @Environment(NotificationPermission.self) private var permission

    func body(content: Content) -> some View {
        content.alert(
            Text("Allow notifications?", comment: "Alert title shown before the system asks for notification permission"),
            isPresented: $isPresented
        ) {
            Button {
                Task {
                    await permission.request()
                    onFinished()
                }
            } label: {
                Text("Continue", comment: "Alert button: go on to the system notification prompt")
            }
            Button(role: .cancel) {
                onFinished()
            } label: {
                Text("Not now", comment: "Alert button: do not ask for notification permission now")
            }
        } message: {
            Text(
                "Pitlog reminds you of deadlines with notifications on this device. Nothing is sent to a server. Next, iOS asks for your permission.",
                comment: "Alert message explaining why notifications are needed, before the system prompt")
        }
    }
}

extension View {
    func notificationPermissionPrompt(isPresented: Binding<Bool>, onFinished: @escaping () -> Void = {}) -> some View {
        modifier(NotificationPermissionPrompt(isPresented: isPresented, onFinished: onFinished))
    }
}

/// Row(s) for the permission state: asks if undecided, links to the system settings if denied.
struct NotificationPermissionRow: View {
    /// Settings shows the state also when everything is fine; the reminder list stays quiet.
    var showsWhenAuthorized = false

    @Environment(NotificationPermission.self) private var permission
    @State private var showingPrompt = false

    var body: some View {
        Group {
            switch permission.state {
            case .notDetermined:
                Button {
                    showingPrompt = true
                } label: {
                    Label {
                        Text("Allow notifications", comment: "Button to start the notification permission flow")
                    } icon: {
                        Image(systemName: "bell.badge")
                    }
                }
                .accessibilityIdentifier("allowNotificationsButton")
            case .denied:
                Label {
                    Text("Notifications are turned off for Pitlog. You will not get reminders.", comment: "Shown when the user denied the notification permission")
                } icon: {
                    Image(systemName: "bell.slash")
                }
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link(destination: url) {
                        Label {
                            Text("Open Settings", comment: "Link to the system settings of the app")
                        } icon: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            case .authorized:
                if showsWhenAuthorized {
                    Label {
                        Text("Notifications are allowed.", comment: "Settings: the notification permission is granted")
                    } icon: {
                        Image(systemName: "bell")
                    }
                }
            }
        }
        .notificationPermissionPrompt(isPresented: $showingPrompt)
    }
}
