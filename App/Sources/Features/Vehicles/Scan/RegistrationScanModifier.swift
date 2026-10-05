import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// Attaches the whole scan flow (source choice, camera, importers, progress, review, problems) to a view.
    /// `onApply` receives the values the user kept on the review screen.
    func registrationScan(
        _ scan: RegistrationScanController, onApply: @escaping (RegistrationPrefill) -> Void
    ) -> some View {
        modifier(RegistrationScanModifier(scan: scan, onApply: onApply))
    }
}

private struct RegistrationScanModifier: ViewModifier {
    @Bindable var scan: RegistrationScanController
    let onApply: (RegistrationPrefill) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                Text("Scan registration certificate", comment: "Title of the source choice for scanning the registration certificate"),
                isPresented: $scan.showingOptions, titleVisibility: .visible
            ) {
                if DocumentScanner.isSupported {
                    Button {
                        scan.showingCamera = true
                    } label: {
                        Text("Scan with camera", comment: "Scan source: the document camera")
                    }
                }
                Button {
                    scan.showingPhotoPicker = true
                } label: {
                    Text("Choose from Photos", comment: "Scan source: the photo library")
                }
                Button {
                    scan.showingFileImporter = true
                } label: {
                    Text("Choose a file", comment: "Scan source: an image or PDF from the Files app")
                }
                Button(role: .cancel) {} label: {
                    Text("Cancel", comment: "Cancel button of a form")
                }
            }
            .fullScreenCover(isPresented: $scan.showingCamera) {
                DocumentScanner(
                    onFinish: { scan.handleCamera($0) },
                    onCancel: { scan.showingCamera = false },
                    onFailure: { scan.handleCameraFailure() }
                )
                .ignoresSafeArea()
            }
            .fileImporter(isPresented: $scan.showingFileImporter, allowedContentTypes: [.pdf, .image]) { result in
                scan.importFile(result)
            }
            .photosPicker(isPresented: $scan.showingPhotoPicker, selection: $scan.photoItem, matching: .images)
            .onChange(of: scan.photoItem) { _, item in
                guard let item else { return }
                Task { await scan.importPhoto(item) }
            }
            .sheet(item: $scan.presentation) { presentation in
                RegistrationReviewView(review: presentation.review, onApply: onApply)
            }
            .alert(
                problemTitle,
                isPresented: Binding(
                    get: { scan.problem != nil },
                    set: { if !$0 { scan.problem = nil } })
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Alert dismiss button")
                }
            } message: {
                problemMessage
            }
            .overlay {
                if scan.isRecognizing { progress }
            }
    }

    private var progress: some View {
        ProgressView {
            Text("Reading the certificate…", comment: "Shown while the scanned certificate is being recognized")
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("registrationScanProgress")
    }

    private var problemTitle: Text {
        switch scan.problem {
        case .notACertificate:
            Text("This is not a registration certificate", comment: "Alert title when a transfer permit or similar was scanned")
        case .failed:
            Text("The scan failed", comment: "Alert title when the scan or the import failed")
        case .nothingRead, nil:
            Text("Nothing could be read", comment: "Alert title when no field could be read from the scan")
        }
    }

    private var problemMessage: Text {
        switch scan.problem {
        case .notACertificate:
            Text(RegistrationScanNoticeTexts.transferPermit)
        case .failed:
            Text("Try again, or choose a photo or a file.", comment: "Alert message when the scan or the import failed")
        case .nothingRead, nil:
            Text("Make sure the whole certificate is in view and well lit, or enter the data by hand.", comment: "Alert message when no field could be read from the scan")
        }
    }
}
