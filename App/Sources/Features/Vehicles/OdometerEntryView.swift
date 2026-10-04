import SwiftData
import SwiftUI

struct OdometerEntryView: View {
    let vehicle: Vehicle

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date = Date()
    @State private var kilometers: Int?

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(selection: $date, in: ...Date(), displayedComponents: .date) {
                    Text("Date", comment: "Odometer entry: date of the reading")
                }
                TextField(value: $kilometers, format: .number) {
                    Text("Odometer (km)", comment: "Odometer entry: kilometres")
                }
                .keyboardType(.numberPad)
            }
            .navigationTitle(Text("Odometer reading", comment: "Navigation title of the odometer entry sheet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Cancel button of a form")
                    }
                    .accessibilityIdentifier("cancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if let kilometers {
                            modelContext.insert(OdometerReading(date: date, kilometers: kilometers, vehicle: vehicle))
                        }
                        dismiss()
                    } label: {
                        Text("Save", comment: "Save button of a form")
                    }
                    .disabled((kilometers ?? -1) < 0)
                }
            }
            .onAppear { kilometers = vehicle.currentOdometerKm }
        }
        .presentationDetents([.medium])
    }
}
