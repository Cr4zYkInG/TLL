import Foundation
import PDFKit

/**
 * NoteProcessingService — Handles file processing and text extraction
 */
class NoteProcessingService {
    static let shared = NoteProcessingService()
    
    private init() {}
    
    func extractText(from url: URL) -> String? {
        // Ensure we have access to the file (needed for UIDocumentPicker results)
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "pdf":
            return extractTextFromPDF(url: url)
        default:
            return nil
        }
    }
    
    private func extractTextFromPDF(url: URL) -> String? {
        guard let document = PDFDocument(url: url) else { return nil }
        
        var fullText = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        
        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
