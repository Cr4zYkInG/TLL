import SwiftUI
import Combine

/**
 * AuthState — Global Authentication State
 * Observes login/logout changes and manages the currentUser object.
 */
class AuthState: ObservableObject {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("educationLevel") var educationLevel: String = ""
    @AppStorage("selectedUniversity") var selectedUniversity: String = ""
    @Published var isLoggedIn: Bool = false
    @Published var isGuest: Bool = false
    @Published var currentUser: UserProfile? = nil
    @Published var isLoading: Bool = false
    @Published var isCheckingSession: Bool = true
    @Published var errorMessage: String? = nil
    
    // Live Study Metrics
    @Published var todayStudyMinutes: Int = 0
    @Published var currentStreak: Int = 1
    
    struct UserProfile {
        let id: String
        let firstName: String
        let lastName: String
        let email: String
        let university: String
        let plan: String
        let credits: Int
        let targetYear: Int?
        let leaderboardUsername: String?
        let isAnonymous: Bool
        let avatarUrl: String?
        let currentStatus: String?
        let examBoard: String?
    }
    
    init() {
        checkSession()
    }
    
    func checkSession() {
        if let userId = UserDefaults.standard.string(forKey: "supabase_user_id"),
           !userId.isEmpty {
            // Restore session
            Task {
                await self.loadUserProfile(userId: userId)
            }
        } else {
            self.isLoggedIn = false
            self.isGuest = false
            self.isCheckingSession = false
        }
    }
    
    @MainActor
    func loadUserProfile(userId: String) async {
        do {
            let profile = try await SupabaseManager.shared.getUserProfile(userId: userId)
            let credits = try? await SupabaseManager.shared.getUserCredits(userId: userId)
            
            self.currentUser = UserProfile(
                id: userId,
                firstName: profile["first_name"] as? String ?? "User",
                lastName: profile["last_name"] as? String ?? "",
                email: profile["email"] as? String ?? "",
                university: profile["university"] as? String ?? selectedUniversity,
                plan: (profile["tier"] as? String ?? "scholar").capitalized,
                credits: credits ?? 0,
                targetYear: {
                    if let intVal = profile["target_year"] as? Int { return intVal }
                    if let strVal = profile["target_year"] as? String { return Int(strVal) }
                    return nil
                }(),
                leaderboardUsername: profile["leaderboard_username"] as? String,
                isAnonymous: profile["is_anonymous"] as? Bool ?? false,
                avatarUrl: profile["avatar_url"] as? String,
                currentStatus: profile["current_status"] as? String ?? "llb",
                examBoard: profile["exam_board"] as? String
            )
            self.isLoggedIn = true
            
            // Load live metrics
            await self.loadUserMetrics()
            
            self.isCheckingSession = false
            
            // Mark onboarding as completed if profile data exists
            if let university = profile["university"] as? String, !university.isEmpty {
                self.hasCompletedOnboarding = true
            } else if let status = profile["current_status"] as? String, !status.isEmpty {
                self.hasCompletedOnboarding = true
            }
            
            // Trigger Sync
            // We need access to modelContext here, usually passed or via a global manager
            // For now, SyncService.reconcile will be called from views that have the context.
        } catch {
            self.isLoggedIn = false
            self.isCheckingSession = false
        }
    }
    
    @MainActor
    func loadUserMetrics() async {
        do {
            if let metrics = try await SupabaseManager.shared.fetchUserMetrics() {
                self.todayStudyMinutes = metrics["study_time"] as? Int ?? 0
                self.currentStreak = metrics["streak"] as? Int ?? 1
                
                // Also update local storage to keep it "sticky" for next launch
                UserDefaults.standard.set(self.todayStudyMinutes, forKey: "todayStudyTime")
                UserDefaults.standard.set(self.currentStreak, forKey: "studyStreak")
            }
        } catch {
            print("AuthState: Failed to load user metrics: \(error)")
        }
    }
    
    func refreshProfile() {
        if let userId = UserDefaults.standard.string(forKey: "supabase_user_id") {
            Task {
                await loadUserProfile(userId: userId)
            }
        }
    }
    
    func setEducationLevel(_ level: EducationLevel) {
        self.educationLevel = level.rawValue
    }
    
    func setUniversity(_ university: String) {
        self.selectedUniversity = university
        if let user = currentUser {
            self.currentUser = UserProfile(
                id: user.id,
                firstName: user.firstName,
                lastName: user.lastName,
                email: user.email,
                university: university,
                plan: user.plan,
                credits: user.credits,
                targetYear: user.targetYear,
                leaderboardUsername: user.leaderboardUsername,
                isAnonymous: user.isAnonymous,
                avatarUrl: user.avatarUrl,
                currentStatus: user.currentStatus,
                examBoard: user.examBoard
            )
        }
    }
    
    func completeOnboarding() {
        self.hasCompletedOnboarding = true
    }
    
    func enterGuestMode() {
        self.hasCompletedOnboarding = true
        self.isGuest = true
        // Set a mock guest profile
        self.currentUser = UserProfile(
            id: "guest",
            firstName: "Guest",
            lastName: "Counsel",
            email: "guest@thinklikelaw.com",
            university: "Exploring",
            plan: "guest",
            credits: 0,
            targetYear: nil,
            leaderboardUsername: nil,
            isAnonymous: false,
            avatarUrl: nil,
            currentStatus: "llb",
            examBoard: nil
        )
    }
    
    // MARK: - Auth Methods
    
    func login(email: String, password: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            if isGuest {
                NotificationCenter.default.post(name: .clearGuestData, object: nil)
            }
            _ = try await SupabaseManager.shared.signIn(email: email, password: password)
            if let userId = UserDefaults.standard.string(forKey: "supabase_user_id") {
                await loadUserProfile(userId: userId)
            }
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func handleAppleSignIn(idToken: String, nonce: String) async {
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            if isGuest {
                NotificationCenter.default.post(name: .clearGuestData, object: nil)
            }
            _ = try await SupabaseManager.shared.signInWithIdToken(provider: "apple", idToken: idToken, nonce: nonce)
            if let userId = UserDefaults.standard.string(forKey: "supabase_user_id") {
                await loadUserProfile(userId: userId)
            }
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func handleGoogleSignIn(idToken: String) async {
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            if isGuest {
                NotificationCenter.default.post(name: .clearGuestData, object: nil)
            }
            _ = try await SupabaseManager.shared.signInWithIdToken(provider: "google", idToken: idToken)
            if let userId = UserDefaults.standard.string(forKey: "supabase_user_id") {
                await loadUserProfile(userId: userId)
            }
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signup(firstName: String, lastName: String, email: String, password: String, university: String, level: EducationLevel) async {
        self.isLoading = true
        self.errorMessage = nil
        
        let metadata: [String: Any] = [
            "first_name": firstName,
            "last_name": lastName,
            "university": university,
            "student_level": level.rawValue
        ]
        
        do {
            _ = try await SupabaseManager.shared.signUp(email: email, password: password, metadata: metadata)
            await MainActor.run {
                self.isLoading = false
                // Note: User needs to confirm email, or we could auto-login if configured in Supabase
                self.errorMessage = "Check your email to verify your account."
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: "supabase_user_id")
        UserDefaults.standard.removeObject(forKey: "supabase_auth_token")
        
        // Trigger local data purge
        NotificationCenter.default.post(name: .clearGuestData, object: nil)
        
        Task {
            // try? await SupabaseManager.shared.client.auth.signOut()
            await MainActor.run {
                self.isLoggedIn = false
                self.isGuest = false
                self.currentUser = nil
            }
        }
    }
    
    func deleteAccount() async {
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            // 1. Delete on Cloud
            try await SupabaseManager.shared.deleteAccount()
            
            // 2. Clear Local Data via Notification (ContentView listens to this)
            await MainActor.run {
                NotificationCenter.default.post(name: .clearGuestData, object: nil)
                
                // 3. Purge Local Session
                self.logout()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Critical Error: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
