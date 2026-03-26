import SwiftUI
import Combine

@MainActor
class MascotManager: Combine.ObservableObject {
    static let shared = MascotManager()
    
    enum MascotState: Equatable {
        case neutral, happy, proud, thinking, studying, sleeping, invigilator, worried, hiding, encouraging, analytical, exhausted
    }
    
    @Published var currentState: MascotState = .neutral
    @Published var currentSpeech: String = ""
    @Published var showBubble: Bool = false
    @Published var isFlipped: Bool = false
    @Published var isVisible: Bool = true
    @Published var isThinking: Bool = false
    
    private var speechTimer: Timer?
    
    // --- Contextual Responses ---
    
    private let greetings = [
        "Purr... ready to master the law? 🐾",
        "A First Class degree is 1% inspiration, 99% citation. Let's go!",
        "Meow! (That's cat for 'You've got this!')",
        "The Law Lords are waiting. Shall we begin?"
    ]
    
    private let focusNudges = [
        "Staying focused? I'll just sit here and look elegant. 🎩",
        "Don't mind me, I'm just auditing your concentrations.",
        "Precision in drafting, focus in study."
    ]
    
    private let deadlineNudges = [
        "Your exam is approaching! Every minute of study counts. ⏳",
        "Have you reviewed your notes for the upcoming deadline?",
        "Ben says: Better to be 7 days early than 1 day late."
    ]
    
    private let studyCelebrations = [
        "Incredible! That's a 1st Class answer! ✨",
        "Lord Denning would be proud of that recall.",
        "Your retention is spiking! Purrr-fection.",
        "Streak protected! You're a law machine.",
        "That's some high-fidelity reasoning right there."
    ]
    
    private let lapseResponses = [
        "Ouch! This case is a bit sticky. Let's try again. 🐾",
        "Even the best KCs have off days. Breathe and retry.",
        "Memory lapse? The Court grants a brief recess (mentally).",
        "Mistakes are just unpublished drafts of success!"
    ]
    
    private let confidenceResponses = [
        "Uncertain? Honesty is the best policy in the High Court.",
        "Solid! Your legal neural pathways are firing.",
        "Certainty! That's the spirit of a senior partner!"
    ]
    
    func speak(_ text: String, duration: TimeInterval = 5.0) {
        // Don't speak if hiding
        guard currentState != .hiding else { return }
        
        currentSpeech = text
        showBubble = true
        
        // Play mascot sound
        AudioManager.shared.playMascotSound(named: "mascot_meow")
        
        speechTimer?.invalidate()
        speechTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            Task { @MainActor in
                withAnimation {
                    self.showBubble = false
                }
            }
        }
    }
    
    // --- Behavior Logic ---
    
    /**
     * Call this when a significant study milestone is reached (e.g., mastered a card)
     */
    func celebrateSuccess() {
        withAnimation {
            isVisible = true
            currentState = .proud
            speak(studyCelebrations.randomElement()!)
            AudioManager.shared.playMascotSound(named: "mascot_happy")
        }
        
        resetStateAfterDelay(6)
    }
    
    func handleGrade(_ grade: SRSService.SRSGrade) {
        withAnimation {
            switch grade {
            case .again:
                currentState = .worried
                speak(lapseResponses.randomElement()!)
            case .hard:
                currentState = .analytical
                speak("A tough one! But precision is key.")
            case .good:
                currentState = .happy
                speak("Good! Keep that intellectual momentum.")
            case .easy:
                currentState = .proud
                speak(studyCelebrations.randomElement()!)
            }
        }
        resetStateAfterDelay(4)
    }
    
    func handleConfidence(_ level: SRSService.ConfidenceLevel) {
        withAnimation {
            switch level {
            case .uncertain:
                speak(confidenceResponses[0], duration: 3)
            case .solid:
                speak(confidenceResponses[1], duration: 3)
            case .certain:
                currentState = .happy
                speak(confidenceResponses[2], duration: 3)
            }
        }
    }
    
    func handleSessionMilestone(index: Int, total: Int) {
        let progress = Double(index + 1) / Double(total)
        if progress == 0.5 {
            speak("Halfway through! The chambers are impressed. 🏛️")
        } else if index == total - 2 {
            speak("Penultimate card! Finish with a strong closing argument.")
        }
    }
    
    private func resetStateAfterDelay(_ seconds: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            withAnimation {
                if self.currentState != .hiding && self.currentState != .thinking {
                    self.currentState = .neutral
                }
            }
        }
    }
    
    /**
     * Call this when the user enters a "Focus Mode" (e.g. Note Drawing)
     */
    func setFocusMode(_ active: Bool) {
        withAnimation {
            if active {
                // Minimized or hidden
                currentState = .hiding
                showBubble = false
                isVisible = false
            } else {
                currentState = .neutral
                isVisible = true
            }
        }
    }
    
    func handleTap(context: String = "") {
        withAnimation {
            currentState = .thinking
            isThinking = true
        }
        
        Task {
            do {
                let userPrompt = context.isEmpty ? "Give me a quick legal tip or words of encouragement for my law studies." : "I am currently looking at: \(context). Give me a relevant legal tip or encouragement based on this."
                
                let mascotPersona = """
                Persona: You are Ben, a tiny adorable kitten who just happens to have a law degree.
                Tone: MAXIMUM CUTE. Purry, brief, and sweet. Use "mew" and "purr".
                Goal: Give a tiny (5-10 words) legal tip or encouragement.
                Constraint: Never exceed 12 words. Be a simple cute cat but with legal essence.
                """
                
                let (response, _) = try await AIService.shared.callAI(tool: .chat, content: mascotPersona + "\n" + userPrompt)
                
                await MainActor.run {
                    withAnimation {
                        self.isThinking = false
                        self.currentState = .happy
                        self.speak(response)
                        AudioManager.shared.playMascotSound(named: "mascot_purr")
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        self.isThinking = false
                        self.currentState = .neutral
                        self.speak(greetings.randomElement()!)
                    }
                }
            }
            
            // Return to neutral
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                withAnimation {
                    if self.currentState == .happy || self.currentState == .thinking {
                        self.currentState = .neutral
                    }
                }
            }
        }
    }
    
    func greet() {
        let random = greetings.randomElement() ?? "Ready to study?"
        speak(random)
    }
    
    func nudgePersistence() {
        speak(focusNudges.randomElement()!)
    }
    
    func nudgeDeadline() {
        speak(deadlineNudges.randomElement()!)
    }
    
    /**
     * Proactive intelligence: Mascot identifies a struggle and offers help.
     */
    func triggerContextualHelp(topic: String, reason: String) {
        withAnimation {
            currentState = .worried
            isVisible = true
        }
        
        let prompt = "I noticed you're struggling with '\(topic)' (\(reason)). As your legal mascot, I want to help. Should we break this down together in the chat?"
        speak(prompt, duration: 8.0)
        
        // Haptic feedback to get attention
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }
    
    // --- Compatibility Methods ---
    
    func changeState(to newState: MascotState) {
        withAnimation {
            self.currentState = newState
        }
    }
    
    func showMascot() {
        withAnimation {
            self.isVisible = true
        }
    }
    
    func hideMascot() {
        withAnimation {
            self.isVisible = false
            self.showBubble = false
        }
    }
    
    func flipMascot() {
        withAnimation {
            self.isFlipped.toggle()
        }
    }
}
