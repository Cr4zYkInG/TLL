import SwiftUI
import UniformTypeIdentifiers

struct EssayMarkingView: View {
    @State private var essay = ""
    @State private var isMarking = false
    @State private var result = ""
    @State private var showingResult = false
    @State private var showingSubmitConfirmation = false
    @EnvironmentObject var authState: AuthState
    
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
                            Text("Essay Marking")
                                .font(Theme.Fonts.outfit(size: 28, weight: .bold))
                            Text("Get holistic academic feedback on your legal writing.")
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
                        ProgressView("Analyzing essay structure...")
                    } else {
                        TextEditor(text: $essay)
                            .font(Theme.Fonts.inter(size: 16))
                            .padding()
                            .background(Theme.Colors.surface)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                            .placeholder(when: essay.isEmpty) {
                                Text("Paste your legal essay here or upload a Word/PDF document...")
                                    .padding(20)
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.4))
                            }
                    }
                }
                .padding(.horizontal)
                
                Button {
                    Theme.HapticFeedback.heavy()
                    showingSubmitConfirmation = true
                } label: {
                    HStack {
                        if isMarking {
                            ProgressView().tint(Theme.Colors.onAccent)
                        } else {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Commence Holistic Marking")
                        }
                    }
                    .font(Theme.Fonts.outfit(size: 18, weight: .bold))
                    .foregroundColor(Theme.Colors.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(essay.isEmpty ? Color.gray.opacity(0.3) : Theme.Colors.accent)
                    .cornerRadius(16)
                }
                .disabled(essay.isEmpty || isMarking)
                .alert("Submit for Evaluation?", isPresented: $showingSubmitConfirmation) {
                    Button("Confirm", role: .none) { mark() }
                    Button("Review Again", role: .cancel) { }
                } message: {
                    Text("Your essay will be evaluated against flagship academic rubrics. This action consumes 250 AI credits.")
                }
                .padding(.horizontal)
                // Rubric Insights (Beginner Friendly)
                VStack(alignment: .leading, spacing: 16) {
                    Text("ACADEMIC RUBRIC INSIGHTS")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            RubricCard(title: "AO1: Knowledge", description: "Recall of legal principles and accurate statute/case references.")
                            RubricCard(title: "AO2: Application", description: "Applying law to facts using IRAC/ILAC logic.")
                            RubricCard(title: "AO3: Analysis", description: "Critical evaluation, contrasting authorities, and conclusions.")
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                
                Spacer()
                
                Button {
                    mark()
                } label: {
                    HStack {
                        if isMarking {
                            ProgressView().tint(Theme.Colors.onAccent)
                        } else {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Commence Holistic Marking")
                        }
                    }
                    .font(Theme.Fonts.outfit(size: 18, weight: .bold))
                    .foregroundColor(Theme.Colors.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(essay.isEmpty ? Color.gray.opacity(0.3) : Theme.Colors.accent)
                    .cornerRadius(16)
                }
                .disabled(essay.isEmpty || isMarking)
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
            EssayMarkingReportView(result: result)
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
                        self.essay = text
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
    
    func mark() {
        isMarking = true
        Task {
            do {
                let context: [String: Any] = [
                    "type": "ESSAY_MARKING",
                    "status": authState.currentUser?.currentStatus ?? "llb",
                    "board": authState.currentUser?.examBoard ?? "aqa",
                    "system": "You are a Senior Academic Marker. Provide a holistic assessment of this legal essay. If the user is LLB, focus on criticality and OSCOLA. If A-Level, focus on AQA/OCR AO1-3 rubrics. Provide a grade and clear advice."
                ]
                let (response, _) = try await AIService.shared.callAI(tool: .mark, content: essay, context: context)
                await MainActor.run {
                    self.result = response
                    self.isMarking = false
                    self.showingResult = true
                }
            } catch {
                await MainActor.run { isMarking = false }
            }
        }
    }
}
// MARK: - Premium UI Components

struct RubricCard: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.Fonts.outfit(size: 12, weight: .bold))
                .foregroundColor(Theme.Colors.accent)
            
            Text(description)
                .font(.system(size: 11))
                .foregroundColor(Theme.Colors.textSecondary)
                .lineLimit(3)
        }
        .padding(16)
        .frame(width: 200, height: 90, alignment: .leading)
        .background(Theme.Colors.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder, lineWidth: 1))
    }
}

struct EssayMarkingReportView: View {
    let result: String
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authState: AuthState

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    PremiumMarkingReportView(
                        reportText: result,
                        examBoard: authState.currentUser?.examBoard
                    )
                    .padding(.vertical, 32)
                }
            }
            .background(Theme.Colors.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                }
            }
            .navigationTitle("Marking Report")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
