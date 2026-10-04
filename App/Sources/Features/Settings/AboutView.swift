import SwiftUI

struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 2) {
                Text("Version", comment: "About screen: app version label")
                Text(verbatim: version)
            }
            .accessibilityElement(children: .combine)
        }
        .navigationTitle(Text("About", comment: "Navigation title of the about screen"))
        .navigationBarTitleDisplayMode(.inline)
        // Pushed from Settings: hide the floating tab bar so it never overlaps the last rows.
        .toolbar(.hidden, for: .tabBar)
    }
}
