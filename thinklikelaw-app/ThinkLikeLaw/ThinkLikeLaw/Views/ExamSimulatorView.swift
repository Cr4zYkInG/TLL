import SwiftUI
import UniformTypeIdentifiers
import Combine

struct ExamSimulatorView: View {
    @EnvironmentObject var authState: AuthState
    @State private var questionText = ""
    @State private var answerText = ""
    @State private var isSimulating = false
    @State private var showingFeedback = false
    @State private var feedback = ""
    @State private var showingSubmitConfirmation = false
    
    @ObservedObject var studyManager = StudySessionManager.shared
    @Environment(\.modelContext) private var modelContext

    
    // Timer State
    @State private var timeRemaining = 3600 // 60 minutes
    @State private var isTimerRunning = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // File Upload
    @State private var showingFilePicker = false
    @State private var isExtracting = false
    
    #if os(iOS)
    @Environment(\.verticalSizeClass) var verticalSizeClass
    #endif
    
    var body: some View {
        #if os(iOS)
        let isLandscape = verticalSizeClass == .compact
        #else
        let isLandscape = false
        #endif
        
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Bespoke Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Timed Exam Simulator")
                            .font(Theme.Fonts.outfit(size: isLandscape ? 18 : 24, weight: .bold))
                        if !isLandscape {
                            HStack {
                                Circle().fill(isTimerRunning ? Color.green : Color.red).frame(width: 8, height: 8)
                                Text(isTimerRunning ? "Exam in Progress" : "Awaiting Commencement")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Countdown Widget
                    HStack(spacing: 12) {
                        Image(systemName: "timer")
                            .font(.system(size: isLandscape ? 16 : 20))
                        Text(timeString(from: timeRemaining))
                            .font(.system(size: isLandscape ? 18 : 24, weight: .black, design: .monospaced))
                    }
                    .padding(.horizontal, isLandscape ? 12 : 20)
                    .padding(.vertical, isLandscape ? 6 : 10)
                    .background(Theme.Colors.surface)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                }
                .padding(isLandscape ? 12 : 24)
                
                // Split Screen Area
                let stackContent = Group {
                    // Left/Top: The Problem Question
                    VStack(alignment: .leading, spacing: isLandscape ? 8 : 16) {
                        HStack {
                            Text("PROBLEM QUESTION")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.Colors.textSecondary)
                            Spacer()
                            if !isLandscape {
                                Button {
                                    showingFilePicker = true
                                } label: {
                                    Label("Upload PDF", systemImage: "doc.badge.plus")
                                        .font(.system(size: 12, weight: .bold))
                                }
                            }
                        }
                        
                        if isExtracting {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            TextEditor(text: $questionText)
                                .font(Theme.Fonts.playfair(size: isLandscape ? 14 : 18))
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                                .placeholder(when: questionText.isEmpty) {
                                    Text("Scenario...")
                                        .font(Theme.Fonts.playfair(size: isLandscape ? 14 : 18))
                                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                                }
                        }
                    }
                    .padding(isLandscape ? 12 : (Theme.isPhone ? 16 : 24))
                    .background(Theme.Colors.surface.opacity(0.3))
                    
                    if Theme.isPhone && !isLandscape {
                        Divider().background(Theme.Colors.glassBorder)
                    } else {
                        Divider().background(Theme.Colors.glassBorder)
                    }
                    
                    // Right/Bottom: Your Answer (IRAC)
                    VStack(alignment: .leading, spacing: isLandscape ? 8 : 16) {
                        Text("YOUR RESPONSE (IRAC)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        #if os(iOS)
                        let editorFont = UIFont(name: "Inter-Regular", size: isLandscape ? 14 : 16) ?? .systemFont(ofSize: isLandscape ? 14 : 16)
                        #else
                        let editorFont = Font.custom("Inter-Regular", size: isLandscape ? 14 : 16)
                        #endif
                        
                        TextViewWrapper(
                            placeholder: "Structure your response using IRAC (Issue, Rule, Application, Conclusion)...",
                            text: $answerText,
                            isEditingEnabled: isTimerRunning,
                            font: editorFont
                        )
                        .background(Color.clear)
                        
                        if !isTimerRunning && answerText.isEmpty {
                            Text("⚠️ Start the clock to begin typing.")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Theme.Colors.accent)
                                .transition(.opacity)
                        }
                    }
                    .padding(isLandscape ? 12 : (Theme.isPhone ? 16 : 24))
                }

                if Theme.isPhone && !isLandscape {
                    VStack(spacing: 0) { stackContent }
                } else {
                    HStack(spacing: 2) { stackContent }
                }
                
                // Bottom Control Bar
                HStack(spacing: 20) {
                    Button {
                        isTimerRunning.toggle()
                        Theme.HapticFeedback.medium()
                    } label: {
                        Label(isTimerRunning ? "Pause" : "Start Clock", systemImage: isTimerRunning ? "pause.fill" : "play.fill")
                            .font(Theme.Fonts.outfit(size: 14, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Theme.Colors.surface)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("⚠️ WARNING: One Sitting Session")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.red)
                        Text("Do not close or refresh. Complete in one sitting.")
                            .font(.system(size: 8))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: Theme.isPhone ? 120 : .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    Button {
                        Theme.HapticFeedback.heavy()
                        showingSubmitConfirmation = true
                    } label: {
                        HStack {
                            if isSimulating {
                                ProgressView().tint(Theme.Colors.onAccent)
                            } else {
                                Text(isLandscape ? "Submit" : "Submit for Marking")
                            }
                        }
                        .font(Theme.Fonts.outfit(size: 14, weight: .bold))
                        .foregroundColor(Theme.Colors.onAccent)
                        .padding(.horizontal, isLandscape ? 20 : 40)
                        .padding(.vertical, 10)
                        .background(questionText.isEmpty || answerText.isEmpty ? Color.gray : Theme.Colors.accent)
                        .cornerRadius(100)
                    }
                    .disabled(questionText.isEmpty || answerText.isEmpty || isSimulating)
                    .alert("Submit for Evaluation?", isPresented: $showingSubmitConfirmation) {
                        Button("Confirm", role: .none) { simulate() }
                        Button("Review Again", role: .cancel) { }
                    } message: {
                        Text("Your response will be marked by the Master AI. This action consumes 250 AI credits.")
                    }
                }
                .padding(isLandscape ? 12 : 24)
                .background(Theme.Colors.surface)
                .overlay(Divider(), alignment: .top)
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.pdf, .presentation],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        .onReceive(timer) { _ in
            if isTimerRunning && timeRemaining > 0 {
                timeRemaining -= 1
            }
        }
        .sheet(isPresented: $showingFeedback) {
            ExamFeedbackView(feedback: feedback)
        }
        .onAppear {
            studyManager.startSession(type: "exam", modelContext: modelContext, authState: authState)
        }
        .onDisappear {
            studyManager.stopSession(modelContext: modelContext, authState: authState)
        }
    }
    
    private func timeString(from seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isExtracting = true
            Task {
                if let text = NoteProcessingService.shared.extractText(from: url) {
                    await MainActor.run {
                        self.questionText = text
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
    
    func simulate() {
        isSimulating = true
        isTimerRunning = false
        Task {
            do {
                let context: [String: Any] = [
                    "type": "EXAM_SIMULATION",
                    "id": authState.currentUser?.id ?? "guest",
                    "system": "You are a Senior Law Examiner. Mark this exam answer against the problem question provided. Provide a formal grade (1st, 2.1, etc.) and a detailed IRAC critique. Be rigorous and strictly academic."
                ]
                
                let combinedContent = "PROBLEM QUESTION:\n\(questionText)\n\nSTUDENT ANSWER:\n\(answerText)"
                let (response, _) = try await AIService.shared.callAI(tool: .mark, content: combinedContent, context: context)
                
                await MainActor.run {
                    self.feedback = response
                    self.isSimulating = false
                    self.showingFeedback = true
                }
            } catch {
                await MainActor.run { isSimulating = false }
            }
        }
    }
}

struct ExamFeedbackView: View {
    let feedback: String
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authState: AuthState
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    PremiumMarkingReportView(
                        reportText: feedback,
                        examBoard: authState.currentUser?.examBoard
                    )
                    .padding(.vertical, 32)
                }
            }
            .background(Theme.Colors.bg.ignoresSafeArea())
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

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .topLeading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
