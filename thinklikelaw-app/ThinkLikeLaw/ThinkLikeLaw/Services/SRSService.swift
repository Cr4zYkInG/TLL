import Foundation
import Combine

/**
 * SRSService — Core logic for Spaced Repetition and Retention
 * Implements a modified SM-2 algorithm for flashcards and 
 * an Ebbinghaus forgetting curve for lecture notes.
 */
class SRSService {
    static let shared = SRSService()
    
    // --- Flashcard SRS (SM-2 Algorithm) ---
    
    enum SRSGrade: Int {
        case again = 0
        case hard = 1
        case good = 2
        case easy = 3
    }
    
    enum ConfidenceLevel: Double {
        case uncertain = 0.8
        case solid = 1.0
        case certain = 1.2
    }
    
    struct SRSResult {
        let interval: Int
        let easeFactor: Double
        let repetitions: Int
        let nextReviewDate: Date
        let isLearning: Bool
        let learningStep: Int
    }
    
    /**
     * Updates flashcard metadata based on user performance
     * learningSteps (in minutes): default [1, 10]
     * graduatingInterval (in days): default 1
     * easyInterval (in days): default 4
     */
    func processReview(
        interval: Int,
        easeFactor: Double,
        repetitions: Int,
        grade: SRSGrade,
        confidence: ConfidenceLevel = .solid,
        isLearning: Bool,
        learningStep: Int,
        learningSteps: [Int] = [1, 10],
        graduatingInterval: Int = 1,
        easyInterval: Int = 4
    ) -> SRSResult {
        var nextInterval = interval
        var nextEaseFactor = easeFactor
        var nextRepetitions = repetitions
        var nextIsLearning = isLearning
        var nextLearningStep = learningStep
        
        let steps = learningSteps.isEmpty ? [1, 10] : learningSteps
        
        if isLearning {
            if grade == .again {
                nextLearningStep = 0
                let nextDate = Calendar.current.date(byAdding: .minute, value: steps[0], to: Date()) ?? Date()
                return SRSResult(interval: 0, easeFactor: easeFactor, repetitions: 0, nextReviewDate: nextDate, isLearning: true, learningStep: 0)
            } else if grade == .hard {
                // Stay in current step, but show in 5 mins
                let nextDate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
                return SRSResult(interval: 0, easeFactor: easeFactor, repetitions: repetitions, nextReviewDate: nextDate, isLearning: true, learningStep: learningStep)
            } else if grade == .good {
                nextLearningStep += 1
                if nextLearningStep >= steps.count {
                    // Graduate
                    nextIsLearning = false
                    nextInterval = graduatingInterval
                    nextRepetitions = 1
                    let nextDate = Calendar.current.date(byAdding: .day, value: graduatingInterval, to: Date()) ?? Date()
                    return SRSResult(interval: graduatingInterval, easeFactor: easeFactor, repetitions: 1, nextReviewDate: nextDate, isLearning: false, learningStep: 0)
                } else {
                    let nextDate = Calendar.current.date(byAdding: .minute, value: steps[nextLearningStep], to: Date()) ?? Date()
                    return SRSResult(interval: 0, easeFactor: easeFactor, repetitions: 0, nextReviewDate: nextDate, isLearning: true, learningStep: nextLearningStep)
                }
            } else { // Easy
                // Immediate graduation
                nextIsLearning = false
                nextInterval = easyInterval
                nextRepetitions = 1
                let nextDate = Calendar.current.date(byAdding: .day, value: easyInterval, to: Date()) ?? Date()
                return SRSResult(interval: easyInterval, easeFactor: easeFactor, repetitions: 1, nextReviewDate: nextDate, isLearning: false, learningStep: 0)
            }
        } else {
            // Standard SM-2 for Graduated cards
            if grade.rawValue >= SRSGrade.good.rawValue {
                if nextRepetitions == 1 {
                    nextInterval = 6
                } else {
                    nextInterval = Int(round(Double(interval) * easeFactor * confidence.rawValue))
                }
                nextRepetitions += 1
            } else {
                // Lapser logic
                nextIsLearning = true
                nextLearningStep = 0
                nextRepetitions = 0
                nextInterval = 0
                nextEaseFactor = max(1.3, easeFactor - 0.2)
                let nextDate = Calendar.current.date(byAdding: .minute, value: steps[0], to: Date()) ?? Date()
                return SRSResult(interval: 0, easeFactor: nextEaseFactor, repetitions: 0, nextReviewDate: nextDate, isLearning: true, learningStep: 0)
            }
            
            // Update Ease Factor for Graduated cards
            let q = Double(grade.rawValue)
            let adjustment = (0.1 - (3 - q) * (0.08 + (3 - q) * 0.02))
            nextEaseFactor = max(1.3, easeFactor + adjustment)
            
            let nextReviewDate = Calendar.current.date(byAdding: .day, value: nextInterval, to: Date()) ?? Date()
            
            return SRSResult(
                interval: nextInterval,
                easeFactor: nextEaseFactor,
                repetitions: nextRepetitions,
                nextReviewDate: nextReviewDate,
                isLearning: nextIsLearning,
                learningStep: 0
            )
        }
    }
    
    // --- Note Retention (Ebbinghaus Forgetting Curve) ---
    
    /**
     * Replicates the website's RetentionEngine.calculateRetention logic
     * Returns a score between 10 and 100 representing estimated memory retention.
     */
    func calculateNoteRetention(reviewCount: Int, lastReviewedAt: Date?) -> Double {
        guard let lastReviewDate = lastReviewedAt else {
            return 100.0 // Brand new
        }
        
        let now = Date()
        let elapsedSeconds = now.timeIntervalSince(lastReviewDate)
        let elapsedDays = max(0, elapsedSeconds / (24 * 60 * 60))
        
        // If reviewed today (and has been reviewed before), stay at 100
        if elapsedDays < 0.5 && reviewCount > 0 {
            return 100.0
        }
        
        // Ebbinghaus Formula Approximation: Retention = e^(-Elapsed / Strength)
        // Memory strength increases based on review count
        let memoryStrength = 1.0 + pow(Double(reviewCount) * 1.5, 1.8)
        let decay = exp(-elapsedDays / memoryStrength)
        
        let score = round(decay * 100.0)
        
        return max(10.0, min(100.0, score))
    }
}
