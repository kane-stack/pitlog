import Observation
import PhotosUI
import PitlogCore
import SwiftUI
import UIKit

/// State and flow of "Scan registration certificate": pick a source, read the pages, show the review.
/// The page images live only inside `process` and are gone when recognition ends; nothing is stored.
@MainActor
@Observable
final class RegistrationScanController {
    enum Problem: Hashable {
        case nothingRead
        case notACertificate
        case failed
    }

    struct Presentation: Identifiable {
        let id = UUID()
        let review: RegistrationReview
    }

    var showingOptions = false
    var showingCamera = false
    var showingFileImporter = false
    var showingPhotoPicker = false
    var photoItem: PhotosPickerItem?
    private(set) var isRecognizing = false
    var presentation: Presentation?
    var problem: Problem?

    @ObservationIgnored var service = RegistrationScanService()

    /// Launch argument of the UI tests: the simulator has no document camera, so a fake recognition result
    /// (`RegistrationScanFixtures`) goes through the real parser instead.
    static let uiTestArgument = "-UITestRegistrationScan"
    static let uiTestUnsupportedArgument = "-UITestRegistrationScanUnsupported"

    func start() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(Self.uiTestArgument) {
            let pages = arguments.contains(Self.uiTestUnsupportedArgument)
                ? RegistrationScanFixtures.unsupportedClass : RegistrationScanFixtures.mixed
            finish(with: RegistrationScanService.draft(from: pages, today: Self.today))
            return
        }
        showingOptions = true
    }

    func handleCamera(_ images: [UIImage]) {
        showingCamera = false
        process(ScanPageImport.pages(from: images))
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
            process(ScanPageImport.pages(from: data))
        }
    }

    func importPhoto(_ item: PhotosPickerItem) async {
        photoItem = nil
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            problem = .failed
            return
        }
        process(ScanPageImport.pages(from: data))
    }

    private static var today: DayDate { CalendarDay.today(in: CalendarDay.austria) }

    private func process(_ pages: [ScanPage]) {
        guard !pages.isEmpty else {
            problem = .nothingRead
            return
        }
        isRecognizing = true
        let service = service
        let today = Self.today
        Task {
            do {
                finish(with: try await service.read(pages, today: today))
            } catch {
                problem = .failed
            }
            isRecognizing = false
        }
    }

    private func finish(with draft: RegistrationDraft) {
        if draft.notices.contains(.transferPermit) {
            problem = .notACertificate
            return
        }
        let review = RegistrationReview(draft: draft)
        if review.isEmpty {
            problem = .nothingRead
        } else {
            presentation = Presentation(review: review)
        }
    }
}
