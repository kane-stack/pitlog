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
            // One summary instead of the per-word elements PDFKit creates for an untagged PDF: those are
            // tiny hit areas (audit) and read without structure. The full document opens through Share.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Preview of the service record with \(file.pageCount) pages. Share it to read the full document in another app.", comment: "VoiceOver: summary of the PDF preview, replaces reading the pages word by word. The number is the page count, plural"))
            .accessibilityIdentifier("serviceRecordPreview")
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

/// `PDFView` for SwiftUI. For VoiceOver the preview is one summary element (see the caller).
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
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}
