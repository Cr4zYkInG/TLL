import Foundation

/**
 * SupabaseFlashcardService — Flashcard operations extracted from SupabaseManager.
 * Handles CRUD for flashcard sets and individual cards.
 */
class SupabaseFlashcardService {
    static let shared = SupabaseFlashcardService()
    private let api = SupabaseManager.shared

    private init() {}

    // MARK: - Flashcard Sets

    func fetchFlashcardSets() async throws -> [FlashcardSet] {
        return try await api.fetchFlashcardSets()
    }

    func fetchFlashcards(setId: String) async throws -> [Flashcard] {
        return try await api.fetchFlashcards(setId: setId)
    }

    func upsertFlashcardSet(
        id: String,
        topic: String,
        cards: [[String: Any]],
        moduleId: String? = nil,
        isPublic: Bool = false,
        learningSteps: [Int] = [1, 10],
        graduatingInterval: Int = 1,
        easyInterval: Int = 4
    ) async throws {
        try await api.upsertFlashcardSet(
            id: id,
            topic: topic,
            cards: cards,
            moduleId: moduleId,
            isPublic: isPublic,
            learningSteps: learningSteps,
            graduatingInterval: graduatingInterval,
            easyInterval: easyInterval
        )
    }
}
