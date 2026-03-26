import SwiftUI
import PDFKit

#if canImport(UIKit)
struct PDFKitView: UIViewRepresentable {
    let pdfData: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: pdfData)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        pdfView.backgroundColor = .clear
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.dataRepresentation() != pdfData {
            uiView.document = PDFDocument(data: pdfData)
        }
    }
}
#elseif canImport(AppKit)
struct PDFKitView: NSViewRepresentable {
    let pdfData: Data
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: pdfData)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        pdfView.backgroundColor = .clear
        
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document?.dataRepresentation() != pdfData {
            nsView.document = PDFDocument(data: pdfData)
        }
    }
}
#endif
