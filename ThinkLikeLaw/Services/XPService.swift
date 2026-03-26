import Foundation
import Combine

/**
 * XPService — Core Engine for Jurisprudence XP and Career Levels.
 * Awarded for Moot wins, Flashcard streaks, and Statute mapping.
 */
class XPService: ObservableObject {
    static let shared = XPService()
    
    @Published var totalXP: Int = 0 {
        didSet {
            UserDefaults.standard.set(totalXP, forKey: "user_total_xp")
            Task { try? await SupabaseManager.shared.updateXP(total: totalXP) } // Sync to cloud
        }
    }
    @Published var level: Int = 1
    
    private init() {
        self.totalXP = UserDefaults.standard.integer(forKey: "user_total_xp")
        self.level = calculateLevel(from: totalXP)
    }
    
    enum XPEvent {
        case mootWin(difficulty: String)
        case mootParticipation(difficulty: String)
        case mootPrepBonus
        case flashcardReview(correct: Bool)
        case caseScan
        case statuteMapCreated
        case dailyStreak(days: Int)
        
        var amount: Int {
            switch self {
            case .mootWin(let diff):
                switch diff {
                case "Self-Rep": return 100
                case "Law Graduate": return 250
                case "Seasoned Lawyer": return 500
                case "King's Counsel": return 1000
                default: return 100
                }
            case .mootParticipation: return 50
            case .mootPrepBonus: return 100
            case .flashcardReview(let correct): return correct ? 10 : 2
            case .caseScan: return 30
            case .statuteMapCreated: return 50
            case .dailyStreak(let days): return days * 20
            }
        }
    }
    
    func addXP(_ event: XPEvent) {
        let earned = event.amount
        totalXP += earned
        
        // Persist locally
        UserDefaults.standard.set(totalXP, forKey: "user_total_xp")
        
        // Recalculate level
        let newLevel = calculateLevel(from: totalXP)
        if newLevel > level {
            level = newLevel
            // Post notification for Level Up UI
            NotificationCenter.default.post(name: .levelUp, object: nil, userInfo: ["level": level])
        }
        
        // Synchronize with Supabase in background
        Task {
            // try? await SupabaseManager.shared.updateXP(total: totalXP)
        }
    }
    
    private func calculateLevel(from xp: Int) -> Int {
        // Simple logarithmic scale: Level 1 = 0, Level 2 = 500, Level 3 = 1250...
        // Format: XP = 500 * (level - 1)^1.5
        // Reversing: level = (xp / 500)^(1/1.5) + 1
        let l = pow(Double(xp) / 500.0, 1.0/1.5) + 1.0
        return max(1, Int(l))
    }
    
    var careerTitle: String {
        switch level {
        case 1...4: return "Self-Represented Litigant"
        case 5...14: return "Law Graduate"
        case 15...29: return "Seasoned Lawyer"
        case 30...99: return "King's Counsel"
        default: return "Supreme Court Justice"
        }
    }
    
    var xpToNextLevel: Int {
        let nextLevelXP = Int(500.0 * pow(Double(level), 1.5))
        return nextLevelXP - totalXP
    }
    
    var progressToNextLevel: Double {
        let currentLevelStart = 500.0 * pow(Double(level - 1), 1.5)
        let nextLevelStart = 500.0 * pow(Double(level), 1.5)
        let totalNeeded = nextLevelStart - currentLevelStart
        let earnedInLevel = Double(totalXP) - currentLevelStart
        return max(0, min(1.0, earnedInLevel / totalNeeded))
    }
}

extension NSNotification.Name {
    static let levelUp = NSNotification.Name("ThinkLikeLawLevelUp")
}
