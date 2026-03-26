import SwiftUI
import UniformTypeIdentifiers

struct IssueSpotterView: View {
    @State private var scenario = ""
    @State private var isAnalyzing = false
    @State private var showingFeedback = false
    @State private var feedback = ""
    
    // File Upload
    @State private var showingFilePicker = false
    @State private var isExtracting = false
    
    var body: some View {
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Investigative Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.Colors.accent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Legal Issue Spotter")
                                .font(Theme.Fonts.outfit(size: 28, weight: .bold))
                            Text("Dossier Analysis Mode")
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(Theme.Colors.accent)
                        }
                    }
                    
                    Text("Drop your complex fact pattern or upload a case file. Our AI will conduct a thorough investigation to spot hidden legal issues.")
                        .font(Theme.Fonts.inter(size: 14))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                }
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Dossier Input Area
                VStack(spacing: 20) {
                    HStack {
                        Label("FACT PATTERN / EVIDENCE", systemImage: "text.justify.left")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        Spacer()
                        
                        Button {
                            showingFilePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "paperclip")
                                Text("Attach Document")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.surface)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                        }
                    }
                    
                    ZStack {
                        if isExtracting {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .tint(Theme.Colors.accent)
                                Text("Scanning document for legal issues...")
                                    .font(Theme.Fonts.inter(size: 14))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            TextEditor(text: $scenario)
                                .font(Theme.Fonts.inter(size: 16))
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .placeholder(when: scenario.isEmpty) {
                                    Text("Enter the complex scenario here. Include all relevant facts, names, and dates...")
                                        .font(Theme.Fonts.inter(size: 16))
                                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.4))
                                }
                        }
                    }
                    .padding(24)
                    .background(Theme.Colors.surface.opacity(0.5))
                    .cornerRadius(24)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Action Bar
                VStack(spacing: 16) {
                    Button {
                        analyze()
                    } label: {
                        HStack(spacing: 12) {
                            if isAnalyzing {
                                ProgressView().tint(Theme.Colors.onAccent)
                            } else {
                                Image(systemName: "sparkles")
                                Text("Commence Investigation")
                            }
                        }
                        .font(Theme.Fonts.outfit(size: 18, weight: .bold))
                        .foregroundColor(Theme.Colors.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            LinearGradient(
                                colors: scenario.isEmpty ? [Color.gray.opacity(0.5)] : [Theme.Colors.accent, Theme.Colors.accent.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: scenario.isEmpty ? .clear : Theme.Colors.accent.opacity(0.3), radius: 15, x: 0, y: 8)
                    }
                    .disabled(scenario.isEmpty || isAnalyzing)
                    
                    Text("AI-powered analysis consumes 20 credits per session.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.6))
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
            InvestigationReportView(feedback: feedback)
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
                        self.scenario = text
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
    
    func analyze() {
        isAnalyzing = true
        Task {
            do {
                let context: [String: Any] = [
                    "type": "ISSUE_SPOTTING",
                    "id": UUID().uuidString,
                    "system": "You are a Legal Investigative Expert. Spot every legal issue in the provided scenario. For each issue: Identify the ISSUE, state the RULE, apply the ANALYSIS, and give a preliminary CONCLUSION (IRAC). Be thorough and exhaustive."
                ]
                
                let (response, _) = try await AIService.shared.callAI(tool: .interpret, content: scenario, context: context)
                
                await MainActor.run {
                    self.feedback = response
                    self.isAnalyzing = false
                    self.showingFeedback = true
                }
            } catch {
                await MainActor.run { isAnalyzing = false }
            }
        }
    }
}

struct InvestigationReportView: View {
    let feedback: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Report Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Investigation Report")
                                .font(Theme.Fonts.outfit(size: 24, weight: .bold))
                            Text("Ref: \(Date().formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.Colors.accent)
                    }
                    .padding(.bottom, 12)
                    
                    MarkdownText(text: feedback)
                }
                .padding(32)
            }
            .background(Theme.Colors.bg)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close File") { dismiss() }
                        .font(.system(size: 16, weight: .bold))
                }
            }
        }
    }
}
