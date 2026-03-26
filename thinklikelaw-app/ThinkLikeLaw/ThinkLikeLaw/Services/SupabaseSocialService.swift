import Foundation

/**
 * SupabaseSocialService — Social & Community operations extracted from SupabaseManager.
 * Handles community feed, news, active users, leaderboard, and content forking.
 */
class SupabaseSocialService {
    static let shared = SupabaseSocialService()
    private let api = SupabaseManager.shared

    private init() {}

    // MARK: - Community Hub

    func fetchCommunityFeed(type: String = "all") async throws -> [[String: Any]] {
        return try await api.fetchCommunityFeed(type: type)
    }

    func forkItem(itemId: String, type: String) async throws {
        try await api.forkItem(itemId: itemId, type: type)
    }

    func updateUpvote(itemId: String, table: String, increment: Int) async throws {
        try await api.updateUpvote(itemId: itemId, table: table, increment: increment)
    }

    // MARK: - Active Users

    func fetchActiveUsers(moduleId: String) async throws -> [OnlineUser] {
        return try await api.fetchActiveUsers(moduleId: moduleId)
    }

    // MARK: - News

    func fetchNewsArticles(category: String) async throws -> [NewsArticle] {
        return try await api.fetchNewsArticles(category: category)
    }

    func getSavedNews() async throws -> [NewsArticle] {
        return try await api.getSavedNews()
    }

    func toggleSaveNews(articleId: String, isSaving: Bool) async throws {
        try await api.toggleSaveNews(articleId: articleId, isSaving: isSaving)
    }

    // MARK: - Leaderboard

    func fetchLeaderboard() async throws -> [[String: Any]] {
        return try await api.fetchLeaderboard()
    }
}
