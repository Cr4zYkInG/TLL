import SwiftUI
import UniformTypeIdentifiers

struct InterpretAIView: View {
    @State private var query = ""
    @State private var isInterpreting = false
    @State private var result = ""
    @State private var showingResult = false
    
    // File Upload
    @State private var showingFilePicker = false
    @State private var isExtracting = false
    
    var body: some View {
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Interpret AI")
                                .font(Theme.Fonts.outfit(size: 28, weight: .bold))
                            Text("Translate complex legalese into plain English.")
                                .font(Theme.Fonts.inter(size: 14))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        Button {
                            showingFilePicker = true
                        } label: {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 20))
                                .foregroundColor(Theme.Colors.accent)
                        }
                    }
                }
                .padding(.horizontal)
                
                ZStack {
                    if isExtracting {
                        ProgressView("Extracting legalese...")
                    } else {
                        TextEditor(text: $query)
                            .font(Theme.Fonts.inter(size: 16))
                            .padding()
                            .background(Theme.Colors.surface)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                            .placeholder(when: query.isEmpty) {
                                Text("Paste legalese here or upload a contract PDF...")
                                    .padding(20)
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.4))
                            }
                    }
                    
                    if isInterpreting {
                        InterpretScanOverlay()
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal)
                
                Button {
                    interpret()
                } label: {
                    HStack {
                        if isInterpreting {
                            ProgressView().tint(Theme.Colors.onAccent)
                        } else {
                            Image(systemName: "sparkles")
                            Text("Simplify")
                        }
                    }
                    .font(Theme.Fonts.outfit(size: 18, weight: .bold))
                    .foregroundColor(Theme.Colors.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(query.isEmpty ? Color.gray.opacity(0.3) : Theme.Colors.accent)
                    .cornerRadius(16)
                }
                .disabled(query.isEmpty || isInterpreting)
                .padding(.horizontal)
                
                // Beginner Friendly Context
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Tip: Use this for complex contract clauses or archaic judicial reasoning.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.pdf, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        .navigationTitle("")
        .sheet(isPresented: $showingResult) {
            InterpretReportView(original: query, result: result)
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
                        self.query = text
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
    
    func interpret() {
        isInterpreting = true
        Task {
            do {
                let context: [String: Any] = [
                    "system": "You are a Legal Translator. Explain the provided legalese in plain, simple English that a student can easily understand. Retain the core legal meaning but remove unnecessary complexity."
                ]
                let (response, _) = try await AIService.shared.callAI(tool: .summarize, content: query, context: context)
                await MainActor.run {
                    self.result = response
                    self.isInterpreting = false
                    self.showingResult = true
                }
            } catch {
                await MainActor.run { isInterpreting = false }
            }
        }
    }
}
// MARK: - Premium UI Components

struct InterpretScanOverlay: View {
    @State private var scanPos: CGFloat = -0.5
    
    var body: some View {
        ZStack {
            Theme.Colors.accent.opacity(0.02)
            
            GeometryReader { geo in
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Theme.Colors.accent.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(height: 80)
                    .offset(y: scanPos * geo.size.height)
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            scanPos = 1.2
                        }
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct InterpretReportView: View {
    let original: String
    let result: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(Theme.Colors.accent)
                            Text("Interpretation Suite")
                                .font(Theme.Fonts.outfit(size: 14, weight: .bold))
                                .foregroundColor(Theme.Colors.accent)
                        }
                        
                        Text("Legalese Unpacked")
                            .font(Theme.Fonts.outfit(size: 32, weight: .bold))
                        
                        Text("Complex legal jargon simplified for immediate understanding.")
                            .font(Theme.Fonts.inter(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("SIMPLIFIED INSIGHT")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(Theme.Colors.accent)
                        
                        MarkdownText(text: result)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.surface)
                    .cornerRadius(24)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.Colors.accent.opacity(0.2), lineWidth: 1))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ORIGINAL SOURCE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        Text(original)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .lineLimit(10)
                            .padding(20)
                            .background(Theme.Colors.surface.opacity(0.5))
                            .cornerRadius(16)
                    }
                }
                .padding(32)
            }
            .background(Theme.Colors.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                }
            }
        }
    }
}
