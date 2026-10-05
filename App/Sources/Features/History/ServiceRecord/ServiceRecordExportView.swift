import PitlogCore
import SwiftUI

/// The sheet before the export: what the record should contain. "Create" renders the PDF on a background task
/// and pushes the preview, where the user can share it. Nothing is stored and nothing leaves the device until
/// the user shares the file.
struct ServiceRecordExportView: View {
    let vehicle: Vehicle

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var usesStartDate = false
    @State private var startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @State private var includeAmounts = false
    @State private var includeVIN = true
    @State private var includeReceipts = false
    @State private var isCreating = false
    @State private var exported: ExportedServiceRecord?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                introSection
                periodSection
                contentSection
                if isCreating {
                    Section {
                        ProgressView {
                            Text("Creating the PDF…", comment: "Service record export: shown while the PDF is being created")
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("serviceRecordProgress")
                    }
                }
            }
            .navigationTitle(Text("Service record", comment: "Title of the service record PDF and of its export screens. Also the start of the file name"))
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
                        create()
                    } label: {
                        Text("Create", comment: "Service record export: button that creates the PDF and opens the preview")
                    }
                    .disabled(isCreating)
                    .accessibilityIdentifier("createServiceRecordButton")
                }
            }
            .navigationDestination(item: $exported) { file in
                ServiceRecordPreviewView(file: file)
            }
            .alert(
                Text("The PDF could not be created.", comment: "Service record export: alert title when the PDF cannot be created"),
                isPresented: $failed
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Button that dismisses an alert")
                }
            } message: {
                Text("Try again. If it keeps failing, leave out the receipts.", comment: "Service record export: alert message when the PDF cannot be created")
            }
        }
    }

    // MARK: Sections

    private var introSection: some View {
        Section {
            Text(
                "Creates a PDF of the history of this vehicle, for example for selling it. The PDF is created on your device. It leaves your device only when you share it.",
                comment: "Service record export: explains what the PDF is and that it is created on the device"
            )
            .font(.subheadline)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var periodSection: some View {
        Section {
            MenuPickerRow(
                title: Text("Period", comment: "Service record export: which entries to include"),
                valueText: usesStartDate
                    ? Text("Since a date", comment: "Service record export: period value, entries from a chosen date on")
                    : Text("All entries", comment: "Service record export: period value, every entry"),
                selection: $usesStartDate
            ) {
                Text("All entries", comment: "Service record export: period value, every entry").tag(false)
                Text("Since a date", comment: "Service record export: period value, entries from a chosen date on").tag(true)
            }
            .accessibilityIdentifier("serviceRecordPeriod")
            if usesStartDate {
                DatePicker(selection: $startDate, in: ...Date(), displayedComponents: .date) {
                    Text("From", comment: "Service record export: first day of the period")
                }
                .accessibilityIdentifier("serviceRecordStartDate")
            }
        }
    }

    private var contentSection: some View {
        Section {
            Toggle(isOn: $includeAmounts) {
                Text("Include amounts", comment: "Service record export: switch to show the costs of the entries and the sums")
            }
            .accessibilityIdentifier("serviceRecordAmounts")
            note(Text("Shows the cost of each entry and the sums per year.", comment: "Service record export: explains the amounts switch"))

            Toggle(isOn: $includeVIN) {
                Text("Include VIN", comment: "Service record export: switch to show the vehicle identification number")
            }
            .accessibilityIdentifier("serviceRecordVIN")
            note(Text("Buyers can check the VIN against the vehicle.", comment: "Service record export: explains the VIN switch"))

            Toggle(isOn: $includeReceipts) {
                Text("Attach receipts", comment: "Service record export: switch to append the receipt images at the end of the PDF")
            }
            .accessibilityIdentifier("serviceRecordReceipts")
            note(Text("Receipts can contain your name and address. Pitlog does not black anything out. The PDF gets larger.", comment: "Service record export: privacy warning for the receipts switch"))
        }
    }

    private func note(_ text: Text) -> some View {
        text
            .font(.footnote)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Create

    private func create() {
        guard !isCreating else { return }
        isCreating = true
        let period: ServiceRecordPeriod = usesStartDate
            ? .since(CalendarDay.dayDate(from: startDate, in: .current)) : .all
        let options = ServiceRecordOptions(
            period: period, includeAmounts: includeAmounts, includeVIN: includeVIN,
            includeReceiptAttachments: includeReceipts)
        let prepared = ServiceRecordFactory.prepare(
            vehicle: vehicle, options: options, today: CalendarDay.today(in: .current))
        let locale = self.locale
        Task {
            do {
                exported = try await ServiceRecordExporter.export(prepared, locale: locale)
            } catch {
                failed = true
            }
            isCreating = false
        }
    }
}
