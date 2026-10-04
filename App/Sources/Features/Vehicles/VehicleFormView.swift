import PhotosUI
import PitlogCore
import SwiftData
import SwiftUI
import UIKit

/// Add and edit form in one sheet. Edits are applied to the vehicle only on "Save".
struct VehicleFormView: View {
    /// `nil` creates a new vehicle.
    let vehicle: Vehicle?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

    @State private var name = ""
    @State private var licensePlate = ""
    @State private var category: VehicleCategory = .passengerCar
    @State private var make = ""
    @State private var model = ""
    @State private var vin = ""
    @State private var firstRegistrationMonth: Int?
    @State private var firstRegistrationYear: Int?
    @State private var plaque: YearMonth?
    @State private var kilometers: Int?
    @State private var photo: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var loaded = false

    private let service = InspectionService()
    private let today = CalendarDay.today(in: CalendarDay.austria)

    private var firstRegistration: YearMonth? {
        guard let firstRegistrationYear, let firstRegistrationMonth else { return nil }
        return YearMonth(year: firstRegistrationYear, month: firstRegistrationMonth)
    }

    private var suggestion: YearMonth? {
        service.estimatedDueMonth(
            countryCode: vehicle?.countryCode ?? "AT",
            category: category,
            firstRegistration: firstRegistration,
            today: today)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            || !licensePlate.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    FormTextField(title: Text("Name", comment: "Vehicle form: name field"), text: $name)
                    FormTextField(title: Text("License plate", comment: "Vehicle form: license plate field"), text: $licensePlate)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    Menu {
                        Picker(selection: $category) {
                            ForEach(VehicleCategory.allCases, id: \.self) { category in
                                Text(category.title).tag(category)
                            }
                        } label: {
                            Text("Type", comment: "Vehicle form: vehicle category picker")
                        }
                    } label: {
                        // Explicit colors and wrapping text: the system picker value is secondary (contrast)
                        // and truncates at large Dynamic Type sizes.
                        HStack(alignment: .firstTextBaseline) {
                            Text("Type", comment: "Vehicle form: vehicle category picker")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(category.title)
                                .foregroundStyle(Color.accentColor)
                                .multilineTextAlignment(.trailing)
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundStyle(Color.accentColor)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Type", comment: "Vehicle form: vehicle category picker"))
                    .accessibilityValue(Text(category.title))
                    .accessibilityAddTraits(.isButton)
                }

                Section {
                    FormTextField(title: Text("Make", comment: "Vehicle form: make field"), text: $make)
                    FormTextField(title: Text("Model", comment: "Vehicle form: model field"), text: $model)
                    FormTextField(title: Text("VIN (optional)", comment: "Vehicle form: vehicle identification number field"), text: $vin)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: vin) { _, newValue in
                        let upper = newValue.uppercased()
                        if upper != newValue { vin = upper }
                    }
                } footer: {
                    if !vin.isEmpty, vin.count != 17 {
                        Text("A VIN has 17 characters.", comment: "Vehicle form: hint when the VIN length is not 17")
                    }
                }

                Section {
                    Picker(selection: $firstRegistrationMonth) {
                        Text("Not set", comment: "Picker option for no month").tag(Int?.none)
                        ForEach(1...12, id: \.self) { month in
                            Text(YearMonth.monthName(month, locale: locale)).tag(Int?.some(month))
                        }
                    } label: {
                        Text("First registration, month", comment: "Vehicle form: month of the first registration")
                    }
                    Picker(selection: $firstRegistrationYear) {
                        Text("Not set", comment: "Picker option for no year").tag(Int?.none)
                        ForEach((1950...today.year).reversed(), id: \.self) { year in
                            Text(year, format: .number.grouping(.never)).tag(Int?.some(year))
                        }
                    } label: {
                        Text("First registration, year", comment: "Vehicle form: year of the first registration")
                    }
                    FormNumberField(title: Text("Odometer (km)", comment: "Vehicle form: current odometer in kilometres"), value: $kilometers)
                }

                Section {
                    Text("Inspection sticker", comment: "Vehicle form: section header for the inspection sticker")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text("Enter the month and year punched on your inspection sticker.", comment: "Vehicle form: explanation of the inspection sticker picker")
                        .font(.footnote)
                    PlaquePicker(plaque: $plaque, suggestion: suggestion, today: today)
                }

                Section {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label {
                            Text(photo == nil ? "Choose photo" : "Change photo", comment: "Vehicle form: button to pick a photo")
                        } icon: {
                            Image(systemName: "photo")
                        }
                    }
                    if let photo, let image = UIImage(data: photo) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                            .accessibilityHidden(true)
                        Button(role: .destructive) {
                            self.photo = nil
                            photoItem = nil
                        } label: {
                            Text("Remove photo", comment: "Vehicle form: button to remove the photo")
                        }
                    }
                } header: {
                    Text("Photo", comment: "Vehicle form: section header for the photo")
                }
            }
            .navigationTitle(
                vehicle == nil
                    ? Text("New vehicle", comment: "Navigation title of the add vehicle form")
                    : Text("Edit vehicle", comment: "Navigation title of the edit vehicle form")
            )
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
                        save()
                    } label: {
                        Text("Save", comment: "Save button of a form")
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                    photo = PhotoDownscaler.jpegData(from: data)
                }
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let vehicle else { return }
        name = vehicle.name
        licensePlate = vehicle.licensePlate
        category = vehicle.category
        make = vehicle.make ?? ""
        model = vehicle.model ?? ""
        vin = vehicle.vin ?? ""
        firstRegistrationMonth = vehicle.firstRegistrationMonth
        firstRegistrationYear = vehicle.firstRegistrationYear
        plaque = vehicle.plaque
        kilometers = vehicle.currentOdometerKm
        photo = vehicle.photo
    }

    private func save() {
        let target = vehicle ?? Vehicle()
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.licensePlate = licensePlate.trimmingCharacters(in: .whitespaces).uppercased()
        target.category = category
        target.make = make.isEmpty ? nil : make
        target.model = model.isEmpty ? nil : model
        target.vin = vin.isEmpty ? nil : vin
        target.firstRegistration = firstRegistration
        target.plaque = plaque
        target.photo = photo
        if vehicle == nil { modelContext.insert(target) }
        if let kilometers, kilometers != target.currentOdometerKm {
            modelContext.insert(OdometerReading(date: Date(), kilometers: kilometers, vehicle: target))
        }
        dismiss()
    }
}

#Preview {
    VehicleFormView(vehicle: nil)
        .modelContainer(PreviewData.container(withSamples: false))
}
