import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// Attaches the whole receipt scan flow (source choice, camera, importers, progress, review, problems).
    /// `mode` says what the review's button does; `onConfirm` receives what the user kept.
    func receiptScan(
        _ scan: ReceiptScanController, mode: ReceiptReviewMode,
        onConfirm: @escaping (ReceiptApplication, ReceiptAttachment?) -> Void
    ) -> some View {
        modifier(ReceiptScanModifier(scan: scan, mode: mode, onConfirm: onConfirm))
    }
}

private struct ReceiptScanModifier: ViewModifier {
    @Bindable var scan: ReceiptScanController
    let mode: ReceiptReviewMode
    let onConfirm: (ReceiptApplication, ReceiptAttachment?) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                Text("Scan receipt", comment: "Title of the source choice for scanning a workshop receipt"),
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
                ReceiptReviewView(
                    review: presentation.review, mode: mode, hasAttachment: presentation.attachment != nil
                ) { application in
                    onConfirm(application, presentation.attachment)
                }
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
            Text("Reading the receipt…", comment: "Shown while the scanned receipt is being recognized")
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("receiptScanProgress")
    }

    private var problemTitle: Text {
        switch scan.problem {
        case .failed:
            Text("The scan failed", comment: "Alert title when the scan or the import failed")
        case .nothingRead, nil:
            Text("Nothing could be read", comment: "Alert title when no field could be read from the scan")
        }
    }

    private var problemMessage: Text {
        switch scan.problem {
        case .failed:
            Text("Try again, or choose a photo or a file.", comment: "Alert message when the scan or the import failed")
        case .nothingRead, nil:
            Text("Make sure the whole receipt is in view and well lit, or enter the data by hand.", comment: "Alert message when no field could be read from a receipt scan")
        }
    }
}

/// Shown instead of the scan buttons when `Entitlements.canScanReceipts` is off (ADR-11): a calm explanation,
/// no dead button.
struct ReceiptScanUnavailableNote: View {
    var body: some View {
        Label {
            Text("Scanning receipts is not included in your current plan. You can still attach a receipt from Photos or Files and enter the values yourself.", comment: "Shown instead of the receipt scan button when the scan is not part of the user's plan")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("receiptScanUnavailableNote")
    }
}
