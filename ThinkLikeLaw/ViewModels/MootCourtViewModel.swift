import Foundation
import Combine
import SwiftUI
import SwiftData
import AVFoundation
import Speech

/**
 * MootCourtViewModel — Business logic extracted from MootCourtView.
 * Manages speech recognition, AI interaction, scoring, timers, and result persistence.
 */
@MainActor
class MootCourtViewModel: ObservableObject {

    // MARK: - Configuration (set once)
    var scenario: String = ""
    var difficulty: MootDifficulty = .selfRep
    var userSide: MootSide = .claimant

    // MARK: - Published State
    @Published var messages: [MootMessage] = []
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var isThinking = false
    @Published var score: Double = 0.0
    @Published var isFinished = false
    @Published var verdict: String? = nil
    @Published var isPreparing = true
    @Published var prepTimeRemaining = 900  // 15 minutes
    @Published var skeletonArguments: [String] = ["", "", ""]

    // MARK: - Speech Properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private var recordingRequest: SFSpeechAudioBufferRecognitionRequest?
    private var timer: Timer?

    var adversarySide: String {
        userSide == .claimant ? "Respondent" : "Claimant"
    }

    // MARK: - Lifecycle

    func onAppear() {
        requestPermissions()
        startPrepTimer()
    }

    func onDisappear() {
        timer?.invalidate()
    }

    // MARK: - Preparation Phase

    func startPrepTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let vm = self else { return }
            Task { @MainActor in
                if vm.prepTimeRemaining > 0 {
                    vm.prepTimeRemaining -= 1
                } else {
                    vm.endPrep()
                }
            }
        }
    }

    func endPrep() {
        timer?.invalidate()
        withAnimation(.spring()) {
            isPreparing = false
        }
        startMoot()
    }

    // MARK: - Trial Logic

    func startMoot() {
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

                appendAdversarialResponse(response)
                isThinking = false
            } catch {
                isThinking = false
            }
        }
    }

    func submitArgument() {
        guard !recognizedText.isEmpty else { return }
        let argument = recognizedText
        messages.append(MootMessage(text: argument, type: .user))
        recognizedText = ""

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

                appendAdversarialResponse(response)
                isThinking = false
                extractScore(from: response)
            } catch {
                isThinking = false
            }
        }
    }

    // MARK: - Response Parsing

    func appendAdversarialResponse(_ response: String) {
        let cleanResponse = response.replacingOccurrences(of: "\\[SCORE: \\d+\\]", with: "", options: .regularExpression)
        let adversaryTag = "[ADVERSARY]:"
        let judgeTag = "[JUDGE]:"

        var segments: [(type: MootParticipant, text: String)] = []
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

        if segments.isEmpty {
            segments.append((.judge, cleanResponse))
        }

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

    func extractScore(from response: String) {
        let pattern = "\\[SCORE: (\\d+)\\]"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)) {
            if let scoreRange = Range(match.range(at: 1), in: response),
               let newScore = Double(response[scoreRange]) {
                withAnimation { self.score = newScore }
            }
        }
    }

    // MARK: - Verdict

    func requestVerdict() {
        isThinking = true
        Task {
            do {
                let prompt = "The trial has concluded. Based on Counsel's performance and a final score of \(Int(score)), provide a final Judicial Verdict and summary. Be decisive."
                let (response, _) = try await AIService.shared.callAI(tool: .moot_trial, content: prompt)

                self.verdict = response
                self.isFinished = true
                self.isThinking = false
            } catch {
                isThinking = false
            }
        }
    }

    func saveMootResult(modelContext: ModelContext) {
        let result = PersistedMootResult(
            scenario: scenario,
            difficulty: difficulty.rawValue,
            score: score,
            isWin: score >= 70,
            transcript: messages.map { "\($0.type): \($0.text)" }.joined(separator: "\n\n")
        )
        modelContext.insert(result)
        try? modelContext.save()

        XPService.shared.addXP(result.isWin ? .mootWin(difficulty: difficulty.rawValue) : .mootParticipation(difficulty: difficulty.rawValue))

        let activeArgs = skeletonArguments.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if !activeArgs.isEmpty {
            XPService.shared.addXP(.mootPrepBonus)
        }
    }

    // MARK: - Difficulty Context

    func getDifficultyContext() -> String {
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

    // MARK: - Helpers

    func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Speech Engine

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        #if os(iOS)
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { _ in }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        }
        #endif
    }

    func startListening() {
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

            recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
                if let result = result {
                    Task { @MainActor in
                        self?.recognizedText = result.bestTranscription.formattedString
                    }
                }
                if error != nil || result?.isFinal == true {
                    Task { @MainActor in
                        self?.stopListening()
                    }
                }
            }

            isListening = true
        } catch {
            isListening = false
        }
    }

    func stopListening() {
        audioEngine.stop()
        recordingRequest?.endAudio()
        recognitionTask?.cancel()
        isListening = false
        submitArgument()
    }

    func speak(_ text: String) {
        let utterance = VoiceService.shared.createUtterance(text: text)
        synthesizer.speak(utterance)
    }
}
