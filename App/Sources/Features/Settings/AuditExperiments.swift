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
                case 7:
                    Color.clear.sheet(isPresented: .constant(true)) {
                        NavigationStack {
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
                            .navigationTitle(Text(verbatim: "Sheet"))
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) { Button { } label: { Text("Cancel") } }
                                ToolbarItem(placement: .confirmationAction) { Button { } label: { Text("Save") } }
                            }
                        }
                    }
                case 8:
                    List {
                        Button { } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "bell").accessibilityHidden(true)
                                Text("First button").fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        Button { } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "bell").accessibilityHidden(true)
                                Text("Second button").fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        Text("A note below the buttons")
                    }
                case 9:
                    List {
                        ForEach(1...8, id: \.self) { index in
                            NavigationLink {
                                Text("Detail")
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Label { Text("Row \(index)") } icon: { Image(systemName: "bell") }.font(.headline)
                                    Text(verbatim: "Subtitle \(index) · in 27 days").font(.subheadline)
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(Text(verbatim: "Row \(index). Subtitle"))
                            }
                        }
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
