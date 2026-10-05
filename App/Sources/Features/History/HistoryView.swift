import PitlogCore
import SwiftData
import SwiftUI

/// The maintenance history of one vehicle: costs per year on top, then the timeline grouped by year.
/// Pushed from the vehicle detail. Rows are tappable rows with swipe actions (a `Button` row in a list
/// fails the clipping audit, see `docs/accessibility-audit.md`).
struct HistoryView: View {
    let vehicle: Vehicle

    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @State private var editorTarget: EntryEditorTarget?
    @State private var filter: MaintenanceCategory?
    @State private var entryToDelete: MaintenanceEntry?
    @State private var showingDeleteConfirmation = false

    private var entries: [MaintenanceEntry] { vehicle.maintenanceEntries ?? [] }

    var body: some View {
        let groups = HistoryTimeline.groups(entries, filter: filter)
        List {
            CostsSection(entries: entries)
            timelineHeader
            filterRow
            addRow
            if entries.isEmpty {
                note(Text("No entries yet. Add service, repairs and other workshop visits.", comment: "History: empty state"))
            } else if groups.isEmpty {
                note(Text("No entries in this category.", comment: "History: empty state when the category filter matches nothing"))
            }
            ForEach(groups) { group in
                yearHeader(group.year)
                ForEach(group.entries, id: \.persistentModelID) { entry in
                    row(entry)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(Text("History", comment: "Section header on the vehicle detail: maintenance history and costs"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $editorTarget) { target in
            EntryEditorView(vehicle: vehicle, entry: target.entry, prefill: target.prefill)
        }
        .confirmationDialog(
            Text("Delete this entry?", comment: "History: title of the delete confirmation"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible,
            presenting: entryToDelete
        ) { entry in
            Button(role: .destructive) {
                modelContext.delete(entry)
                entryToDelete = nil
            } label: {
                Text("Delete", comment: "Swipe action to delete a reminder")
            }
        } message: { _ in
            Text("The entry and its receipts are deleted from all your devices.", comment: "History: message of the delete confirmation")
        }
    }

    // MARK: Header rows

    private var timelineHeader: some View {
        Text("Entries", comment: "History: header above the list of entries")
            .font(.title3.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
            .listRowSeparator(.hidden)
            .padding(.top, 8)
    }

    private func yearHeader(_ year: Int) -> some View {
        Text(verbatim: String(year))
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
            .listRowSeparator(.hidden)
    }

    private func note(_ text: Text) -> some View {
        text
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var filterRow: some View {
        MenuPickerRow(
            title: Text("Category", comment: "History: category filter and entry editor field"),
            valueText: filter.map { Text(verbatim: $0.title(locale: locale)) }
                ?? Text("All", comment: "History: category filter value that shows every category"),
            selection: $filter
        ) {
            Text("All", comment: "History: category filter value that shows every category")
                .tag(MaintenanceCategory?.none)
            ForEach(MaintenanceCategory.allCases, id: \.self) { category in
                Text(verbatim: category.title(locale: locale)).tag(MaintenanceCategory?.some(category))
            }
        }
        .accessibilityIdentifier("historyFilter")
    }

    private var addRow: some View {
        Label {
            Text("Add entry", comment: "History: button to add a new entry")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "plus.circle")
        }
        .foregroundStyle(Color.accentColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { editorTarget = .new() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { editorTarget = .new() }
        .accessibilityIdentifier("addEntryButton")
    }

    // MARK: Rows

    private func row(_ entry: MaintenanceEntry) -> some View {
        let presentation = HistoryRowPresentation(entry: entry, locale: locale)
        return HistoryRow(presentation: presentation)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { editorTarget = .edit(entry) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: presentation.accessibilityLabel))
            .accessibilityHint(Text("Opens the entry for editing.", comment: "VoiceOver hint of a history row"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { editorTarget = .edit(entry) }
            .accessibilityAction(named: Text("Delete", comment: "Swipe action to delete a reminder")) {
                confirmDelete(entry)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    confirmDelete(entry)
                } label: {
                    Label {
                        Text("Delete", comment: "Swipe action to delete a reminder")
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
                Button {
                    editorTarget = .edit(entry)
                } label: {
                    Label {
                        Text("Edit", comment: "Swipe action to edit a reminder")
                    } icon: {
                        Image(systemName: "pencil")
                    }
                }
                .tint(.indigo)
            }
    }

    private func confirmDelete(_ entry: MaintenanceEntry) {
        entryToDelete = entry
        showingDeleteConfirmation = true
    }
}

/// One entry of the timeline: category with icon, date, workshop, work summary and amount.
struct HistoryRow: View {
    let presentation: HistoryRowPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AmountLayout {
                Label {
                    Text(verbatim: presentation.categoryTitle)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: presentation.entry.category.iconName)
                }
                .font(.headline)
            } trailing: {
                if let amount = presentation.amountText {
                    Text(verbatim: amount)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(verbatim: presentation.dateText)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if let workshop = presentation.workshop {
                Text(verbatim: workshop)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let summary = presentation.workSummary {
                Text(verbatim: summary)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if presentation.receiptCount > 0 {
                Label {
                    Text("\(presentation.receiptCount) receipts", comment: "History row: number of attached receipts, plural")
                } icon: {
                    Image(systemName: "paperclip")
                }
                .font(.subheadline)
            }
        }
    }
}
