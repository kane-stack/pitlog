import PitlogCore
import SwiftUI

/// Sets the inspection sticker month of a vehicle, prefilled with the month a § 57a receipt names. The sticker
/// itself is authoritative (ADR-5): the month is only saved when the user confirms it here.
struct PlaqueUpdateView: View {
    let vehicle: Vehicle
    let suggestion: YearMonth

    @Environment(\.dismiss) private var dismiss
    @State private var plaque: YearMonth?

    init(vehicle: Vehicle, suggestion: YearMonth) {
        self.vehicle = vehicle
        self.suggestion = suggestion
        _plaque = State(initialValue: suggestion)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Check the month against the punch on your inspection sticker before you save.", comment: "Sticker update from a receipt: reminds the user that the sticker is authoritative")
                        .fixedSize(horizontal: false, vertical: true)
                }
                Section {
                    PlaquePicker(plaque: $plaque)
                }
            }
            .navigationTitle(Text("Inspection sticker", comment: "VoiceOver label of the inspection sticker picker"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Cancel button of a form")
                    }
                    .accessibilityIdentifier("plaqueUpdateCancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        vehicle.plaque = plaque
                        dismiss()
                    } label: {
                        Text("Save", comment: "Save button of a form")
                    }
                    .disabled(plaque == nil)
                    .accessibilityIdentifier("plaqueUpdateSaveButton")
                }
            }
        }
    }
}
