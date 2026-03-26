import SwiftUI

struct CitationPopupView: View {
    let citation: String
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = true
    @State private var tnaCase: TNACase?
    @State private var ratioText: String = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.bg.ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Grounding with TNA...")
                        .tint(Theme.Colors.accent)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .font(Theme.Fonts.inter(size: 16))
                            .multilineTextAlignment(.center)
                        Button("Dismiss") { dismiss() }
                            .buttonStyle(.bordered)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header Card
                            VStack(alignment: .leading, spacing: 8) {
                                Text(tnaCase?.title ?? "Unknown Case")
                                    .font(Theme.Fonts.outfit(size: Theme.isPhone ? 18 : 22, weight: .bold))
                                    .foregroundColor(Theme.Colors.accent)
                                
                                HStack {
                                    Text(tnaCase?.ncn ?? citation)
                                        .font(.system(size: Theme.isPhone ? 12 : 14, weight: .bold, design: .monospaced))
                                    Spacer()
                                    Text(tnaCase?.court ?? "")
                                        .font(Theme.Fonts.inter(size: 10, weight: .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Theme.Colors.accent.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                            .padding()
                            .background(Theme.Colors.surface)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                            
                            // Ratio Decidendi Section
                            VStack(alignment: .leading, spacing: 12) {
                                Label("RATIO DECIDENDI", systemImage: "brain.head.profile/")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                
                                Text(ratioText)
                                    .font(Theme.Fonts.inter(size: Theme.isPhone ? 14 : 16))
                                    .lineSpacing(4)
                            }
                            .padding()
                            .background(Theme.Colors.surface)
                            .cornerRadius(16)
                            
                            // Official Link
                            if let link = tnaCase?.link {
                                Link(destination: URL(string: link)!) {
                                    HStack {
                                        Image(systemName: "link.circle.fill")
                                        Text("View Official Judgment (TNA)")
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                    }
                                    .font(Theme.Fonts.inter(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Theme.Colors.accent)
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(24)
                    }
                }
            }
            .navigationTitle("Legal Grounding")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }
            .onAppear {
                loadLegalData()
            }
        }
    }
    
    private func loadLegalData() {
        Task {
            do {
                var data = try await TNAService.shared.getCaseBrief(citation: citation)
                
                // Fallback: If no results for full name, try searching for just the NCN part
                if data == nil {
                    let ncnPattern = "\\[\\d{4}\\]\\s+[A-Z]+(?:\\s+[A-Z]+)?\\s+\\d+"
                    if let ncnRegex = try? NSRegularExpression(pattern: ncnPattern, options: [.caseInsensitive]),
                       let match = ncnRegex.firstMatch(in: citation, options: [], range: NSRange(citation.startIndex..., in: citation)) {
                        let ncn = (citation as NSString).substring(with: match.range)
                        data = try await TNAService.shared.getCaseBrief(citation: ncn)
                    }
                }
                
                guard let finalData = data else {
                    await MainActor.run {
                        self.errorMessage = "Citation '\(citation)' not found in official records."
                        self.isLoading = false
                    }
                    return
                }
                
                await MainActor.run {
                    self.tnaCase = finalData.tnacase
                }
                
                // Now get AI to generate the Ratio grounded in the content
                let prompt = "Explain the Ratio Decidendi of the following case: \(finalData.tnacase.title). Ground your answer strictly in this judgment text: \(finalData.content). Keep it professional and legally rigorous."
                
                let (ratio, _) = try await AIService.shared.callAI(tool: .interpret, content: prompt)
                
                await MainActor.run {
                    self.ratioText = ratio
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to ground legal citation: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}
