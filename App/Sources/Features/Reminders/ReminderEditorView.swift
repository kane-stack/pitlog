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
    @State private var showingPermissionPrompt = false

    private let builder = ReminderScheduleBuilder()

    init(vehicle: Vehicle, category: ReminderCategory, reminder: Reminder?) {
        self.vehicle = vehicle
        self.category = category
        self.reminder = reminder
        let f = Self.fields(vehicle: vehicle, category: category, reminder: reminder)
        _title = State(initialValue: f.title)
        _isEnabled = State(initialValue: f.isEnabled)
        _date = State(initialValue: f.date)
        _hasDate = State(initialValue: f.hasDate)
        _hasKm = State(initialValue: f.hasKm)
        _kilometers = State(initialValue: f.kilometers)
        _leadDays = State(initialValue: f.leadDays)
        _leadKm = State(initialValue: f.leadKm)
        _repeatRule = State(initialValue: f.repeatRule)
        _repeatMonths = State(initialValue: f.repeatMonths)
        _repeatMonthsEnabled = State(initialValue: f.repeatMonthsEnabled)
        _repeatKmEnabled = State(initialValue: f.repeatKmEnabled)
        _repeatKm = State(initialValue: f.repeatKm)
        _note = State(initialValue: f.note)
    }

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
                    FormTextField(title: Text("Note", comment: "Reminder editor: optional note"), text: $note)
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
            .notificationPermissionPrompt(isPresented: $showingPermissionPrompt) { dismiss() }
        }
    }

    private var navigationTitle: Text {
        Text("Reminder", comment: "Reminder type: custom reminder without a title")
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
                        .foregroundStyle(.primary)
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
            // A row instead of a section footer: footers use a secondary color that fails the contrast audit.
            dueFooter
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
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
            LeadPicker(title: Text("Remind before", comment: "Reminder editor: lead time before the date"), value: $leadDays, options: LeadOptions.days, valueText: LeadOptions.days)
            if isService, hasKm {
                LeadPicker(title: Text("Remind before, distance", comment: "Service reminder editor: lead distance before the odometer value"), value: $leadKm, options: LeadOptions.leadKm, valueText: LeadOptions.kilometers)
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
                    LeadPicker(title: Text("Repeat every", comment: "Reminder editor: repeat interval"), value: $repeatMonths, options: LeadOptions.repeatMonths, valueText: LeadOptions.months)
                }
                Toggle(isOn: $repeatKmEnabled) {
                    Text("Repeat by distance", comment: "Service reminder editor: repeat after a number of kilometres")
                }
                if repeatKmEnabled {
                    LeadPicker(title: Text("Repeat every, distance", comment: "Service reminder editor: repeat interval in kilometres"), value: $repeatKm, options: LeadOptions.repeatKm, valueText: LeadOptions.kilometers)
                }
                Text(
                    "When you mark the service as done, the next one counts from that day and the current odometer reading.",
                    comment: "Service reminder editor footer: how repeating works")
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
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
                    LeadPicker(title: Text("Repeat every", comment: "Reminder editor: repeat interval"), value: $repeatMonths, options: LeadOptions.repeatMonths, valueText: LeadOptions.months)
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

    /// Everything the form starts with. Computed once in `init`, so the form never changes after it appears.
    private struct Fields {
        var title = ""
        var isEnabled = true
        var date = Date()
        var hasDate = true
        var hasKm = false
        var kilometers: Int?
        var leadDays = 14
        var leadKm = ReminderSettings.Defaults.serviceLeadKm
        var repeatRule: ReminderRepeatRule = .none
        var repeatMonths = 12
        var repeatMonthsEnabled = false
        var repeatKmEnabled = false
        var repeatKm = 15_000
        var note = ""
    }

    private static func fields(vehicle: Vehicle, category: ReminderCategory, reminder: Reminder?) -> Fields {
        let today = CalendarDay.today(in: .current)
        let settings = ReminderSettings.load()
        let defaults = ReminderScheduleBuilder().defaults(for: vehicle)
        var fields = Fields()
        guard let reminder else {
            fields.leadDays = settings.leadDays(for: category)
            fields.leadKm = settings.serviceLeadKm
            fields.date = CalendarDay.date(
                from: defaultDay(category: category, defaults: defaults, today: today), in: .current)
            return fields
        }
        fields.title = reminder.title
        fields.isEnabled = reminder.isEnabled
        fields.leadDays = reminder.leadDays
        fields.leadKm = reminder.leadKm
        fields.note = reminder.note
        fields.repeatRule = reminder.repeatRule
        if let months = reminder.repeatMonths {
            fields.repeatMonths = months
            fields.repeatMonthsEnabled = category == .service
        }
        if let km = reminder.repeatKm {
            fields.repeatKm = km
            fields.repeatKmEnabled = true
        }
        fields.hasDate = reminder.dueDate != nil
        fields.hasKm = reminder.dueKm != nil
        fields.kilometers = reminder.dueKm
        fields.date = CalendarDay.date(
            from: editingDay(reminder, vehicle: vehicle, category: category, defaults: defaults, today: today),
            in: .current)
        return fields
    }

    /// Prefill of a new reminder: the country default for tyres and vignette, otherwise a month from now.
    private static func defaultDay(category: ReminderCategory, defaults: any ReminderDefaults, today: DayDate) -> DayDate {
        switch category {
        case .tyreWinter: defaults.nextTyreChangeDay(for: .winter, from: today)
        case .tyreSummer: defaults.nextTyreChangeDay(for: .summer, from: today)
        case .vignette: defaults.nextVignetteExpiry(from: today) ?? today.adding(months: 1)
        case .service, .custom: today.adding(months: 1)
        }
    }

    /// For yearly kinds the stored date is the first legal day still to come, which may lie in the past
    /// if nobody marked it done. The editor shows the next one instead.
    private static func editingDay(
        _ reminder: Reminder, vehicle: Vehicle, category: ReminderCategory,
        defaults: any ReminderDefaults, today: DayDate
    ) -> DayDate {
        guard let stored = reminder.dueDate else {
            return defaultDay(category: category, defaults: defaults, today: today)
        }
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
