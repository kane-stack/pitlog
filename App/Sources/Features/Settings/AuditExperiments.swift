import SwiftUI

/// TEMPORARY: isolates which constructs the Dynamic Type audit flags. Removed before merge.
struct AuditExperiments: View {
    let number: Int
    @State private var on = true
    @State private var value = 14
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Group {
                switch number {
                case 1:
                    List { ForEach(1...6, id: \.self) { Text("Plain row \($0)") } }
                case 2:
                    List {
                        Toggle(isOn: $on) { Text("First toggle") }
                        Toggle(isOn: $on) { Text("Second toggle") }
                        Text("A note below the toggles")
                    }
                case 3:
                    List {
                        LeadPicker(title: Text("Picker one"), value: $value, options: LeadOptions.days, valueText: LeadOptions.days)
                        LeadPicker(title: Text("Picker two"), value: $value, options: LeadOptions.days, valueText: LeadOptions.days)
                        Text("A note below the pickers")
                    }
                case 4:
                    Form {
                        DatePicker(selection: $date, displayedComponents: .date) { Text("A date") }
                        Text("A note below the date")
                        Text("Another note")
                    }
                case 5:
                    List {
                        Button { } label: { Label { Text("First button") } icon: { Image(systemName: "bell") } }
                        Button { } label: { Label { Text("Second button") } icon: { Image(systemName: "bell") } }
                        Text("A note below the buttons")
                    }
                default:
                    Form {
                        Section {
                            Toggle(isOn: $on) { Text("On") }
                            DatePicker(selection: $date, displayedComponents: .date) { Text("A date") }
                            Text("A note").font(.footnote)
                        }
                        Section {
                            LeadPicker(title: Text("Picker"), value: $value, options: LeadOptions.days, valueText: LeadOptions.days)
                            Text("A second note").font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle(Text(verbatim: "Experiment \(number)"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
