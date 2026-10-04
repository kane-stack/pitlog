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
            LabeledContent {
                Text(verbatim: version)
            } label: {
                Text("Version", comment: "About screen: app version label")
            }
        }
        .navigationTitle(Text("About", comment: "Navigation title of the about screen"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
