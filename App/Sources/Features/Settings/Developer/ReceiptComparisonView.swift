#if DEBUG
import PhotosUI
import PitlogCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Debug only (never compiled into Release): the entry to the developer tools in Settings.
struct DeveloperView: View {
    @Environment(StoreService.self) private var store

    var body: some View {
        List {
            Section {
                Picker(selection: Binding(get: { store.debugTier }, set: { store.debugTier = $0 })) {
                    Text(verbatim: "Automatic (StoreKit)").tag(Tier?.none)
                    Text(verbatim: "Free").tag(Tier?.some(.free))
                    Text(verbatim: "Pro").tag(Tier?.some(.pro))
                } label: {
                    Text(verbatim: "Pro status override")
                }
                .accessibilityIdentifier("developerTierPicker")
            } footer: {
                Text(verbatim: "Overrides the tier for the gates only. Resets when the app restarts.")
            }
            NavigationLink {
                ReceiptComparisonView()
            } label: {
                Label {
                    Text(verbatim: "Receipt extraction comparison")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "doc.text.magnifyingglass")
                }
            }
            .accessibilityIdentifier("developerReceiptComparisonRow")
        }
        .navigationTitle(Text(verbatim: "Developer"))
    }
}

/// One line of the comparison: what each extractor read and what the merge made of it.
struct ComparisonRow: Codable, Hashable, Identifiable {
    var field: String
    var heuristic: String?
    var model: String?
    var merged: String?
    var id: String { field }
}

/// The values of one run, without the image and without the recognized text (which holds the customer's
/// address). This is what the share sheet exports.
struct ComparisonExport: Codable {
    var rows: [ComparisonRow]
    var modelAvailable: Bool
    var modelAvailability: String
    var qrCodeFound: Bool
    var pageCount: Int
    var lineCount: Int
    var recognitionMs: Double
    var heuristicMs: Double
    var modelMs: Double?
    var os: String
    var date: String
}

/// Debug view for the device test: pick an image or PDF, run both extractors, compare per field, export the
/// values as JSON (docs/receipt-parser.md, "Gerätetest").
struct ReceiptComparisonView: View {
    @Query private var vehicles: [Vehicle]
    @State private var showingFileImporter = false
    @State private var showingPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isRunning = false
    @State private var export: ComparisonExport?
    @State private var exportURL: URL?
    @State private var failure: String?

    var body: some View {
        List {
            Section {
                Text(verbatim: "Apple Intelligence: \(Self.availability)")
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    showingPhotoPicker = true
                } label: {
                    Text(verbatim: "Choose a photo")
                }
                Button {
                    showingFileImporter = true
                } label: {
                    Text(verbatim: "Choose an image or PDF")
                }
                if isRunning { ProgressView() }
                if let failure {
                    Text(verbatim: failure)
                }
            }
            if let export {
                Section {
                    Text(verbatim: timings(export))
                        .fixedSize(horizontal: false, vertical: true)
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Text(verbatim: "Export values as JSON")
                        }
                    }
                } header: {
                    Text(verbatim: "Timings")
                }
                ForEach(export.rows) { row in
                    Section {
                        Text(verbatim: "Heuristic: \(row.heuristic ?? "–")")
                        Text(verbatim: "Language model: \(row.model ?? "–")")
                        Text(verbatim: "Merged: \(row.merged ?? "–")")
                    } header: {
                        Text(verbatim: row.field)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .navigationTitle(Text(verbatim: "Receipt comparison"))
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    failure = "The photo could not be loaded."
                    return
                }
                await run(data)
            }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.pdf, .image]) { result in
            guard case .success(let url) = result else { return }
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                failure = "The file could not be read."
                return
            }
            Task { await run(data) }
        }
    }

    // MARK: Run

    private func run(_ data: Data) async {
        isRunning = true
        failure = nil
        defer { isRunning = false }
        let pages = ScanPageImport.pages(from: data)
        guard !pages.isEmpty else {
            failure = "No page could be read."
            return
        }
        let clock = ContinuousClock()
        let recognitionStart = clock.now
        let scan: ReceiptScan
        do {
            scan = try await ReceiptScanService().read(pages)
        } catch {
            failure = "Text recognition failed: \(error)"
            return
        }
        let recognition = clock.now - recognitionStart
        let infos = vehicles.map { ReceiptVehicleInfo($0) }
        let context = ReceiptExtractionService.context(
            today: CalendarDay.today(in: CalendarDay.austria), vehicles: infos, primary: nil,
            rksvPayloads: scan.rksvPayloads)
        let extraction = await ReceiptExtractionService().extract(lines: scan.lines, context: context)
        let result = Self.export(
            extraction, scan: scan, recognition: recognition, availability: Self.availability)
        export = result
        exportURL = Self.write(result)
    }

    // MARK: Output

    private func timings(_ export: ComparisonExport) -> String {
        var text = "Recognition \(Int(export.recognitionMs)) ms, heuristic \(String(format: "%.1f", export.heuristicMs)) ms"
        if let model = export.modelMs { text += ", language model \(Int(model)) ms" }
        return text + ". Pages \(export.pageCount), lines \(export.lineCount), QR code \(export.qrCodeFound ? "yes" : "no")."
    }

    static var availability: String {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available: return "available"
        case .unavailable(let reason): return "unavailable (\(reason))"
        }
        #else
        return "framework missing"
        #endif
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
    }

    static func export(
        _ extraction: ReceiptExtraction, scan: ReceiptScan, recognition: Duration, availability: String
    ) -> ComparisonExport {
        let h = extraction.heuristic
        let m = extraction.model
        let merge = extraction.merge

        func money(_ value: Money?) -> String? {
            value.map { "\($0.amountMinor) \($0.currencyCode)" }
        }
        func merged<V: Hashable & Sendable>(_ field: MergedField<V>?, _ text: (V) -> String) -> String? {
            field.map { "\(text($0.value)) [\($0.confidence), \($0.agreement)]" }
        }
        func row(_ name: String, _ heuristic: String?, _ model: String?, _ merged: String? = nil) -> ComparisonRow {
            ComparisonRow(field: name, heuristic: heuristic, model: model, merged: merged)
        }

        let rows = [
            row("date (history)", h.historyDate?.isoString, m?.historyDate?.isoString,
                merged(merge.date) { $0.isoString }),
            row("grossTotal", money(h.grossTotal), money(m?.grossTotal), merged(merge.gross) { "\($0.amountMinor) \($0.currencyCode)" }),
            row("serviceDate", h.serviceDate?.isoString, m?.serviceDate?.isoString),
            row("invoiceDate", h.invoiceDate?.isoString, m?.invoiceDate?.isoString),
            row("netTotal", money(h.netTotal), money(m?.netTotal)),
            row("vatAmount", money(h.vatAmount), money(m?.vatAmount)),
            row("vatRate", h.vatRate.map(String.init), m?.vatRate.map(String.init)),
            row("workshopName", h.workshopName, m?.workshopName, merged(merge.workshop) { $0 }),
            row("workshopUID", h.workshopUID, m?.workshopUID),
            row("odometerKm", h.odometerKm.map(String.init), m?.odometerKm.map(String.init),
                merged(merge.odometerKm) { String($0) }),
            row("plate", h.plate, m?.plate, merged(merge.plate) { $0 }),
            row("vin", h.vin, m?.vin, merged(merge.vin) { $0 }),
            row("category", h.suggestedCategory?.rawValue, m?.suggestedCategory?.rawValue,
                merged(merge.category) { $0.rawValue }),
            row("workItems", h.workItems.isEmpty ? nil : h.workItems.joined(separator: " | "),
                (m?.workItems.isEmpty ?? true) ? nil : m?.workItems.joined(separator: " | "),
                merged(merge.workItems) { $0.joined(separator: " | ") }),
            row("suggestedPlaque", h.suggestedPlaque.map { "\($0)" }, nil),
            row("isCreditNote", String(h.isCreditNote), m.map { String($0.isCreditNote) }, String(merge.isCreditNote)),
        ]
        return ComparisonExport(
            rows: rows, modelAvailable: extraction.modelAvailable, modelAvailability: availability,
            qrCodeFound: extraction.rksv != nil, pageCount: scan.pageCount, lineCount: scan.lines.count,
            recognitionMs: milliseconds(recognition), heuristicMs: milliseconds(extraction.heuristicDuration),
            modelMs: extraction.modelDuration.map(milliseconds),
            os: ProcessInfo.processInfo.operatingSystemVersionString,
            date: CalendarDay.today(in: .current).isoString)
    }

    private static func write(_ export: ComparisonExport) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(export) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("receipt-comparison-\(export.date)-\(UUID().uuidString.prefix(8))")
            .appendingPathExtension("json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
#endif
