import PitlogCore
import SwiftUI

struct VehicleRow: View {
    let vehicle: Vehicle
    let outcome: InspectionService.Outcome
    let today: DayDate
    /// Over the free limit: readable, not editable (ADR-11).
    var isReadOnly = false

    var body: some View {
        HStack(spacing: 12) {
            VehicleThumbnail(vehicle: vehicle)
            VStack(alignment: .leading, spacing: 2) {
                Text(vehicle.displayName)
                    .font(.headline)
                if !vehicle.name.isEmpty, !vehicle.licensePlate.isEmpty {
                    Text(vehicle.licensePlate)
                        .font(.subheadline)
                }
                InspectionBadge(outcome: outcome, today: today)
                if isReadOnly {
                    Label {
                        Text("Read only", comment: "Marks a vehicle that is over the free limit and cannot be edited")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "lock.fill")
                    }
                    .font(.footnote)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
