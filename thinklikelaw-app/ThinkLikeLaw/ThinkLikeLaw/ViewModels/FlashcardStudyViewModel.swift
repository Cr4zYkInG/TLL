import Foundation
import Combine
import SwiftUI
import SwiftData

/**
 * FlashcardStudyViewModel — Business logic extracted from FlashcardStudyView.
 * Manages SRS review processing, session stats, card verification, and cloud sync.
 */
@MainActor
class FlashcardStudyViewModel: ObservableObject {

    // MARK: - Configuration
    var set: PersistedFlashcardSet!
    var isCramMode: Bool = false

    // MARK: - Published State
    @Published var cardsToReview: [PersistedFlashcard] = []
    @Published var currentIndex = 0
    @Published var isFlipped = false
    @Published var isSessionComplete = false
    @Published var cardOffset: CGFloat = 0

    // Session Stats
    @Published var correctCount = 0
    @Published var incorrectCount = 0
    @Published var sessionStartTime = Date()

    // Card Interaction
    @Published var selectedConfidence: SRSService.ConfidenceLevel = .solid
    @Published var aiFeedback: String?
    @Published var isVerifyingAnswer = false
    @Published var srsFlashColor: Color?
    @Published var verifiedCards: Set<String> = []

    // Internal tracking
    var cardFailures: [String: Int] = [:]

    var progress: Double {
        guard !cardsToReview.isEmpty else { return 0 }
        return Double(currentIndex) / Double(cardsToReview.count)
    }

    // MARK: - Lifecycle

    func onAppear(authState: AuthState, modelContext: ModelContext) {
        sessionStartTime = Date()
        if isCramMode {
            cardsToReview = set.cards.shuffled()
        } else {
            let cutoff = Date().addingTimeInterval(60)
            cardsToReview = set.cards.filter { $0.nextReviewDate <= cutoff }
                .sorted { $0.nextReviewDate < $1.nextReviewDate }
        }
        StudySessionManager.shared.startSession(type: "flashcards", modelContext: modelContext, authState: authState)
    }

    func onDisappear(modelContext: ModelContext, authState: AuthState) {
        StudySessionManager.shared.stopSession(modelContext: modelContext, authState: authState)
        if !isCramMode { syncToSupabase() }
    }

    // MARK: - Review Logic

    func submitReview(grade: SRSService.SRSGrade, modelContext: ModelContext) {
        if isCramMode {
            submitCramReview(grade: grade, modelContext: modelContext)
            return
        }

        let card = cardsToReview[currentIndex]
        let result = SRSService.shared.processReview(
            interval: card.interval,
            easeFactor: card.easeFactor,
            repetitions: card.repetitions,
            grade: grade,
            confidence: selectedConfidence,
            isLearning: card.isLearning ?? true,
            learningStep: card.learningStep ?? 0,
            learningSteps: set.learningSteps,
            graduatingInterval: set.graduatingInterval,
            easyInterval: set.easyInterval
        )

        // Visual feedback
        withAnimation(.easeIn(duration: 0.1)) {
            srsFlashColor = grade == .again ? .red : (grade == .hard ? .orange : (grade == .good ? .blue : .green))
        }

        #if os(iOS)
        switch grade {
        case .again: UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .hard: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .good: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .easy: UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation { self.srsFlashColor = nil }
        }

        // Track stats
        if grade == .good || grade == .easy { correctCount += 1 }
        else { incorrectCount += 1 }

        // Update persisted model
        card.interval = result.interval
        card.easeFactor = result.easeFactor
        card.repetitions = result.repetitions
        card.nextReviewDate = result.nextReviewDate
        card.lastReviewedAt = Date()
        card.isLearning = result.isLearning
        card.learningStep = result.learningStep

        XPService.shared.addXP(.flashcardReview(correct: grade != .again))

        // Track failures for contextual mascot help
        if grade == .again {
            let cardId = card.uuid
            let currentFails = (cardFailures[cardId] ?? 0) + 1
            cardFailures[cardId] = currentFails
            if currentFails == 3 {
                MascotManager.shared.triggerContextualHelp(topic: set.topic, reason: "repeated lapses")
            }
        }

        try? modelContext.save()

        MascotManager.shared.handleGrade(grade)
        MascotManager.shared.handleSessionMilestone(index: currentIndex, total: cardsToReview.count)

        advanceToNextCard()
    }

    private func submitCramReview(grade: SRSService.SRSGrade, modelContext: ModelContext) {
        if grade == .good || grade == .easy { correctCount += 1 }
        else { incorrectCount += 1 }

        XPService.shared.addXP(.flashcardReview(correct: grade == .good || grade == .easy))

        let card = cardsToReview[currentIndex]
        card.repetitions += 1
        card.lastReviewedAt = Date()
        try? modelContext.save()

        advanceToNextCard()
    }

    private func advanceToNextCard() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if currentIndex < cardsToReview.count - 1 {
                isFlipped = false
                selectedConfidence = .solid
                aiFeedback = nil
                currentIndex += 1
            } else {
                isSessionComplete = true
                if !isCramMode { syncToSupabase() }
            }
        }
    }

    // MARK: - Interval Preview

    func intervalPreview(grade: SRSService.SRSGrade) -> String {
        guard cardsToReview.indices.contains(currentIndex) else { return "" }
        let card = cardsToReview[currentIndex]

        let result = SRSService.shared.processReview(
            interval: card.interval,
            easeFactor: card.easeFactor,
            repetitions: card.repetitions,
            grade: grade,
            confidence: selectedConfidence,
            isLearning: card.isLearning ?? true,
            learningStep: card.learningStep ?? 0,
            learningSteps: set.learningSteps,
            graduatingInterval: set.graduatingInterval,
            easyInterval: set.easyInterval
        )

        if isCramMode { return "—" }

        let seconds = result.nextReviewDate.timeIntervalSince(Date())
        if seconds < 3600 {
            return "\(max(1, Int(seconds / 60)))m"
        } else if seconds < 86400 {
            return "\(Int(seconds / 3600))h"
        } else {
            return "\(max(1, Int(seconds / 86400)))d"
        }
    }

    // MARK: - AI Verification

    func verifyFlashcardFact(card: PersistedFlashcard) {
        isVerifyingAnswer = true
        aiFeedback = nil

        Task {
            do {
                let context = ["question": card.question]
                let (response, _) = try await AIService.shared.callAI(tool: .verify_answer, content: card.answer, context: context)
                isVerifyingAnswer = false
                if response.contains("VERIFIED: Correct") || response.uppercased().contains("VERIFIED: CORRECT") {
                    verifiedCards.insert(card.uuid)
                    #if os(iOS)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    #endif
                } else {
                    aiFeedback = response
                    #if os(iOS)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    #endif
                }
            } catch {
                isVerifyingAnswer = false
                aiFeedback = "Unable to contact Chambers for verification."
            }
        }
    }

    // MARK: - Cloud Sync

    func syncToSupabase() {
        let deckId = set.id
        let topic = set.topic
        let moduleId = set.moduleId
        let isPublic = set.isPublic

        let cardsJson: [[String: Any]] = set.cards.map { card in
            var dict: [String: Any] = [
                "question": card.question,
                "answer": card.answer,
                "type": card.type ?? "basic",
                "interval": card.interval,
                "easeFactor": card.easeFactor,
                "repetitions": card.repetitions,
                "nextReviewDate": ISO8601DateFormatter().string(from: card.nextReviewDate),
                "isLearning": card.isLearning ?? true,
                "learningStep": card.learningStep ?? 0
            ]
            if let last = card.lastReviewedAt {
                dict["lastReviewedAt"] = ISO8601DateFormatter().string(from: last)
            }
            if let fUrl = card.frontImageUrl { dict["frontImageUrl"] = fUrl }
            if let bUrl = card.backImageUrl { dict["backImageUrl"] = bUrl }
            if let occ = card.occlusionRectsJson { dict["occlusionRectsJson"] = occ }
            return dict
        }

        Task {
            do {
                try await SupabaseManager.shared.upsertFlashcardSet(
                    id: deckId,
                    topic: topic,
                    cards: cardsJson,
                    moduleId: moduleId,
                    isPublic: isPublic,
                    learningSteps: set.learningSteps,
                    graduatingInterval: set.graduatingInterval,
                    easyInterval: set.easyInterval
                )
                print("Supabase: Flashcard set synchronized successfully.")
            } catch {
                print("Supabase: Sync failed -> \(error)")
            }
        }
    }

    // MARK: - Helpers

    func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}
