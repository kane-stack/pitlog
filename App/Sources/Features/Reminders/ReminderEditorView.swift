import PitlogCore
import SwiftData
import SwiftUI

/// Add and edit form for one reminder. It adapts to the category; tyre and vignette are prefilled from the
/// country defaults. Edits are applied to the reminder only on "Save".
struct ReminderEditorView: View {
    let vehicle: Vehicle
    let category: ReminderCategory
    /// `nil` creates a new reminder.
    let reminder: Reminder?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(NotificationPermission.self) private var permission

    @State private var title = ""
    @State private var isEnabled = true
    @State private var date = Date()
    @State private var hasDate = true
    @State private var hasKm = false
    @State private var kilometers: Int?
    @State private var leadDays = 14
    @State private var leadKm = ReminderSettings.Defaults.serviceLeadKm
    @State private var repeatRule: ReminderRepeatRule = .none
    @State private var repeatMonths = 12
    @State private var repeatMonthsEnabled = false
    @State private var repeatKmEnabled = false
    @State private var repeatKm = 15_000
    @State private var note = ""
    @State private var loaded = false
    @State private var showingPermissionPrompt = false

    private let builder = ReminderScheduleBuilder()
    private let today = CalendarDay.today(in: .current)

    private var isService: Bool { category == .service }
    private var isCustom: Bool { category == .custom }
    private var hasTitleField: Bool { isService || isCustom }

    private var canSave: Bool {
        if isCustom { return !title.trimmingCharacters(in: .whitespaces).isEmpty }
        if isService { return hasDate || (hasKm && (kilometers ?? 0) > 0) }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                basics
                dueSection
                leadSection
                repeatSection
                Section {
                    TextField(text: $note, axis: .vertical) {
                        Text("Note", comment: "Reminder editor: optional note")
                    }
                    .accessibilityLabel(Text("Note", comment: "Reminder editor: optional note"))
                }
            }
            .navigationTitle(navigationTitle)
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
                        save()
                    } label: {
                        Text("Save", comment: "Save button of a form")
                    }
                    .disabled(!canSave)
                    .accessibilityIdentifier("saveReminderButton")
                }
            }
            .onAppear(perform: load)
            .notificationPermissionPrompt(isPresented: $showingPermissionPrompt) { dismiss() }
        }
    }

    private var navigationTitle: Text {
        reminder == nil
            ? Text("New reminder", comment: "Navigation title of the add reminder form")
            : Text("Edit reminder", comment: "Navigation title of the edit reminder form")
    }

    // MARK: Sections

    private var basics: some View {
        Section {
            if hasTitleField {
                FormTextField(
                    title: Text("Title", comment: "Reminder editor: title of the reminder"), text: $title)
            } else {
                LabeledContent {
                    Text(category.title(locale: locale))
                } label: {
                    Text("Type", comment: "Reminder editor: the kind of reminder")
                }
            }
            Toggle(isOn: $isEnabled) {
                Text("Reminder on", comment: "Reminder editor: switch the reminder on or off")
            }
        }
    }

    @ViewBuilder
    private var dueSection: some View {
        Section {
            if isService {
                Toggle(isOn: $hasDate) {
                    Text("By date", comment: "Service reminder: remind at a date")
                }
                if hasDate { datePicker }
                Toggle(isOn: $hasKm) {
                    Text("By odometer", comment: "Service reminder: remind at an odometer value")
                }
                if hasKm {
                    FormNumberField(
                        title: Text("Service at (km)", comment: "Service reminder: odometer value of the next service"),
                        value: $kilometers)
                }
            } else {
                datePicker
            }
        } footer: {
            dueFooter
        }
    }

    private var datePicker: some View {
        DatePicker(selection: $date, displayedComponents: .date) {
            dateLabel
        }
    }

    private var dateLabel: Text {
        switch category {
        case .tyreWinter:
            Text("Winter period starts", comment: "Tyre reminder editor: date the winter tyre period starts")
        case .tyreSummer:
            Text("Winter period ends", comment: "Tyre reminder editor: date the winter tyre period ends")
        case .vignette:
            Text("Valid until", comment: "Vignette reminder editor: last day of validity")
        case .service, .custom:
            Text("Date", comment: "Reminder editor: date of the reminder")
        }
    }

    @ViewBuilder
    private var dueFooter: some View {
        let defaults = builder.defaults(for: vehicle)
        switch category {
        case .tyreWinter, .tyreSummer:
            let start = defaults.tyreChangeDay(for: .winter).displayString(locale: locale)
            let end = defaults.tyreChangeDay(for: .summer).displayString(locale: locale)
            Text(
                "Default for Austria: winter tyre period from \(start) to \(end), relevant in wintry road conditions (§ 102 Abs. 8a KFG). You can change the date. Without guarantee.",
                comment: "Tyre reminder editor footer. Arguments: start and end of the winter tyre period as day and month")
        case .vignette:
            if let vignette = defaults.vignette {
                let new = vignette.newVignetteAvailable.displayString(locale: locale)
                Text(
                    "You get a reminder on \(new) when the new vignette is available, and before the old one expires. A vignette bought online may only be valid from the 18th day after purchase.",
                    comment: "Vignette reminder editor footer. Argument: day and month the new vignette is available")
            }
        case .service:
            Text(
                "Dates for kilometres are estimated from your odometer readings. Add readings regularly.",
                comment: "Service reminder editor footer: the odometer based date is an estimate")
        case .custom:
            EmptyView()
        }
    }

    private var leadSection: some View {
        Section {
            Stepper(value: $leadDays, in: 0...365) {
                Text("Remind \(leadDays) days before", comment: "Reminder editor: lead time in days, plural")
            }
            if isService, hasKm {
                Stepper(value: $leadKm, in: 0...5_000, step: 100) {
                    Text("Remind \(leadKm) km before", comment: "Service reminder editor: lead distance in kilometres")
                }
            }
        }
    }

    @ViewBuilder
    private var repeatSection: some View {
        if isService {
            Section {
                Toggle(isOn: $repeatMonthsEnabled) {
                    Text("Repeat by time", comment: "Service reminder editor: repeat after a number of months")
                }
                if repeatMonthsEnabled {
                    Stepper(value: $repeatMonths, in: 1...120) {
                        Text("Every \(repeatMonths) months", comment: "Service reminder editor: repeat interval in months, plural")
                    }
                }
                Toggle(isOn: $repeatKmEnabled) {
                    Text("Repeat by distance", comment: "Service reminder editor: repeat after a number of kilometres")
                }
                if repeatKmEnabled {
                    Stepper(value: $repeatKm, in: 1_000...100_000, step: 1_000) {
                        Text("Every \(repeatKm) km", comment: "Service reminder editor: repeat interval in kilometres")
                    }
                }
            } footer: {
                Text(
                    "When you mark the service as done, the next one counts from that day and the current odometer reading.",
                    comment: "Service reminder editor footer: how repeating works")
            }
        } else if isCustom {
            Section {
                MenuPickerRow(
                    title: Text("Repeat", comment: "Custom reminder editor: repeat picker"),
                    valueText: repeatTitle(repeatRule),
                    selection: $repeatRule
                ) {
                    ForEach(ReminderRepeatRule.allCases, id: \.self) { rule in
                        repeatTitle(rule).tag(rule)
                    }
                }
                if repeatRule == .months {
                    Stepper(value: $repeatMonths, in: 1...120) {
                        Text("Every \(repeatMonths) months", comment: "Service reminder editor: repeat interval in months, plural")
                    }
                }
            }
        }
    }

    private func repeatTitle(_ rule: ReminderRepeatRule) -> Text {
        switch rule {
        case .none: Text("Never", comment: "Custom reminder repeat option: does not repeat")
        case .yearly: Text("Every year", comment: "Custom reminder repeat option: yearly")
        case .months: Text("Every few months", comment: "Custom reminder repeat option: every N months")
        }
    }

    // MARK: Load and save

    private func load() {
        guard !loaded else { return }
        loaded = true
        let settings = ReminderSettings.load()
        let defaults = builder.defaults(for: vehicle)
        guard let reminder else {
            leadDays = settings.leadDays(for: category)
            leadKm = settings.serviceLeadKm
            date = CalendarDay.date(from: defaultDay(defaults: defaults), in: .current)
            hasDate = true
            hasKm = false
            repeatRule = .none
            return
        }
        title = reminder.title
        isEnabled = reminder.isEnabled
        leadDays = reminder.leadDays
        leadKm = reminder.leadKm
        note = reminder.note
        repeatRule = reminder.repeatRule
        if let months = reminder.repeatMonths {
            repeatMonths = months
            repeatMonthsEnabled = isService
        }
        if let km = reminder.repeatKm {
            repeatKm = km
            repeatKmEnabled = true
        }
        hasDate = reminder.dueDate != nil
        hasKm = reminder.dueKm != nil
        kilometers = reminder.dueKm
        date = CalendarDay.date(from: editingDay(reminder, defaults: defaults), in: .current)
    }

    /// Prefill of a new reminder: the country default for tyres and vignette, otherwise a month from now.
    private func defaultDay(defaults: any ReminderDefaults) -> DayDate {
        switch category {
        case .tyreWinter: defaults.nextTyreChangeDay(for: .winter, from: today)
        case .tyreSummer: defaults.nextTyreChangeDay(for: .summer, from: today)
        case .vignette: defaults.nextVignetteExpiry(from: today) ?? today.adding(months: 1)
        case .service, .custom: today.adding(months: 1)
        }
    }

    /// For yearly kinds the stored date is the first legal day still to come, which may lie in the past
    /// if nobody marked it done. The editor shows the next one instead.
    private func editingDay(_ reminder: Reminder, defaults: any ReminderDefaults) -> DayDate {
        guard let stored = reminder.dueDate else { return defaultDay(defaults: defaults) }
        guard category == .tyreWinter || category == .tyreSummer || category == .vignette else { return stored }
        let schedule = reminder.schedule(
            vehicleID: vehicle.id.uuidString, projection: nil, defaults: defaults, today: today)
        let wanted: [PlannedNotification.Kind] = [.tyreChangeWinter, .tyreChangeSummer, .vignetteExpiring]
        return schedule?.occurrences(today: today)
            .filter { wanted.contains($0.kind) }
            .map(\.eventDay)
            .min() ?? stored
    }

    private func save() {
        let target: Reminder
        if let reminder {
            target = reminder
        } else {
            target = Reminder(category: category)
            modelContext.insert(target)
            target.vehicle = vehicle
        }
        target.category = category
        target.title = hasTitleField ? title.trimmingCharacters(in: .whitespaces) : ""
        target.isEnabled = isEnabled
        target.note = note
        target.leadDays = leadDays
        target.leadKm = leadKm

        let pickedDay = CalendarDay.dayDate(from: date, in: .current)
        if isService {
            target.dueDate = hasDate ? pickedDay : nil
            target.dueKm = hasKm ? kilometers : nil
            target.repeatMonths = repeatMonthsEnabled ? repeatMonths : nil
            target.repeatKm = repeatKmEnabled ? repeatKm : nil
            target.repeatRule = .none
        } else {
            target.dueDate = pickedDay
            target.dueKm = nil
            target.repeatKm = nil
            if isCustom {
                target.repeatRule = repeatRule
                target.repeatMonths = repeatRule == .months ? repeatMonths : nil
            } else {
                target.repeatRule = .none
                target.repeatMonths = nil
            }
        }

        if isEnabled, permission.state == .notDetermined {
            // Explain first, then the system prompt; the sheet closes when the user has chosen.
            showingPermissionPrompt = true
        } else {
            dismiss()
        }
    }
}
