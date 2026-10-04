import PitlogCore
import SwiftData
import SwiftUI

struct VehicleDetailView: View {
    let vehicle: Vehicle

    @Environment(\.locale) private var locale
    @State private var showingEdit = false
    @State private var showingOdometer = false
    @State private var showingRecordInspection = false

    private let service = InspectionService()

    var body: some View {
        let today = CalendarDay.today(in: CalendarDay.austria)
        let outcome = service.evaluate(vehicle, today: today)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                InspectionCardView(vehicle: vehicle, outcome: outcome, today: today) {
                    showingRecordInspection = true
                }
            }
            .padding()
        }
        .navigationTitle(vehicle.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEdit = true
                } label: {
                    Text("Edit", comment: "Toolbar button to edit a vehicle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) { VehicleFormView(vehicle: vehicle) }
        .sheet(isPresented: $showingOdometer) { OdometerEntryView(vehicle: vehicle) }
        .sheet(isPresented: $showingRecordInspection) {
            RecordInspectionView(vehicle: vehicle)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            VehicleThumbnail(vehicle: vehicle, size: 88)
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                if !vehicle.name.isEmpty, !vehicle.licensePlate.isEmpty {
                    Text(vehicle.licensePlate)
                        .foregroundStyle(.secondary)
                }
                Button {
                    showingOdometer = true
                } label: {
                    if let km = vehicle.currentOdometerKm {
                        Label {
                            Text("\(km.formatted(.number)) km", comment: "Odometer value with unit, shown in the vehicle header")
                        } icon: {
                            Image(systemName: "gauge.with.dots.needle.50percent")
                        }
                    } else {
                        Label {
                            Text("Add odometer reading", comment: "Button in the vehicle header when no odometer reading exists")
                        } icon: {
                            Image(systemName: "gauge.with.dots.needle.50percent")
                        }
                    }
                }
                .accessibilityHint(Text("Adds an odometer reading.", comment: "VoiceOver hint of the odometer button"))
            }
        }
    }
}

#Preview {
    let container = PreviewData.container()
    let vehicle = (try? container.mainContext.fetch(FetchDescriptor<Vehicle>()))?.first
    return NavigationStack {
        if let vehicle { VehicleDetailView(vehicle: vehicle) }
    }
    .modelContainer(container)
}
