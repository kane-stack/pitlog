import PitlogCore
import SwiftUI

/// Which locked feature the user wanted when the paywall opened. The paywall highlights it.
enum PaywallContext: String, Identifiable, Hashable {
    case general
    case vehicles
    case reminders
    case receiptScan
    case costs
    case serviceRecordExport

    var id: String { rawValue }

    var feature: ProFeature? {
        switch self {
        case .general: nil
        case .vehicles: .moreVehicles
        case .reminders: .proReminders
        case .receiptScan: .receiptScan
        case .costs: .multiYearCosts
        case .serviceRecordExport: .serviceRecordExport
        }
    }
}

extension View {
    /// Presents the paywall as a sheet while `context` is set.
    func paywall(_ context: Binding<PaywallContext?>) -> some View {
        sheet(item: context) { PaywallView(context: $0) }
    }
}
