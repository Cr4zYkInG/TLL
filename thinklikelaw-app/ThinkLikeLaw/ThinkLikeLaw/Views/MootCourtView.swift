import SwiftUI
import SwiftData
import AVFoundation
import Speech

/**
 * MootCourtView — Voice-driven adversarial legal roleplay with career progression.
 * Scaling from Self-Representation to King's Counsel.
 */
struct MootCourtView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let scenario: String
    let difficulty: MootDifficulty
    let userSide: MootSide
    
    // Core State
    @State private var messages: [MootMessage] = []
    @State private var isListening = false
    @State private var recognizedText = ""
    @State private var isThinking = false
    @State private var score: Double = 0.0
    @State private var isFinished = false
    @State private var verdict: String? = nil
    
    // Speech Properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    @State private var recordingRequest: SFSpeechAudioBufferRecognitionRequest?
    
    // Preparation Phase
    @State private var isPreparing = true
    @State private var prepTimeRemaining = 900 // 15 mins
    @State private var skeletonArguments: [String] = ["", "", ""]
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                if isPreparing {
                    preparationView
                        .transition(.move(edge: .leading))
                } else {
                    trialArenaView
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
                }
            }
            
            if isFinished {
                verdictOverlay
            }
        }
        .onAppear {
            requestPermissions()
            startPrepTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(10)
                    .background(Theme.Colors.surface)
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: difficulty.icon)
                        .foregroundColor(Color(hex: difficulty.color))
                        .font(.system(size: 10))
                    Text(difficulty.rawValue.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(Color(hex: difficulty.color))
                        .tracking(1)
                }
                Text("Supreme Court Trial")
                    .font(Theme.Fonts.outfit(size: 18, weight: .bold))
            }
            Spacer()
            scoreBadge
        }
        .padding()
    }
    
    private var trialArenaView: some View {
        VStack(spacing: 0) {
            // Courtroom Layout (Jury & Bench)
            HStack(spacing: 12) {
                // Jury Box (Reactive)
                VStack(spacing: 4) {
                    Text("JURY BOX")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    HStack(spacing: 4) {
                        ForEach(0..<6) { _ in
                            Circle()
                                .fill(Theme.Colors.accent.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    ProgressView(value: score, total: 100)
                        .tint(.green)
                        .frame(width: 60)
                }
                .padding(10)
                .background(Theme.Colors.surface)
                .cornerRadius(12)
                .glassCard()
                
                Spacer()
                
                // Bench (Judge Ben)
                VStack(spacing: 4) {
                    Image("ben_sitting")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .background(Theme.Colors.surface.opacity(0.8)) // Fallback background
                        .overlay {
                            Image(systemName: "cat.fill") // Symbolic fallback
                                .foregroundColor(Theme.Colors.accent.opacity(0.5))
                                .font(.system(size: 20))
                        }
                        .clipShape(Circle())
                    Text("JUSTICE BEN")
                        .font(.system(size: 8, weight: .black))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            // Arena (Transcript)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(messages) { msg in
                            MootBubble(message: msg)
                                .id(msg.id)
                        }
                        
                        if isThinking {
                            LoadingBubble()
                                .transition(.opacity)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            
            // Voice Controls
            VStack(spacing: 16) {
                if !recognizedText.isEmpty {
                    Text(recognizedText)
                        .font(Theme.Fonts.inter(size: 14, weight: .medium))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding()
                        .background(Theme.Colors.surface.opacity(0.8))
                        .cornerRadius(12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Button {
                    if isListening {
                        stopListening()
                    } else {
                        startListening()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(isListening ? Color.red : Theme.Colors.accent)
                            .frame(width: 80, height: 80)
                            .shadow(color: (isListening ? Color.red : Theme.Colors.accent).opacity(0.3), radius: 20)
                        
                        Image(systemName: isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.Colors.onAccent)
                    }
                }
                .buttonStyle(.plain)
                
                Text(isListening ? "Listening to your argument..." : "Tap to speak your argument...")
                    .font(Theme.Fonts.inter(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.bottom, 40)
        }
    }
    
    private var preparationView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Banner
                VStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.Colors.accent)
                    Text("Pre-Trial Briefing")
                        .font(Theme.Fonts.outfit(size: 24, weight: .bold))
                    Text("Prepare your case carefully for \(difficulty.rawValue) level scrutiny.")
                        .font(Theme.Fonts.inter(size: 14))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Timer Card
                VStack(spacing: 8) {
                    Text(formatTime(prepTimeRemaining))
                        .font(.system(size: 56, weight: .bold, design: .monospaced))
                        .foregroundColor(prepTimeRemaining < 60 ? .red : Theme.Colors.accent)
                    
                    Text("COUNTDOWN TO COMMENCEMENT")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .tracking(2)
                }
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
                .background(Theme.Colors.surface)
                .cornerRadius(24)
                .glassCard()
                
                // Case Brief
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "doc.text.below.ecg.fill")
                            .foregroundColor(Theme.Colors.accent)
                        Text("JUDICIAL BRIEF")
                            .font(.system(size: 12, weight: .black))
                            .tracking(1)
                        Spacer()
                        Button(action: {
                            #if os(iOS)
                            UIPasteboard.general.string = scenario
                            #else
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(scenario, forType: .string)
                            #endif
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.Colors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.Colors.accent.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    
                    Text(scenario)
                        .font(Theme.Fonts.inter(size: 15))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineSpacing(6)
                        .padding()
                        .background(Theme.Colors.bg.opacity(0.5))
                        .cornerRadius(16)
                }
                .padding()
                .background(Theme.Colors.surface.opacity(0.4))
                .cornerRadius(20)
                
                // Skeleton Argument Builder
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "list.bullet.rectangle.portrait.fill")
                            .foregroundColor(Theme.Colors.accent)
                        Text("SKELETON ARGUMENTS")
                            .font(.system(size: 12, weight: .black))
                            .tracking(1)
                        Spacer()
                        Text("+100 XP ADVOCACY BONUS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Text("Draft your three primary legal points. The Presiding Judge will actively interrogate these specific claims.")
                         .font(Theme.Fonts.inter(size: 12))
                         .foregroundColor(Theme.Colors.textSecondary)
                         
                    ForEach(0..<3, id: \.self) { index in
                        TextField("Argument \(index + 1)...", text: Binding(
                            get: { self.skeletonArguments[index] },
                            set: { self.skeletonArguments[index] = $0 }
                        ))
                        .font(Theme.Fonts.inter(size: 14))
                        .padding()
                        .background(Theme.Colors.surface)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                    }
                }
                .padding()
                .background(Theme.Colors.surface.opacity(0.3))
                .cornerRadius(20)
                
                Button(action: { endPrep() }) {
                    HStack {
                        Text("Commence Trial")
                        Image(systemName: "gavel.fill")
                    }
                    .font(Theme.Fonts.outfit(size: 18, weight: .bold))
                    .foregroundColor(Theme.Colors.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(colors: [Theme.Colors.accent, Theme.Colors.accent.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(16)
                    .shadow(color: Theme.Colors.accent.opacity(0.4), radius: 15, y: 8)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal)
        }
    }
    
    private var verdictOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: score >= 70 ? "trophy.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(score >= 70 ? .yellow : .orange)
                
                VStack(spacing: 8) {
                    Text(score >= 70 ? "Case Won" : "Trial Adjourned")
                        .font(Theme.Fonts.outfit(size: 28, weight: .black))
                        .foregroundColor(.white)
                    
                    Text("Final Performance: \(Int(score))%")
                        .font(Theme.Fonts.inter(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                if let verdictText = verdict {
                    ScrollView {
                        Text(verdictText)
                            .font(Theme.Fonts.inter(size: 14))
                            .foregroundColor(.white)
                            .padding()
                    }
                    .frame(maxHeight: 200)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
                }
                
                Button(action: { dismiss() }) {
                    Text("Exit Courtroom")
                        .font(Theme.Fonts.outfit(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(12)
                }
            }
            .padding(32)
            .background(Theme.Colors.surface.opacity(0.2))
            .cornerRadius(32)
            .glassCard()
            .padding(24)
        }
    }
    
    // MARK: - Helper Views
    
    private var scoreBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar.fill")
                .foregroundColor(Theme.Colors.accent)
            Text("\(Int(score))%")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.Colors.surface)
        .cornerRadius(12)
        .glassCard()
    }

    // MARK: - Logic
    
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private func startPrepTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if prepTimeRemaining > 0 {
                prepTimeRemaining -= 1
            } else {
                endPrep()
            }
        }
    }
    
    private func endPrep() {
        timer?.invalidate()
        withAnimation(.spring()) {
            isPreparing = false
        }
        startMoot()
    }
    
    private func startMoot() {
        isThinking = true
        Task {
            do {
                let difficultyContext = getDifficultyContext()
                
                let activeArgs = skeletonArguments.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                var skeletonInjection = ""
                if !activeArgs.isEmpty {
                    let formattedArgs = activeArgs.map { "- \($0)" }.joined(separator: "\n")
                    skeletonInjection = "\nCounsel's pre-submitted Skeleton Arguments:\n\(formattedArgs)\n\nCRITICAL: You MUST specifically challenge and aggressively interrogate ONE of these arguments heavily during this trial."
                }

                let prompt = """
                You are playing a Moot Court simulation at '\(difficulty.rawValue)' difficulty.
                Case Scenario: '\(scenario)'.
                
                USER'S ROLE: \(userSide.rawValue)
                OPPOSING COUNSEL'S ROLE: \(adversarySide)
                
                CONTEXT: \(difficultyContext)
                \(skeletonInjection)
                
                1. Call the Court to order formally.
                2. State the facts briefly from a neutral judicial perspective.
                Maintain Ben's mascot identity but adapt your judicial quality to the difficulty.
                """
                let (response, _) = try await AIService.shared.callAI(
                    tool: .moot_trial, 
                    content: prompt,
                    context: ["difficulty": difficulty.rawValue, "side": userSide.rawValue]
                )
                
                await MainActor.run {
                    appendAdversarialResponse(response)
                    isThinking = false
                }
            } catch {
                isThinking = false
            }
        }
    }
    
    private var adversarySide: String {
        userSide == .claimant ? "Respondent" : "Claimant"
    }
    
    private func submitArgument() {
        guard !recognizedText.isEmpty else { return }
        let argument = recognizedText
        messages.append(MootMessage(text: argument, type: .user))
        recognizedText = ""
        
        // Final Trial End Condition (Turn count)
        if messages.count > 10 {
            requestVerdict()
            return
        }
        
        isThinking = true
        Task {
            do {
                let difficultyContext = getDifficultyContext()
                let prompt = """
                Counsel for the \(userSide.rawValue) (the user) has submitted: '\(argument)'. 
                Difficulty Level: \(difficulty.rawValue).
                
                ADVERSARIAL BEHAVIOR: \(difficultyContext)
                
                1. Mr. Adversary (Counsel for the \(adversarySide)) MUST react first with a sharp legal rebuttal, objection, or counter-point based on the laws/precedents in the scenario.
                2. Justice Ben (Judge) then intervenes to either sustain the objection, ask a probing question to the user, or move the trial forward.
                
                IMPORTANT: Format the response clearly as:
                [ADVERSARY]: ...
                [JUDGE]: ...
                
                Include performance score at end as [SCORE: X].
                """
                let (response, _) = try await AIService.shared.callAI(
                    tool: .moot_trial, 
                    content: prompt,
                    context: ["difficulty": difficulty.rawValue, "side": userSide.rawValue]
                )
                
                await MainActor.run {
                    appendAdversarialResponse(response)
                    isThinking = false
                    extractScore(from: response)
                }
            } catch {
                isThinking = false
            }
        }
    }
    
    private func appendAdversarialResponse(_ response: String) {
        // Remove the score tag from the text displayed in bubbles
        let cleanResponse = response.replacingOccurrences(of: "\\[SCORE: \\d+\\]", with: "", options: .regularExpression)
        
        let adversaryTag = "[ADVERSARY]:"
        let judgeTag = "[JUDGE]:"
        
        var segments: [(type: MootParticipant, text: String)] = []
        
        // Split by tags
        let lines = cleanResponse.components(separatedBy: "\n")
        var currentRole: MootParticipant = .judge
        var currentText = ""
        
        for line in lines {
            if line.contains(adversaryTag) {
                if !currentText.isEmpty { segments.append((currentRole, currentText.trimmingCharacters(in: .whitespacesAndNewlines))) }
                currentRole = .adversary
                currentText = line.replacingOccurrences(of: adversaryTag, with: "")
            } else if line.contains(judgeTag) {
                if !currentText.isEmpty { segments.append((currentRole, currentText.trimmingCharacters(in: .whitespacesAndNewlines))) }
                currentRole = .judge
                currentText = line.replacingOccurrences(of: judgeTag, with: "")
            } else {
                currentText += "\n" + line
            }
        }
        
        if !currentText.isEmpty {
            segments.append((currentRole, currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        
        // If no tags were found, treat it as a single judge message
        if segments.isEmpty {
            segments.append((.judge, cleanResponse))
        }
        
        // Add with slight delays for "presence"
        Task {
            for (index, segment) in segments.enumerated() {
                if index > 0 { try? await Task.sleep(nanoseconds: 800_000_000) }
                await MainActor.run {
                    messages.append(MootMessage(text: segment.text, type: segment.type))
                    speak(segment.text)
                }
            }
        }
    }
    
    private func requestVerdict() {
        isThinking = true
        Task {
            do {
                let prompt = "The trial has concluded. Based on Counsel's performance and a final score of \(Int(score)), provide a final Judicial Verdict and summary. Be decisive."
                let (response, _) = try await AIService.shared.callAI(tool: .moot_trial, content: prompt)
                
                await MainActor.run {
                    self.verdict = response
                    self.isFinished = true
                    self.isThinking = false
                    saveMootResult()
                }
            } catch {
                isThinking = false
            }
        }
    }
    
    private func saveMootResult() {
        let result = PersistedMootResult(
            scenario: scenario,
            difficulty: difficulty.rawValue,
            score: score,
            isWin: score >= 70,
            transcript: messages.map { "\($0.type): \($0.text)" }.joined(separator: "\n\n")
        )
        modelContext.insert(result)
        try? modelContext.save()
        
        // Award XP based on win/participation
        XPService.shared.addXP(result.isWin ? .mootWin(difficulty: difficulty.rawValue) : .mootParticipation(difficulty: difficulty.rawValue))
        
        // Advocacy Bonus
        let activeArgs = skeletonArguments.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if !activeArgs.isEmpty {
            XPService.shared.addXP(.mootPrepBonus)
        }
    }
    
    private func getDifficultyContext() -> String {
        switch difficulty {
        case .selfRep:
            return "Self-Rep Mode: Ben is extremely lenient and fatherly. Mr. Adversary is incompetent and makes joking objections. User doesn't need to be professional."
        case .graduate:
            return "Graduate Mode: Standards are higher. Focus on IRAC and statutory references. Ben is inquisitive but helpful."
        case .lawyer:
            return "Seasoned Lawyer Mode: Stern courtroom atmosphere. Ben will interrupt weak arguments. Mr. Adversary is aggressive and uses complex case law."
        case .kc:
            return "King's Counsel Mode: Elite technicality. Ben only accepts high-level legal reasoning (OSCOLA). Mr. Adversary is brilliantly obstructive. One mistake leads to an objection."
        }
    }
    
    private func extractScore(from response: String) {
        let pattern = "\\[SCORE: (\\d+)\\]"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)) {
            if let scoreRange = Range(match.range(at: 1), in: response),
               let newScore = Double(response[scoreRange]) {
                withAnimation { self.score = newScore }
            }
        }
    }
    
    // MARK: - Speech Engine
    
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        #if os(iOS)
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { _ in }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        }
        #endif
    }
    
    private func startListening() {
        audioEngine.stop()
        recognitionTask?.cancel()
        
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            #endif
            
            let request = SFSpeechAudioBufferRecognitionRequest()
            let inputNode = audioEngine.inputNode
            
            recordingRequest = request
            
            inputNode.removeTap(onBus: 0)
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self.stopListening()
                }
            }
            
            isListening = true
        } catch {
            isListening = false
        }
    }
    
    private func stopListening() {
        audioEngine.stop()
        recordingRequest?.endAudio()
        recognitionTask?.cancel()
        isListening = false
        submitArgument()
    }
    
    private func speak(_ text: String) {
        let utterance = VoiceService.shared.createUtterance(text: text)
        synthesizer.speak(utterance)
    }
}

// MARK: - Models & Components

enum MootParticipant {
    case user
    case judge
    case adversary
}

struct MootMessage: Identifiable {
    let id = UUID()
    let text: String
    let type: MootParticipant
}

struct MootBubble: View {
    let message: MootMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.type == .user { Spacer() }
            
            if message.type != .user {
                badgeIcon
            }
            
            VStack(alignment: message.type == .user ? .trailing : .leading, spacing: 4) {
                Text(participantName)
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Text(message.text)
                    .font(Theme.Fonts.inter(size: 15))
                    .padding(16)
                    .background(bubbleColor)
                    .foregroundColor(textColor)
                    .cornerRadius(20)
                    .glassCard()
            }
            
            if message.type != .user { Spacer() }
        }
    }
    
    private var participantName: String {
        switch message.type {
        case .user: return "YOU (COUNSEL)"
        case .judge: return "JUSTICE BEN"
        case .adversary: return "MR. ADVERSARY"
        }
    }
    
    private var badgeIcon: some View {
        ZStack {
            Circle()
                .fill(Theme.Colors.surface)
                .frame(width: 36, height: 36)
                .glassCard()
            
            if message.type == .judge {
                Image("ben_sitting")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 28, height: 28)
                    .background(Theme.Colors.surface)
                    .overlay {
                        Image(systemName: "cat.fill")
                            .foregroundColor(Theme.Colors.accent.opacity(0.3))
                            .font(.system(size: 14))
                    }
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.trianglebadge.exclamationmark.fill")
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var bubbleColor: Color {
        switch message.type {
        case .user: return Theme.Colors.accent
        case .judge: return Theme.Colors.surface
        case .adversary: return Color.orange.opacity(0.1)
        }
    }
    
    private var textColor: Color {
        switch message.type {
        case .user: return .white
        case .judge: return Theme.Colors.textPrimary
        case .adversary: return .orange
        }
    }
}

struct LoadingBubble: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Theme.Colors.accent)
            Text("Judicial deliberations...")
                .font(.caption)
                .italic()
                .foregroundColor(Theme.Colors.textSecondary)
            Spacer()
        }
        .padding(.leading, 50)
    }
}
