import PitlogCore
import SwiftUI

/// Record a completed inspection: pick the date, let the engine compute the next due month, and
/// make the user confirm the new sticker. The sticker is authoritative (ADR-5), so the result is
/// only a prefilled proposal.
struct RecordInspectionView: View {
    let vehicle: Vehicle

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var date = Date()
    @State private var proposal: NextInspectionDue?
    @State private var failure: InspectionService.UnavailableReason?
    @State private var plaque: YearMonth?

    private let service = InspectionService()

    private var inspectionDay: DayDate { CalendarDay.dayDate(from: date, in: CalendarDay.austria) }
    private var hasOutsideWindowNote: Bool {
        proposal?.notes.contains { $0.ruleID == "AT-12" } ?? false
    }

    var body: some View {
        NavigationStack {
            Form {
                if let proposal {
                    confirmation(proposal)
                } else {
                    dateStep
                }
            }
            .navigationTitle(Text("Record inspection", comment: "Navigation title of the record inspection sheet"))
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
                    if proposal == nil {
                        Button(action: calculate) {
                            Text("Continue", comment: "Button to continue to the next step")
                        }
                        .accessibilityIdentifier("continueButton")
                    } else {
                        Button(action: save) {
                            Text("Save", comment: "Save button of a form")
                        }
                        .disabled(plaque == nil)
                    }
                }
            }
        }
    }

    private var dateStep: some View {
        Section {
            DatePicker(selection: $date, in: ...Date(), displayedComponents: .date) {
                Text("Inspection date", comment: "Record inspection: date of the inspection")
            }
            .environment(\.timeZone, CalendarDay.austria)
            if let failure {
                Label(failure.text(locale: locale), systemImage: "exclamationmark.triangle")
            }
        } footer: {
            Text("The date on which the vehicle passed the inspection.", comment: "Record inspection: explanation of the date field")
        }
    }

    @ViewBuilder
    private func confirmation(_ proposal: NextInspectionDue) -> some View {
        Section {
            if hasOutsideWindowNote {
                Label {
                    Text("Inspected outside the window: enter the punch exactly as it appears on your new inspection sticker.", comment: "Record inspection: emphasised warning for a late inspection (AT-12)")
                        .fontWeight(.bold)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
            }
            PlaquePicker(plaque: $plaque)
        } header: {
            Text("New inspection sticker", comment: "Record inspection: section header for the confirmation step")
        } footer: {
            Text("Check the new sticker and adjust if needed.", comment: "Record inspection: ask the user to verify the proposal against the sticker")
        }
        let others = proposal.notes.filter { $0.ruleID != "AT-12" }
        if !others.isEmpty {
            Section {
                ForEach(Array(others.enumerated()), id: \.offset) { _, note in
                    Label(RuleNoteText.text(for: note, locale: locale), systemImage: "info.circle")
                }
            }
        }
        Section {
            LegalNoticeView()
        }
    }

    private func calculate() {
        let today = CalendarDay.today(in: CalendarDay.austria)
        switch service.nextDue(for: vehicle, inspectedOn: inspectionDay, today: today) {
        case .success(let result):
            failure = nil
            proposal = result
            plaque = result.dueMonth
        case .failure(let reason):
            failure = reason
        }
    }

    private func save() {
        vehicle.plaque = plaque
        vehicle.lastInspection = inspectionDay
        dismiss()
    }
}
