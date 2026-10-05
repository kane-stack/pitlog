import PitlogCore
import SwiftData
import SwiftUI

struct VehicleDetailView: View {
    let vehicle: Vehicle

    @Environment(\.locale) private var locale
    @Environment(\.entitlements) private var entitlements
    @Query(filter: #Predicate<Vehicle> { !$0.isArchived }, sort: \Vehicle.createdAt)
    private var activeVehicles: [Vehicle]
    @State private var paywall: PaywallContext?
    @State private var showingEdit = false
    @State private var showingOdometer = false
    @State private var showingRecordInspection = false
    /// Set by "Record inspection": after the sheet closed the user is asked whether to log it in the history.
    @State private var historyOffer: EntryPrefill?
    @State private var showingHistoryOffer = false
    @State private var historyEditor: EntryEditorTarget?

    private let service = InspectionService()

    /// Over the free limit (ADR-11): everything is readable, changes lead to the paywall.
    private var isReadOnly: Bool { entitlements.isReadOnly(vehicle, among: activeVehicles) }

    /// Runs `change` for an editable vehicle, shows the paywall for a read-only one.
    private func edit(_ change: () -> Void) {
        if isReadOnly { paywall = .vehicles } else { change() }
    }

    var body: some View {
        let today = CalendarDay.today(in: CalendarDay.austria)
        let outcome = service.evaluate(vehicle, today: today)
        List {
            header
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            if isReadOnly {
                ReadOnlyBanner { paywall = .vehicles }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
            }
            InspectionCardView(vehicle: vehicle, outcome: outcome, today: today) {
                edit { showingRecordInspection = true }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            RemindersSummaryRow(vehicle: vehicle, today: CalendarDay.today(in: .current))
            HistorySummaryRow(vehicle: vehicle)
        }
        .listStyle(.plain)
        // Hide the floating tab bar so it never overlaps the last rows (as in About).
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(vehicle.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    edit { showingEdit = true }
                } label: {
                    Text("Edit", comment: "Toolbar button to edit a vehicle")
                }
            }
        }
        .paywall($paywall)
        .sheet(isPresented: $showingEdit) { VehicleFormView(vehicle: vehicle) }
        .sheet(isPresented: $showingOdometer) { OdometerEntryView(vehicle: vehicle) }
        .sheet(isPresented: $showingRecordInspection, onDismiss: {
            if historyOffer != nil { showingHistoryOffer = true }
        }) {
            RecordInspectionView(vehicle: vehicle) { day in
                historyOffer = EntryPrefill(category: .inspection, date: day, km: vehicle.currentOdometerKm)
            }
        }
        .historyOfferAlert(
            isPresented: $showingHistoryOffer, offer: $historyOffer, editor: $historyEditor,
            message: Text("Log the inspection in the history of this vehicle, for example with the fee you paid.", comment: "Alert after recording an inspection: offer to add it to the history"))
        .sheet(item: $historyEditor) { target in
            EntryEditorView(vehicle: vehicle, entry: target.entry, prefill: target.prefill)
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
                }
                Button {
                    edit { showingOdometer = true }
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
                .buttonStyle(.borderless)
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
    .environment(NotificationPermission(center: SystemNotificationCenter()))
}
