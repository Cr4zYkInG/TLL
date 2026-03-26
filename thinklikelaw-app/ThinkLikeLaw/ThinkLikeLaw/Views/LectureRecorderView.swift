import SwiftUI
import Speech
import SwiftData

struct LectureRecorderView: View {
    @StateObject private var dictationService = DictationService.shared
    @EnvironmentObject var authState: AuthState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersistedModule.name) var modules: [PersistedModule]
    
    @State private var showingSaveSheet = false
    @State private var lectureTitle = ""
    @State private var selectedModuleId: String = ""
    @State private var isProcessingAI = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lecture Recorder")
                        .font(Theme.Fonts.outfit(size: 28, weight: .bold))
                    Text("High-fidelity acoustic capture & transcription")
                        .font(Theme.Fonts.inter(size: 14))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 10))
                        Text("For maximum accuracy, please sit towards the speaker/lecturer.")
                            .font(Theme.Fonts.inter(size: 11, weight: .medium))
                    }
                    .foregroundColor(Theme.Colors.accent)
                    .padding(.top, 4)
                }
                Spacer()
                
                if dictationService.isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("REC")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(24)
            
            Spacer()
            
            // Central Waveform / Visualizer
            ZStack {
                // Background Glow
                Circle()
                    .fill(Theme.Colors.accent.opacity(0.05))
                    .frame(width: 300, height: 300)
                    .blur(radius: 50)
                
                // Animated Waveform
                HStack(spacing: 4) {
                    ForEach(0..<40) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(dictationService.isRecording ? Theme.Colors.accent : Theme.Colors.textSecondary.opacity(0.2))
                            .frame(width: 4, height: waveHeight(for: i))
                            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: dictationService.audioPower)
                    }
                }
            }
            .frame(height: 300)
            
            Spacer()
            
            // Live Transcript Section
            VStack(alignment: .leading, spacing: 12) {
                Text("LIVE TRANSCRIPT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                ScrollView {
                    Text(dictationService.transcript.isEmpty ? "Start recording to see live legal transcription..." : dictationService.transcript)
                        .font(Theme.Fonts.inter(size: 16))
                        .foregroundColor(dictationService.transcript.isEmpty ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                .frame(height: 120)
                .padding()
                .background(Theme.Colors.surface)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder, lineWidth: 1))
            }
            .padding(.horizontal, 24)
            
            // Controls
            HStack(spacing: 24) {
                if !dictationService.isRecording && !dictationService.transcript.isEmpty {
                    Button(action: { showingSaveSheet = true }) {
                        Label("Save as Note", systemImage: "square.and.arrow.down.fill")
                            .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                            .foregroundColor(Theme.Colors.onAccent)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Theme.Colors.accent)
                            .cornerRadius(100)
                    }
                }
                
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(dictationService.isRecording ? .red : Theme.Colors.accent)
                            .frame(width: 72, height: 72)
                        
                        Image(systemName: dictationService.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Theme.Colors.onAccent)
                    }
                    .shadow(color: (dictationService.isRecording ? Color.red : Theme.Colors.accent).opacity(0.3), radius: 15, y: 5)
                }
                
                if !dictationService.isRecording && !dictationService.transcript.isEmpty {
                    Button(action: { dictationService.transcript = "" }) {
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                            .padding(16)
                            .background(.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.vertical, 40)
        }
        .background(Theme.Colors.bg.ignoresSafeArea())
        .sheet(isPresented: $showingSaveSheet) {
            saveLectureSheet
        }
    }
    
    private var saveLectureSheet: some View {
        NavigationStack {
            Form {
                Section("Lecture Details") {
                    TextField("Lecture Title", text: $lectureTitle)
                }
                
                Section("Module Selection") {
                    Picker("Select Module", selection: $selectedModuleId) {
                        Text("Uncategorized").tag("")
                        ForEach(modules) { module in
                            Text(module.name).tag(module.id)
                        }
                    }
                }
                
                Section {
                    Button(action: saveLecture) {
                        if isProcessingAI {
                            ProgressView()
                        } else {
                            Text("Process & Save with AI")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(lectureTitle.isEmpty || isProcessingAI)
                }
            }
            .navigationTitle("Save Lecture")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingSaveSheet = false }
                }
            }
        }
    }
    
    private func waveHeight(for index: Int) -> CGFloat {
        if !dictationService.isRecording { return 10 }
        let baseHeight: CGFloat = 10
        let modifier = CGFloat(dictationService.audioPower * 500)
        let randomness = CGFloat.random(in: 0.5...1.5)
        return min(100, baseHeight + modifier * randomness)
    }
    
    private func toggleRecording() {
        if dictationService.isRecording {
            dictationService.stopRecording()
        } else {
            // Request permissions first
            SFSpeechRecognizer.requestAuthorization { status in
                if status == .authorized {
                    AVAudioApplication.requestRecordPermission { granted in
                        if granted {
                            DispatchQueue.main.async {
                                try? dictationService.startRecording()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func saveLecture() {
        isProcessingAI = true
        
        let transcriptJson = try? JSONEncoder().encode(dictationService.segments)
        let audioUrlString = dictationService.getAudioURL()?.absoluteString
        
        Task {
            do {
                // 1. Call AI to summarize the transcript
                let (summarizedBrief, _) = try await AIService.shared.callAI(tool: .generate_notes, content: dictationService.transcript)
                
                await MainActor.run {
                    // 2. Save to SwiftData
                    let newNote = PersistedNote(
                        id: UUID().uuidString,
                        title: lectureTitle,
                        content: summarizedBrief,
                        preview: summarizedBrief.prefix(150).description
                    )
                    
                    // Link to module if selected
                    if !selectedModuleId.isEmpty {
                        if let module = modules.first(where: { $0.id == selectedModuleId }) {
                            newNote.module = module
                        }
                    }
                    
                    newNote.audioUrl = audioUrlString
                    newNote.transcriptSegments = transcriptJson
                    
                    modelContext.insert(newNote)
                    try? modelContext.save()
                    
                    // 3. Clear and Close
                    dictationService.transcript = ""
                    lectureTitle = ""
                    isProcessingAI = false
                    showingSaveSheet = false
                }
            } catch {
                print("LectureRecorder: AI Processing failed -> \(error)")
                await MainActor.run {
                    isProcessingAI = false
                }
            }
        }
    }
}
