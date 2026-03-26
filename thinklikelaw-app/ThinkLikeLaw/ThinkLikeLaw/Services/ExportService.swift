import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#if canImport(PencilKit)
import PencilKit
#endif
import PDFKit

class ExportService {
    static let shared = ExportService()
    
    private init() {}
    
    func exportNoteToPDF(note: PersistedNote) -> URL? {
        let pdfFilename = "\(note.title.replacingOccurrences(of: " ", with: "_")).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(pdfFilename)

        #if os(iOS)
        let format = UIGraphicsPDFRendererFormat()
        let pageWidth: CGFloat = 595.2 // A4 Width
        let pageHeight: CGFloat = 841.8 // A4 Height
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        do {
            try renderer.writePDF(to: tempURL) { context in
                context.beginPage()
                
                let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
                let bodyFont = UIFont.systemFont(ofSize: 12, weight: .regular)
                
                // Draw Title
                let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont]
                let attributedTitle = NSAttributedString(string: note.title, attributes: titleAttributes)
                attributedTitle.draw(in: CGRect(x: 40, y: 40, width: pageWidth - 80, height: 40))
                
                // Draw Metadata
                let metaAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.gray]
                let metaString = "Created: \(note.createdAt?.formatted() ?? "Unknown") | Module: \(note.module?.name ?? "General")"
                let attributedMeta = NSAttributedString(string: metaString, attributes: metaAttributes)
                attributedMeta.draw(in: CGRect(x: 40, y: 80, width: pageWidth - 80, height: 20))
                
                // Draw Content
                let textFontAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont]
                let attributedContent = NSAttributedString(string: note.content, attributes: textFontAttributes)
                attributedContent.draw(in: CGRect(x: 40, y: 110, width: pageWidth - 80, height: pageHeight - 150))
                
                // Draw Drawing Data
                if let drawingData = note.drawingData, let drawing = try? PKDrawing(data: drawingData) {
                    let image = drawing.image(from: drawing.bounds, scale: 2.0)
                    let maxImageWidth = pageWidth - 80
                    let aspectRatio = image.size.height / image.size.width
                    let imageHeight = maxImageWidth * aspectRatio
                    
                    context.beginPage()
                    image.draw(in: CGRect(x: 40, y: 40, width: maxImageWidth, height: min(imageHeight, pageHeight - 80)))
                }
            }
            return tempURL
        } catch {
            print("ExportService: Failed to create PDF (iOS): \(error)")
            return nil
        }
        #elseif os(macOS)
        let pdfData = NSMutableData()
        let pageWidth: CGFloat = 595.2
        let pageHeight: CGFloat = 841.8
        var pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else {
            return nil
        }
        
        NSGraphicsContext.current = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        
        pdfContext.beginPDFPage(nil)
        
        let titleFont = NSFont.boldSystemFont(ofSize: 24)
        let bodyFont = NSFont.systemFont(ofSize: 12)
        
        // Draw Title (PDF uses 0,0 at bottom-left on Mac, so we flip or calculate)
        let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont]
        let attributedTitle = NSAttributedString(string: note.title, attributes: titleAttributes)
        attributedTitle.draw(in: CGRect(x: 40, y: pageHeight - 80, width: pageWidth - 80, height: 40))
        
        // Draw Metadata
        let metaAttributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.gray]
        let metaString = "Created: \(note.createdAt?.formatted() ?? "Unknown") | Module: \(note.module?.name ?? "General")"
        let attributedMeta = NSAttributedString(string: metaString, attributes: metaAttributes)
        attributedMeta.draw(in: CGRect(x: 40, y: pageHeight - 100, width: pageWidth - 80, height: 20))
        
        // Draw Content
        let textAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont]
        let attributedContent = NSAttributedString(string: note.content, attributes: textAttributes)
        attributedContent.draw(in: CGRect(x: 40, y: 40, width: pageWidth - 80, height: pageHeight - 150))
        
        pdfContext.endPDFPage()
        
        // Drawing Page
        if let drawingData = note.drawingData, let drawing = try? PKDrawing(data: drawingData) {
            pdfContext.beginPDFPage(nil)
            let image = drawing.image(from: drawing.bounds, scale: 2.0)
            let maxImageWidth = pageWidth - 80
            let aspectRatio = image.size.height / image.size.width
            let imageHeight = maxImageWidth * aspectRatio
            
            image.draw(in: CGRect(x: 40, y: pageHeight - imageHeight - 40, width: maxImageWidth, height: min(imageHeight, pageHeight - 80)))
            pdfContext.endPDFPage()
        }
        
        pdfContext.closePDF()
        
        do {
            try pdfData.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            print("ExportService: Failed to save PDF (macOS): \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }
    
    func exportNoteToMarkdown(note: PersistedNote) -> URL? {
        let filename = "\(note.title.replacingOccurrences(of: " ", with: "_")).md"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        let markdownContent = """
        # \(note.title)
        
        **Module**: \(note.module?.name ?? "General")
        **Date**: \(note.createdAt?.formatted() ?? "Unknown")
        
        ---
        
        \(note.content)
        
        ---
        *Exported from ThinkLikeLaw*
        """
        
        do {
            try markdownContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("ExportService: Failed to create Markdown file: \(error)")
            return nil
        }
    }
}
