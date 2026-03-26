import SwiftUI
import Vision
import SwiftData
#if os(macOS)
import AppKit
#endif

/**
 * CaseScannerView — OCR-to-IRAC extraction for physical textbooks.
 * Powered by Mistral Large (Premium Feature).
 */
struct CaseScannerView: View {
    var hideCloseButton: Bool = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    #if os(macOS)
    @State private var inputImage: NSImage?
    #else
    @State private var inputImage: UIImage?
    #endif

    @State private var recognizedText = ""
    @State private var isProcessing = false
    @State private var aiNote: String?
    
    var body: some View {
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                headerArea
                
                if let image = inputImage {
                    ZStack {
                        Group {
                            #if os(macOS)
                            Image(nsImage: image)
                                .resizable()
                            #else
                            Image(uiImage: image)
                                .resizable()
                            #endif
                        }
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(20)
                        .glassCard()
                        
                        if isProcessing {
                            ZStack {
                                Color.black.opacity(0.4).cornerRadius(20)
                                VStack {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Analyzing Case Facts...")
                                        .font(Theme.Fonts.inter(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    placeholderArea
                }
                
                if let note = aiNote {
                    ScrollView {
                        Text(note)
                            .font(Theme.Fonts.inter(size: 14))
                            .padding()
                            .background(Theme.Colors.surface.opacity(0.4))
                            .cornerRadius(16)
                            .glassCard()
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                actionButtons
            }
        }
    }
    
    private var headerArea: some View {
        HStack {
            if !hideCloseButton {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(10)
                        .background(Theme.Colors.surface)
                        .clipShape(Circle())
                }
            }
            Spacer()
            Text("Case Briefing Scanner")
                .font(Theme.Fonts.outfit(size: 20, weight: .bold))
            Spacer()
            // Help
            Image(systemName: "questionmark.circle")
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding()
    }
    
    private var placeholderArea: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.accent.opacity(0.4))
            
            Text("Scan any Case Page")
                .font(Theme.Fonts.outfit(size: 24, weight: .bold))
            
            Text("Point your camera at a textbook or legal brief.\nThinkLikeLaw will extract the IRAC structure instantly.")
                .font(Theme.Fonts.inter(size: 14))
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            if inputImage == nil {
                Button(action: { /* Logic for image picker */ }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Select from Library")
                    }
                    .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                    .foregroundColor(Theme.Colors.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.Colors.accent)
                    .cornerRadius(16)
                    .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 10, y: 5)
                }
            } else if !isProcessing && aiNote == nil {
                Button(action: { performOCR() }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Extract IRAC Brief")
                    }
                    .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                    .foregroundColor(Theme.Colors.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.Colors.accent)
                    .cornerRadius(16)
                }
            } else if aiNote != nil {
                Button(action: { saveNote() }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save to Briefs")
                    }
                    .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .cornerRadius(16)
                }
            }
        }
        .padding(24)
        .background(Theme.Colors.surface)
        #if os(iOS)
        .cornerRadius(32, corners: .allCorners)
        #else
        .cornerRadius(32)
        #endif
        .glassCard()
    }
    
    // MARK: - Logic
    
    private func performOCR() {
        #if os(macOS)
        guard let image = inputImage, let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        #else
        guard let image = inputImage, let cgImage = image.cgImage else { return }
        #endif
        isProcessing = true
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            
            Task {
                processWithAI(text: text)
            }
        }
        request.recognitionLevel = .accurate
        
        try? requestHandler.perform([request])
    }
    
    private func processWithAI(text: String) {
        Task {
            do {
                let prompt = "OCR Result from a Law Textbook:\n\(text)\n\nExtract a high-fidelity IRAC Case Brief. Format with Markdown. Ensure OSCOLA compliance."
                let (response, _) = try await AIService.shared.callAI(tool: .chat, content: prompt)
                
                await MainActor.run {
                    self.aiNote = response
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func saveNote() {
        guard let noteText = aiNote else { return }
        let newNote = PersistedNote(
            title: "Scanned Brief: \(Date().formatted(date: .abbreviated, time: .omitted))",
            content: noteText,
            preview: "Extracted from Textbook scan."
        )
        modelContext.insert(newNote)
        try? modelContext.save()
        
        // Award XP for successful case extraction
        XPService.shared.addXP(.caseScan)
        
        dismiss()
    }
}
