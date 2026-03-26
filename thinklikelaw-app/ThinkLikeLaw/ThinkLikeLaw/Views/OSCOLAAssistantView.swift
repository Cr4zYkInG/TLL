import SwiftUI
import UniformTypeIdentifiers

struct OSCOLAAssistantView: View {
    @State private var text = ""
    @State private var isProcessing = false
    @State private var feedback = ""
    @State private var showingFeedback = false
    
    // File Upload
    @State private var showingFilePicker = false
    @State private var isExtracting = false
    
    var body: some View {
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Editorial Audit Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.Colors.accent)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("OSCOLA Audit Suite")
                                .font(Theme.Fonts.outfit(size: 24, weight: .bold))
                            Text("Premium Citation Accuracy Enforcement")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Status Indicator
                        HStack(spacing: 6) {
                            Circle().fill(Theme.Colors.accent).frame(width: 6, height: 6)
                            Text("OSCOLA 4TH ED")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.Colors.surface)
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                    }
                    
                    Text("Paste your bibliography or footnotes. Our AI will audit every period, bracket, and italics for strict compliance.")
                        .font(Theme.Fonts.inter(size: 14))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(32)
                .background(Theme.Colors.surface.opacity(0.1))
                
                // Audit Workbench
                VStack(spacing: 20) {
                    HStack {
                        HStack(spacing: 8) {
                            Text("SOURCE MANUSCRIPT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.Colors.textSecondary)
                            
                            if isProcessing {
                                Text("• AUDITING...")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(Theme.Colors.accent)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            showingFilePicker = true
                        } label: {
                            Label("Load Document", systemImage: "arrow.up.doc.fill")
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                    
                    ZStack {
                        if isExtracting {
                            ProgressView("Scanning for citations...")
                        } else {
                            VStack(spacing: 0) {
                                TextEditor(text: $text)
                                    .font(.system(size: 16, design: .monospaced))
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .disabled(isProcessing)
                                    .placeholder(when: text.isEmpty) {
                                        Text("Paste your legal text, footnotes, or bibliography here for a rigourous OSCOLA audit...")
                                            .font(Theme.Fonts.inter(size: 16))
                                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.4))
                                    }
                                
                                if !text.isEmpty && !isProcessing {
                                    HStack {
                                        Spacer()
                                        Text("\(text.count) characters")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                                    }
                                    .padding(.top, 8)
                                }
                            }
                        }
                        
                        // Premium Scanning Animation
                        if isProcessing {
                            OSCOLAScanOverlay()
                                .transition(.opacity)
                        }
                    }
                    .padding(24)
                    .background(Theme.Colors.surface)
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(isProcessing ? Theme.Colors.accent.opacity(0.5) : Theme.Colors.glassBorder, lineWidth: 1)
                    )
                    .shadow(color: isProcessing ? Theme.Colors.accent.opacity(0.1) : Color.clear, radius: 20, x: 0, y: 10)
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)
                
                // Beginner Friendly Reference Footer
                VStack(alignment: .leading, spacing: 16) {
                    Text("OSCOLA QUICK REFERENCE")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.horizontal, 32)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            OSCOLATipCard(title: "Case Law", example: "Donoghue v Stevenson [1932] AC 562", rule: "No punctuation in case names.")
                            OSCOLATipCard(title: "Statutes", example: "Human Rights Act 1998", rule: "Year follows title directly.")
                            OSCOLATipCard(title: "Journals", example: "J Griffiths, 'The Politics of the Judiciary' (1985) 48 MLR 125", rule: "Authors in Roman style.")
                        }
                        .padding(.horizontal, 32)
                    }
                }
                .padding(.top, 32)
                
                Spacer()
                
                // Audit controls
                VStack(spacing: 16) {
                    Button {
                        audit()
                    } label: {
                        HStack {
                            if isProcessing {
                            ProgressView().tint(Theme.Colors.onAccent)
                            } else {
                                Image(systemName: "text.magnifyingglass")
                                Text("Execute Rigourous Audit")
                            }
                        }
                        .font(Theme.Fonts.outfit(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(text.isEmpty ? Color.gray.opacity(0.5) : Theme.Colors.accent)
                        .cornerRadius(12)
                    }
                    .disabled(text.isEmpty || isProcessing)
                    
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Detailed corrections and highlighted inaccuracies will be provided.")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(32)
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.pdf, .presentation, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        .sheet(isPresented: $showingFeedback) {
            OSCOLAReportView(feedback: feedback)
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isExtracting = true
            Task {
                if let text = NoteProcessingService.shared.extractText(from: url) {
                    await MainActor.run {
                        self.text = text
                        self.isExtracting = false
                    }
                } else {
                    await MainActor.run { self.isExtracting = false }
                }
            }
        case .failure:
            break
        }
    }
    
    func audit() {
        isProcessing = true
        Task {
            do {
                let context: [String: Any] = [
                    "type": "OSCOLA_AUDIT",
                    "system": "You are a Legal Citations Expert (OSCOLA 4th Ed). Audit the provided text for citation errors. For every error:\n1. List the inaccurate citation.\n2. State the exact OSCOLA rule it violates.\n3. Provides the corrected version.\nUse markdown headers (###) and bolding (**text**) for clarity. Be extremely pedantic about punctuation and italics."
                ]
                
                let (response, _) = try await AIService.shared.callAI(tool: .audit, content: text, context: context)
                await MainActor.run {
                    self.feedback = response
                    self.isProcessing = false
                    self.showingFeedback = true
                }
            } catch {
                await MainActor.run { isProcessing = false }
            }
        }
    }
}

// MARK: - Premium UI Components

struct OSCOLAScanOverlay: View {
    @State private var scanPos: CGFloat = -0.5
    
    var body: some View {
        ZStack {
            Theme.Colors.accent.opacity(0.02)
            
            GeometryReader { geo in
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Theme.Colors.accent.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(height: 100)
                    .offset(y: scanPos * geo.size.height)
                    .onAppear {
                        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                            scanPos = 1.2
                        }
                    }
            }
            
            VStack(spacing: 12) {
                ProgressView()
                    .tint(Theme.Colors.accent)
                Text("Synthesizing OSCOLA Rules...")
                    .font(Theme.Fonts.outfit(size: 12, weight: .bold))
                    .foregroundColor(Theme.Colors.accent)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct OSCOLATipCard: View {
    let title: String
    let example: String
    let rule: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.Fonts.outfit(size: 12, weight: .bold))
                .foregroundColor(Theme.Colors.accent)
            
            Text(example)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)
            
            Text(rule)
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textSecondary)
                .lineLimit(2)
        }
        .padding(16)
        .frame(width: 220, height: 100, alignment: .leading)
        .background(Theme.Colors.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder, lineWidth: 1))
    }
}

struct OSCOLAReportView: View {
    let feedback: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("Audit Complete")
                                .font(Theme.Fonts.outfit(size: 14, weight: .bold))
                                .foregroundColor(.green)
                        }
                        
                        Text("Accuracy Report")
                            .font(Theme.Fonts.outfit(size: 32, weight: .bold))
                        
                        Text("We've audited your citations against the OSCOLA 4th Edition standard.")
                            .font(Theme.Fonts.inter(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    
                    MarkdownText(text: feedback)
                        .padding(24)
                        .background(Theme.Colors.surface)
                        .cornerRadius(24)
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                }
                .padding(32)
            }
            .background(Theme.Colors.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Acknowledge") { dismiss() }
                        .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                }
            }
        }
    }
}
