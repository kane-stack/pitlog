import SwiftUI
import UIKit

struct VehicleThumbnail: View {
    let vehicle: Vehicle
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let data = vehicle.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: vehicle.category.symbolName)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.secondarySystemFill))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
    }
}
