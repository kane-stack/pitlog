import PitlogCore
import SwiftData
import SwiftUI

struct VehicleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.entitlements) private var entitlements
    // Archived vehicles do not count against the limit and are never deleted by it (ADR-11).
    @Query(filter: #Predicate<Vehicle> { !$0.isArchived }, sort: \Vehicle.createdAt)
    private var vehicles: [Vehicle]

    @State private var showingForm = false
    @State private var showingLimitAlert = false
    @State private var vehicleToDelete: Vehicle?

    private let service = InspectionService()

    var body: some View {
        let today = CalendarDay.today(in: CalendarDay.austria)
        List {
            ForEach(vehicles) { vehicle in
                NavigationLink(value: vehicle) {
                    VehicleRow(vehicle: vehicle, outcome: service.evaluate(vehicle, today: today), today: today)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        vehicleToDelete = vehicle
                    } label: {
                        Label {
                            Text("Delete", comment: "Swipe action to delete a vehicle")
                        } icon: {
                            Image(systemName: "trash")
                        }
                    }
                    Button {
                        vehicle.isArchived = true
                    } label: {
                        Label {
                            Text("Archive", comment: "Swipe action to archive a vehicle")
                        } icon: {
                            Image(systemName: "archivebox")
                        }
                    }
                    .tint(.indigo)
                }
            }
        }
        .overlay {
            if vehicles.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("No vehicles", comment: "Empty state title on the Vehicles tab")
                    } icon: {
                        Image(systemName: "car")
                    }
                } description: {
                    Text(
                        "Add a vehicle to keep track of inspections, service and costs.",
                        comment: "Empty state description on the Vehicles tab"
                    )
                }
            }
        }
        .navigationTitle(Text("Vehicles", comment: "Navigation title of the Vehicles tab"))
        .navigationDestination(for: Vehicle.self) { vehicle in
            VehicleDetailView(vehicle: vehicle)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if entitlements.canAddVehicle(currentCount: vehicles.count) {
                        showingForm = true
                    } else {
                        showingLimitAlert = true
                    }
                } label: {
                    Label {
                        Text("Add vehicle", comment: "Toolbar button to add a vehicle")
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            VehicleFormView(vehicle: nil)
        }
        .alert(
            Text("Vehicle limit reached", comment: "Alert title when the entitlement allows no more vehicles"),
            isPresented: $showingLimitAlert
        ) {
            Button(role: .cancel) {} label: {
                Text("OK", comment: "Alert dismiss button")
            }
        } message: {
            Text("Your vehicles stay available. You can view them, but not add more.", comment: "Alert message when the vehicle limit is reached")
        }
        .confirmationDialog(
            Text("Delete this vehicle?", comment: "Confirmation title for deleting a vehicle"),
            isPresented: Binding(
                get: { vehicleToDelete != nil },
                set: { if !$0 { vehicleToDelete = nil } }),
            titleVisibility: .visible,
            presenting: vehicleToDelete
        ) { vehicle in
            Button(role: .destructive) {
                modelContext.delete(vehicle)
                vehicleToDelete = nil
            } label: {
                Text("Delete", comment: "Confirm deleting a vehicle")
            }
        } message: { _ in
            Text("The vehicle and its odometer readings will be deleted. This cannot be undone.", comment: "Confirmation message for deleting a vehicle")
        }
    }
}

#Preview {
    NavigationStack { VehicleListView() }
        .modelContainer(PreviewData.container())
}
