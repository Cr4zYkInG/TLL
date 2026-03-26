import Foundation

/**
 * SupabaseAuthService — Authentication operations extracted from SupabaseManager.
 * Handles sign-in, sign-up, token refresh, and account deletion.
 */
class SupabaseAuthService {
    static let shared = SupabaseAuthService()
    private let api = SupabaseManager.shared

    private init() {}

    // MARK: - Email/Password Auth

    func signIn(email: String, password: String) async throws -> String {
        return try await api.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String, metadata: [String: Any]) async throws -> String {
        return try await api.signUp(email: email, password: password, metadata: metadata)
    }

    // MARK: - Social Auth

    func signInWithIdToken(provider: String, idToken: String, nonce: String? = nil) async throws -> String {
        return try await api.signInWithIdToken(provider: provider, idToken: idToken, nonce: nonce)
    }

    // MARK: - Session

    func refreshSession() async throws -> String {
        return try await api.refreshSession()
    }

    // MARK: - Profile & Account

    func getUserProfile(userId: String) async throws -> [String: Any] {
        return try await api.getUserProfile(userId: userId)
    }

    func updateProfile(updates: [String: Any]) async throws {
        try await api.updateProfile(updates: updates)
    }

    func uploadAvatar(data: Data) async throws -> String {
        return try await api.uploadAvatar(data: data)
    }

    func deleteAccount() async throws {
        try await api.deleteAccount()
    }
}
