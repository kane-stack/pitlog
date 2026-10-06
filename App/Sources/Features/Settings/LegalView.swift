import PitlogCore
import SwiftUI

struct LegalView: View {
    var body: some View {
        // A scroll view of plain cards instead of a List: List cells failed the Dynamic Type audit.
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                card {
                    heading(Text("Disclaimer", comment: "Legal screen: section header"))
                    LegalNoticeView()
                    Text("Pitlog calculates inspection deadlines from the first registration and the date on your inspection sticker. Some rules of the 2027 inspection reform are still legally open. In doubt the app shows the earlier deadline. It does not replace the sticker, the registration certificate or advice from an inspection station.", comment: "Legal screen: full disclaimer")
                        .wrapsText()
                }

                card {
                    Text("Rule version", comment: "Legal screen: label for the version of the rule set")
                    Text(verbatim: AustriaInspectionRules.ruleVersion)
                }

                card {
                    heading(Text("Official sources", comment: "Legal screen: section header for the list of legal sources"))
                    // Static references, no network calls (privacy: CloudKit only).
                    Text(verbatim: "§ 57a KFG 1967")
                    Text(verbatim: "§ 132 Abs. 37 KFG")
                    Text(verbatim: "§ 135 Abs. 51 KFG")
                    Text(verbatim: "BGBl. I Nr. 79/2026 (42. KFG-Novelle)")
                    Text("You can look these provisions up in the Austrian Legal Information System (RIS).", comment: "Legal screen: hint where to find the sources, no link on purpose")
                        .font(.footnote)
                        .wrapsText()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Text("Legal", comment: "Navigation title of the legal screen"))
        .navigationBarTitleDisplayMode(.inline)
        // Pushed from Settings: hide the floating tab bar so it never overlaps the last rows.
        .toolbar(.hidden, for: .tabBar)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func heading(_ title: Text) -> some View {
        title
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
    }
}
