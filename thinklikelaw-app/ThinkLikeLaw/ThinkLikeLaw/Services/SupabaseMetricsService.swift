import Foundation

/**
 * SupabaseMetricsService — User metrics, credits, and study session operations.
 * Extracted from SupabaseManager for clean domain separation.
 */
class SupabaseMetricsService {
    static let shared = SupabaseMetricsService()
    private let api = SupabaseManager.shared

    private init() {}

    // MARK: - Credits

    func getUserCredits(userId: String) async throws -> Int {
        return try await api.getUserCredits(userId: userId)
    }

    func deductCredits(amount: Int) async throws {
        try await api.deductCredits(amount: amount)
    }

    // MARK: - XP & Metrics

    func updateXP(total: Int) async throws {
        try await api.updateXP(total: total)
    }

    func fetchUserMetrics() async throws -> [String: Any]? {
        return try await api.fetchUserMetrics()
    }

    func updateStudyMetrics(minutesToAdd: Int) async throws -> [String: Any] {
        return try await api.updateStudyMetrics(minutesToAdd: minutesToAdd)
    }

    // MARK: - Study Sessions

    func fetchStudySessions() async throws -> [StudySession] {
        return try await api.fetchStudySessions()
    }

    func upsertStudySession(id: String, date: Date, durationMinutes: Int, type: String) async throws {
        try await api.upsertStudySession(id: id, date: date, durationMinutes: durationMinutes, type: type)
    }

    // MARK: - Deadlines

    func fetchDeadlines() async throws -> [Deadline] {
        return try await api.fetchDeadlines()
    }

    func upsertDeadline(id: String, title: String, date: Date, moduleId: String?, moduleName: String?, moduleColor: String?, weight: Double, priority: Int, isNotificationActive: Bool, isArchived: Bool, isDeleted: Bool = false) async throws {
        try await api.upsertDeadline(id: id, title: title, date: date, moduleId: moduleId, moduleName: moduleName, moduleColor: moduleColor, weight: weight, priority: priority, isNotificationActive: isNotificationActive, isArchived: isArchived, isDeleted: isDeleted)
    }

    func deleteDeadline(id: String) async throws {
        try await api.deleteDeadline(id: id)
    }
}
