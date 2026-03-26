import Foundation
import Combine
import PencilKit
import Vision

class OCRService {
    static let shared = OCRService()
    
    /**
     * recognizeText(from:drawing:)
     * Converts a PKDrawing into an image and runs Vision text recognition.
     */
    func recognizeText(from drawing: PKDrawing) async throws -> String {
        // 1. Convert drawing to image
        #if os(iOS)
        let uiImage = drawing.image(from: drawing.bounds, scale: 2.0)
        guard let cgImage = uiImage.cgImage else {
            throw OCRError.imageConversionFailed
        }
        #elseif os(macOS)
        let nsImage = drawing.image(from: drawing.bounds, scale: 2.0)
        var rect = drawing.bounds
        guard let cgImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw OCRError.imageConversionFailed
        }
        #else
        // Fallback for other platforms if needed
        throw OCRError.imageConversionFailed
        #endif
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { (request, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }
                
                // Combine recognized text pieces with spaces/newlines
                let recognizedString = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: recognizedString)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    enum OCRError: Error {
        case imageConversionFailed
        case noTextFound
    }
}
