import PitlogCore
import SwiftUI

struct LegalView: View {
    var body: some View {
        List {
            Section {
                heading(Text("Disclaimer", comment: "Legal screen: section header"))
                LegalNoticeView()
                Text("Pitlog calculates inspection deadlines from the first registration and the date on your inspection sticker. Some rules of the 2027 inspection reform are still legally open. In doubt the app shows the earlier deadline. It does not replace the sticker, the registration certificate or advice from an inspection station.", comment: "Legal screen: full disclaimer")
            }

            Section {
                // Plain texts in the primary color: LabeledContent values are secondary and fail the contrast audit.
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rule version", comment: "Legal screen: label for the version of the rule set")
                    Text(verbatim: AustriaInspectionRules.ruleVersion)
                }
                .accessibilityElement(children: .combine)
            }

            Section {
                heading(Text("Official sources", comment: "Legal screen: section header for the list of legal sources"))
                // Static references, no network calls (privacy: CloudKit only).
                Text(verbatim: "§ 57a KFG 1967")
                Text(verbatim: "§ 132 Abs. 37 KFG")
                Text(verbatim: "§ 135 Abs. 51 KFG")
                Text(verbatim: "BGBl. I Nr. 79/2026 (42. KFG-Novelle)")
                Text("You can look these provisions up in the Austrian Legal Information System (RIS).", comment: "Legal screen: hint where to find the sources, no link on purpose")
                    .font(.footnote)
            }
        }
        .navigationTitle(Text("Legal", comment: "Navigation title of the legal screen"))
        .navigationBarTitleDisplayMode(.inline)
        // Pushed from Settings: hide the floating tab bar so it never overlaps the last rows.
        .toolbar(.hidden, for: .tabBar)
    }

    /// In-row heading in the primary color: system section headers are secondary and fail the contrast audit.
    private func heading(_ title: Text) -> some View {
        title
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
    }
}
