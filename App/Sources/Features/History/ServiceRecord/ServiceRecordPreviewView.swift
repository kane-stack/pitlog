import CoreTransferable
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// The exported file as something `ShareLink` can hand over: the PDF itself, with its file name.
struct ServiceRecordDocument: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { document in
            SentTransferredFile(document.url, allowAccessingOriginalFile: true)
        }
    }
}

/// Shows the finished PDF and offers the share sheet.
struct ServiceRecordPreviewView: View {
    let file: ExportedServiceRecord

    var body: some View {
        PDFPreview(url: file.url)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(Text("Preview", comment: "Service record export: navigation title of the PDF preview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: ServiceRecordDocument(url: file.url), preview: SharePreview(file.fileName)) {
                        Label {
                            Text("Share", comment: "Service record export: button that opens the share sheet for the PDF")
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .accessibilityIdentifier("shareServiceRecordButton")
                }
            }
    }
}

/// `PDFView` for SwiftUI. VoiceOver reads the text of the pages through PDFKit.
private struct PDFPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.pageShadowsEnabled = true
        view.backgroundColor = .systemGroupedBackground
        view.document = PDFDocument(url: url)
        view.accessibilityIdentifier = "serviceRecordPreview"
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}
