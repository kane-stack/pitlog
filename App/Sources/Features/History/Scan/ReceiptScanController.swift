import Observation
import PhotosUI
import PitlogCore
import SwiftUI
import UIKit

/// What a receipt scan needs from the screen that starts it.
struct ReceiptScanInput {
    var vehicles: [ReceiptVehicleInfo]
    /// The vehicle the screen is about; also the one whose odometer and registration the parser checks against.
    var contextVehicleID: UUID?
    /// The entry already belongs to the vehicle (the entry editor): the review has no vehicle picker.
    var vehicleIsFixed: Bool
}

/// State and flow of "Scan receipt": pick a source, read the pages, extract, show the review.
/// The page images live only inside this controller until the review is closed; what is stored is the
/// `ReceiptAttachment` the user confirms.
@MainActor
@Observable
final class ReceiptScanController {
    enum Problem: Hashable {
        case nothingRead
        case failed
    }

    struct Presentation: Identifiable {
        let id = UUID()
        let review: ReceiptReview
        let attachment: ReceiptAttachment?
    }

    var showingOptions = false
    var showingCamera = false
    var showingFileImporter = false
    var showingPhotoPicker = false
    var photoItem: PhotosPickerItem?
    private(set) var isRecognizing = false
    var presentation: Presentation?
    var problem: Problem?

    @ObservationIgnored var scanService = ReceiptScanService()
    @ObservationIgnored var extractionService = ReceiptExtractionService()
    @ObservationIgnored private var input = ReceiptScanInput(vehicles: [], contextVehicleID: nil, vehicleIsFixed: false)

    /// Launch argument of the UI tests: the simulator has no document camera, so a fixed recognition result
    /// (`ReceiptScanFixtures`) goes through the real heuristic and merge, with a fake language model.
    static let uiTestArgument = "-UITestReceiptScan"

    private static var today: DayDate { CalendarDay.today(in: CalendarDay.austria) }

    func start(_ input: ReceiptScanInput) {
        self.input = input
        if ProcessInfo.processInfo.arguments.contains(Self.uiTestArgument) {
            let scan = ReceiptScan(lines: ReceiptScanFixtures.lines, rksvPayloads: [], pageCount: 1)
            extractionService = ReceiptExtractionService(model: ReceiptScanFixtures.fakeModel)
            finish(scan: scan, pages: [], originalPDF: nil)
            return
        }
        showingOptions = true
    }

    func handleCamera(_ images: [UIImage]) {
        showingCamera = false
        process(ScanPageImport.pages(from: images), originalPDF: nil)
    }

    func handleCameraFailure() {
        showingCamera = false
        problem = .failed
    }

    func importFile(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            if (error as? CocoaError)?.code != .userCancelled { problem = .failed }
        case .success(let url):
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), data.count <= ReceiptImport.maximumBytes else {
                problem = .failed
                return
            }
            process(ScanPageImport.pages(from: data), originalPDF: Self.isPDF(data) ? data : nil)
        }
    }

    func importPhoto(_ item: PhotosPickerItem) async {
        photoItem = nil
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            problem = .failed
            return
        }
        process(ScanPageImport.pages(from: data), originalPDF: Self.isPDF(data) ? data : nil)
    }

    private static func isPDF(_ data: Data) -> Bool { data.prefix(5) == Data("%PDF-".utf8) }

    private func process(_ pages: [ScanPage], originalPDF: Data?) {
        guard !pages.isEmpty else {
            problem = .nothingRead
            return
        }
        isRecognizing = true
        let service = scanService
        Task {
            do {
                let scan = try await service.read(pages)
                await finishAsync(scan: scan, pages: pages, originalPDF: originalPDF)
            } catch {
                problem = .failed
            }
            isRecognizing = false
        }
    }

    private func finish(scan: ReceiptScan, pages: [ScanPage], originalPDF: Data?) {
        isRecognizing = true
        Task {
            await finishAsync(scan: scan, pages: pages, originalPDF: originalPDF)
            isRecognizing = false
        }
    }

    private func finishAsync(scan: ReceiptScan, pages: [ScanPage], originalPDF: Data?) async {
        guard !scan.lines.isEmpty else {
            problem = .nothingRead
            return
        }
        let context = ReceiptExtractionService.context(
            today: Self.today, vehicles: input.vehicles, primary: input.contextVehicleID,
            rksvPayloads: scan.rksvPayloads)
        let extraction = await extractionService.extract(lines: scan.lines, context: context)
        let review = ReceiptReview(
            merge: extraction.merge, vehicles: input.vehicles, contextVehicleID: input.contextVehicleID,
            vehicleIsFixed: input.vehicleIsFixed, locale: .autoupdatingCurrent)
        guard !review.items.isEmpty else {
            problem = .nothingRead
            return
        }
        let attachment = ReceiptAttachmentBuilder.make(
            pages: pages, originalPDF: originalPDF, recognizedText: scan.storedText)
        presentation = Presentation(review: review, attachment: attachment)
    }
}
