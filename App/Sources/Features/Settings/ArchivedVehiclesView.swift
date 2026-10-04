import SwiftData
import SwiftUI

/// Archived vehicles stay in the store; here they can be restored or deleted.
struct ArchivedVehiclesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Vehicle> { $0.isArchived }, sort: \Vehicle.createdAt)
    private var vehicles: [Vehicle]
    @State private var vehicleToDelete: Vehicle?

    var body: some View {
        List {
            ForEach(vehicles) { vehicle in
                HStack {
                    VehicleThumbnail(vehicle: vehicle, size: 40)
                    Text(vehicle.displayName)
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
                        vehicle.isArchived = false
                    } label: {
                        Label {
                            Text("Restore", comment: "Swipe action to restore an archived vehicle")
                        } icon: {
                            Image(systemName: "arrow.uturn.backward")
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
                        Text("No archived vehicles", comment: "Empty state title of the archived vehicles screen")
                    } icon: {
                        Image(systemName: "archivebox")
                    }
                }
            }
        }
        .navigationTitle(Text("Archived vehicles", comment: "Navigation title of the archived vehicles screen"))
        .navigationBarTitleDisplayMode(.inline)
        // Pushed from Settings: hide the floating tab bar so it never overlaps the last rows.
        .toolbar(.hidden, for: .tabBar)
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
