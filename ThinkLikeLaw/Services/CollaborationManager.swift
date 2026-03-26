import Foundation
import SwiftUI
import Combine

class CollaborationManager: ObservableObject {
    static let shared = CollaborationManager()
    
    @Published var activeUsers: [OnlineUser] = []
    private var heartbeatTimer: Timer?
    private var currentModuleId: String?
    
    private init() {}
    
    /**
     * Start tracking presence for a specific module
     */
    func startTracking(moduleId: String) {
        stopTracking()
        currentModuleId = moduleId
        
        // Initial heartbeat
        sendHeartbeat()
        
        // Periodic heartbeat & refresh
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
        
        // Initial fetch
        fetchActiveUsers()
    }
    
    /**
     * Stop tracking presence
     */
    func stopTracking() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        currentModuleId = nil
        
        // Clear active users
        DispatchQueue.main.async {
            self.activeUsers = []
        }
    }
    
    /**
     * Broadcast content to other students in the module
     */
    func broadcast(content: String, type: String = "brief") {
        guard let moduleId = currentModuleId else { return }
        
        Task {
            do {
                try await SupabaseManager.shared.updateProfile(updates: [
                    "broadcast_content": content,
                    "broadcast_type": type,
                    "active_module_id": moduleId
                ])
                
                // Clear broadcast after 60 seconds to avoid stale "toast"
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                try await SupabaseManager.shared.updateProfile(updates: [
                    "broadcast_content": NSNull(),
                    "broadcast_type": NSNull()
                ])
            } catch {
                print("CollaborationManager: Broadcast failed: \(error)")
            }
        }
    }
    
    private func sendHeartbeat() {
        guard let moduleId = currentModuleId else { return }
        
        Task {
            do {
                let formatter = ISO8601DateFormatter()
                let nowString = formatter.string(from: Date())
                
                try await SupabaseManager.shared.updateProfile(updates: [
                    "last_seen_at": nowString,
                    "active_module_id": moduleId
                ])
                
                // After heartbeat, refresh the list
                fetchActiveUsers()
            } catch {
                print("CollaborationManager: Heartbeat failed: \(error)")
            }
        }
    }
    
    private func fetchActiveUsers() {
        guard let moduleId = currentModuleId else { return }
        
        Task {
            do {
                let users = try await SupabaseManager.shared.fetchActiveUsers(moduleId: moduleId)
                DispatchQueue.main.async {
                    // Filter out current user (optional)
                    let currentUserId = UserDefaults.standard.string(forKey: "supabase_user_id")
                    self.activeUsers = users.filter { $0.id != currentUserId }
                }
            } catch {
                print("CollaborationManager: Fetch active users failed: \(error)")
            }
        }
    }
}
