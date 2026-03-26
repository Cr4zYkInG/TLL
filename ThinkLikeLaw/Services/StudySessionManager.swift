import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
class StudySessionManager: ObservableObject {
    static let shared = StudySessionManager()
    
    private var startTime: Date?
    private var activeType: String?
    
    @Published var currentSessionDuration: TimeInterval = 0
    private var timer: Timer?
    
    private init() {}
    
    func startSession(type: String, modelContext: ModelContext? = nil, authState: AuthState? = nil) {
        // If already in a session, stop it first and persist it
        if startTime != nil {
            stopSession(modelContext: modelContext, authState: authState)
        }
        
        startTime = Date()
        activeType = type
        currentSessionDuration = 0
        
        // Use a Task with a loop instead of Timer to avoid Swift 6 capture errors
        Task { [weak self] in
            while let self = self, self.startTime != nil {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await MainActor.run {
                    if let start = self.startTime {
                        self.currentSessionDuration = Date().timeIntervalSince(start)
                    }
                }
            }
        }
    }
    
    func stopSession(modelContext: ModelContext? = nil, authState: AuthState? = nil) {
        guard let start = startTime, let type = activeType else { return }
        
        let duration = Date().timeIntervalSince(start)
        let minutes = Int(duration / 60)
        
        // Only record if more than 1 minute (to avoid noise)
        if minutes >= 1 {
            saveSessionLocally(minutes: minutes, type: type, modelContext: modelContext)
            saveSessionToCloud(minutes: minutes, authState: authState)
        }
        
        // Reset
        startTime = nil
        activeType = nil
        currentSessionDuration = 0
        timer?.invalidate()
        timer = nil
    }
    
    private func saveSessionLocally(minutes: Int, type: String, modelContext: ModelContext?) {
        guard let context = modelContext else { return }
        
        let today = Calendar.current.startOfDay(for: Date())
        let fetchDescriptor = FetchDescriptor<PersistedStudySession>(
            predicate: #Predicate { $0.date == today && $0.type == type }
        )
        
        do {
            let existing = try context.fetch(fetchDescriptor)
            if let first = existing.first {
                first.durationMinutes += minutes
            } else {
                let newSession = PersistedStudySession(date: today, durationMinutes: minutes, type: type)
                context.insert(newSession)
            }
            try context.save()
        } catch {
            print("StudySessionManager: Failed to save locally -> \(error)")
        }
    }
    
    private func saveSessionToCloud(minutes: Int, authState: AuthState?) {
        Task {
            do {
                let updated = try await SupabaseManager.shared.updateStudyMetrics(minutesToAdd: minutes)
                await MainActor.run {
                    authState?.todayStudyMinutes = updated["study_time"] as? Int ?? 0
                    authState?.currentStreak = updated["streak"] as? Int ?? 1
                }
            } catch {
                print("StudySessionManager: Cloud sync failed -> \(error)")
            }
        }
    }
}
