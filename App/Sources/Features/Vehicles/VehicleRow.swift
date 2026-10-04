import PitlogCore
import SwiftUI

struct VehicleRow: View {
    let vehicle: Vehicle
    let outcome: InspectionService.Outcome
    let today: DayDate

    var body: some View {
        HStack(spacing: 12) {
            VehicleThumbnail(vehicle: vehicle)
            VStack(alignment: .leading, spacing: 2) {
                Text(vehicle.displayName)
                    .font(.headline)
                if !vehicle.name.isEmpty, !vehicle.licensePlate.isEmpty {
                    Text(vehicle.licensePlate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                InspectionBadge(outcome: outcome, today: today)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
