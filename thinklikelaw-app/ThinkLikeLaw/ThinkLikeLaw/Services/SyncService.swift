import Foundation
import SwiftData

class SyncService {
    static let shared = SyncService()
    
    private var isSyncing = false
    
    private init() {}
    
    @MainActor
    func reconcile(modelContext: ModelContext) async {
        guard !isSyncing else { 
            print("SyncService: Already syncing, skipping...")
            return 
        }
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id"), !userId.isEmpty else { 
            print("SyncService: No userId found, sync aborted.")
            return 
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        print("SyncService: Starting reconciliation for userId: \(userId)")
        
        do {
            // 1. Reconcile Modules
            let remoteModules = try await SupabaseManager.shared.fetchModules()
            print("SyncService: Fetched \(remoteModules.count) remote modules.")
            let remoteIds = Set(remoteModules.map { $0.id })
            
            var processedModuleIds = Set<String>()
            
            let localModulesDescriptor = FetchDescriptor<PersistedModule>()
            let localModules = (try? modelContext.fetch(localModulesDescriptor)) ?? []
            let localIds = Set(localModules.map { $0.id })
            
            // Push local-only or tombstoned modules to cloud
            for local in localModules {
                if !remoteIds.contains(local.id) || local.isDeleted {
                    // If it's deleted and not in remote, we might not need to push unless we want to ensure remote is also tombstoned
                    // If it is in remote and local isDeleted, we MUST push the tombstone.
                    
                    if local.isDeleted && !remoteIds.contains(local.id) {
                        // Already deleted locally and never reached cloud? Just delete locally for real now.
                        modelContext.delete(local)
                        continue
                    }

                    print("SyncService: Syncing module status to cloud: \(local.name) (Deleted: \(local.isDeleted ?? false))")
                    try? await SupabaseManager.shared.upsertModule(
                        id: local.id,
                        name: local.name,
                        icon: local.icon,
                        description: local.desc,
                        archived: local.archived,
                        isDeleted: local.isDeleted ?? false
                    )
                }
            }
            
            // Pull remote modules & Handle deletions
            for remote in remoteModules {
                if remote.isDeleted {
                    // Remote says it's deleted -> Delete local if it exists
                    if let local = localModules.first(where: { $0.id == remote.id }) {
                        print("SyncService: Deleting local module (remote tombstone): \(local.name) [\(local.id)]")
                        modelContext.delete(local)
                    } else {
                        print("SyncService: Remote module \(remote.name) [\(remote.id)] is tombstoned, skipping pull.")
                    }
                    continue
                }

                if processedModuleIds.contains(remote.id) {
                    print("SyncService: Skipping duplicate remote module in same sync: \(remote.name) [\(remote.id)]")
                    continue
                }
                processedModuleIds.insert(remote.id)

                if !localIds.contains(remote.id) {
                    print("SyncService: Pulling remote-only module: \(remote.name)")
                    let newModule = PersistedModule(
                        id: remote.id,
                        name: remote.name,
                        icon: remote.icon,
                        desc: remote.description,
                        archived: remote.archived,
                        examDeadline: remote.examDeadline,
                        createdAt: remote.createdAt,
                        isDeleted: false
                    )
                    modelContext.insert(newModule)
                } else if let local = localModules.first(where: { $0.id == remote.id }) {
                    // Update existing local module with remote values
                    local.name = remote.name
                    local.icon = remote.icon
                    local.desc = remote.description
                    local.archived = remote.archived
                    local.examDeadline = remote.examDeadline
                }
            }
            
            // Re-fetch local modules after pull to ensure we have all of them (including newly pulled)
            let allLocalModules = (try? modelContext.fetch(localModulesDescriptor)) ?? []
            
            // 2. Reconcile Notes per Module
            for module in allLocalModules {
                let remoteNotes = try await SupabaseManager.shared.fetchLectures(moduleId: module.id)
                let remoteNoteIds = Set(remoteNotes.map { $0.id })
                let localNoteIds = Set(module.notes.map { $0.id })
                
                // Push local-only or tombstoned notes to cloud
                for note in module.notes {
                    if !remoteNoteIds.contains(note.id) || (note.isDeleted ?? false) {
                        
                        if note.isDeleted && !remoteNoteIds.contains(note.id) {
                            modelContext.delete(note)
                            continue
                        }

                        print("SyncService: Syncing note status to cloud: \(note.title) (Deleted: \(note.isDeleted ?? false))")
                        try? await SupabaseManager.shared.upsertLecture(
                            id: note.id,
                            moduleId: module.id,
                            title: note.title,
                            content: note.content,
                            preview: note.preview,
                            lastModified: note.lastModified ?? Date(),
                            reviewCount: note.reviewCount,
                            retentionScore: note.retentionScore,
                            aiHistory: note.aiHistory,
                            attachmentUrl: note.attachmentUrl,
                            drawingData: note.drawingData,
                            paperStyle: note.paperStyle,
                            paperColor: note.paperColor,
                            audioUrl: note.audioUrl,
                            pdfData: note.pdfData,
                            isDeleted: note.isDeleted ?? false
                        )
                    }
                }
                
                // Pull remote notes & Handle deletions
                for remoteNote in remoteNotes {
                    if remoteNote.isDeleted {
                        if let local = module.notes.first(where: { $0.id == remoteNote.id }) {
                            print("SyncService: Deleting local note (remote tombstone): \(local.title)")
                            modelContext.delete(local)
                        }
                        continue
                    }

                    if !localNoteIds.contains(remoteNote.id) {
                        print("SyncService: Pulling remote-only note: \(remoteNote.title)")
                        let newNote = PersistedNote(
                            id: remoteNote.id,
                            title: remoteNote.title,
                            content: remoteNote.content,
                            preview: remoteNote.preview,
                            moduleId: module.id,
                            createdAt: remoteNote.createdAt,
                            lastModified: remoteNote.lastModified ?? remoteNote.createdAt,
                            reviewCount: remoteNote.reviewCount,
                            retentionScore: remoteNote.retentionScore,
                            lastReviewedAt: nil,
                            drawingData: remoteNote.drawingData,
                            paperStyle: remoteNote.paperStyle ?? "blank",
                            paperColor: remoteNote.paperColor ?? "white",
                            attachmentUrl: remoteNote.attachmentUrl,
                            aiHistory: remoteNote.aiHistory,
                            isDeleted: false
                        )
                        newNote.module = module
                        modelContext.insert(newNote)
                    } else if let local = module.notes.first(where: { $0.id == remoteNote.id }) {
                        // Update existing local note
                        local.title = remoteNote.title
                        local.content = remoteNote.content
                        local.preview = remoteNote.preview
                        local.lastModified = remoteNote.lastModified
                        local.reviewCount = remoteNote.reviewCount
                        local.retentionScore = remoteNote.retentionScore
                        local.drawingData = remoteNote.drawingData
                        local.aiHistory = remoteNote.aiHistory
                    }
                }
            }
            
            // 3. Reconcile Deadlines
            print("SyncService: Reconciling deadlines...")
            let remoteDeadlines = try await SupabaseManager.shared.fetchDeadlines()
            print("SyncService: Fetched \(remoteDeadlines.count) remote deadlines.")
            let remoteDeadlineIds = Set(remoteDeadlines.map { $0.id })
            
            var processedDeadlineIds = Set<String>()
            
            let localDeadlinesDescriptor = FetchDescriptor<PersistedDeadline>()
            let localDeadlines = (try? modelContext.fetch(localDeadlinesDescriptor)) ?? []
            let localDeadlineIds = Set(localDeadlines.map { $0.id })
            
            // Push local-only or tombstoned deadlines to cloud
            for local in localDeadlines {
                if !remoteDeadlineIds.contains(local.id) || local.isDeleted ?? false {
                    
                    if local.isDeleted ?? false && !remoteDeadlineIds.contains(local.id) {
                        modelContext.delete(local)
                        continue
                    }

                    print("SyncService: Syncing deadline status to cloud: \(local.title) (Deleted: \(local.isDeleted ?? false))")
                    try? await SupabaseManager.shared.upsertDeadline(
                        id: local.id,
                        title: local.title,
                        date: local.date,
                        moduleId: local.moduleId,
                        moduleName: local.moduleName,
                        moduleColor: local.moduleColor,
                        weight: local.weight ?? 0.0,
                        priority: local.priority ?? 1,
                        isNotificationActive: local.isNotificationActive ?? true,
                        isArchived: local.isArchived ?? false,
                        isDeleted: local.isDeleted ?? false
                    )
                }
            }
            
            // Pull remote-only to local & Handle deletions
            for remote in remoteDeadlines {
                if remote.isDeleted {
                    if let local = localDeadlines.first(where: { $0.id == remote.id }) {
                        print("SyncService: Deleting local deadline (remote tombstone): \(local.title) [\(local.id)]")
                        modelContext.delete(local)
                    } else {
                        print("SyncService: Remote deadline \(remote.title) [\(remote.id)] is tombstoned, skipping pull.")
                    }
                    continue
                }

                if processedDeadlineIds.contains(remote.id) {
                    print("SyncService: Skipping duplicate remote deadline in same sync: \(remote.title) [\(remote.id)]")
                    continue
                }
                processedDeadlineIds.insert(remote.id)

                if !localDeadlineIds.contains(remote.id) {
                    print("SyncService: Pulling remote-only deadline: \(remote.title)")
                    let newDeadline = PersistedDeadline(
                        id: remote.id,
                        title: remote.title,
                        date: remote.date,
                        moduleId: remote.moduleId,
                        moduleName: remote.moduleName,
                        moduleColor: remote.moduleColor,
                        weight: remote.weight,
                        priority: remote.priority,
                        isNotificationActive: remote.isNotificationActive
                    )
                    newDeadline.isArchived = remote.isArchived
                    newDeadline.isDeleted = false
                    newDeadline.createdAt = remote.createdAt
                    modelContext.insert(newDeadline)
                } else if let local = localDeadlines.first(where: { $0.id == remote.id }) {
                    // Update local with remote values
                    local.title = remote.title
                    local.date = remote.date
                    local.moduleId = remote.moduleId
                    local.moduleName = remote.moduleName
                    local.moduleColor = remote.moduleColor
                    local.weight = remote.weight
                    local.priority = remote.priority
                    local.isNotificationActive = remote.isNotificationActive
                }
            }
            
            // 4. Reconcile Study Sessions
            print("SyncService: Reconciling study sessions...")
            if let remoteSessions = try? await SupabaseManager.shared.fetchStudySessions() {
                let remoteSessionIds = Set(remoteSessions.map { $0.id })
                let localSessionsDescriptor = FetchDescriptor<PersistedStudySession>()
                let localSessions = (try? modelContext.fetch(localSessionsDescriptor)) ?? []
                let localSessionIds = Set(localSessions.map { $0.id })
                
                // Push local to cloud
                for local in localSessions {
                    if !remoteSessionIds.contains(local.id) {
                        print("SyncService: Pushing study session to cloud: \(local.id)")
                        try? await SupabaseManager.shared.upsertStudySession(
                            id: local.id,
                            date: local.date,
                            durationMinutes: local.durationMinutes,
                            type: local.type
                        )
                    }
                }
                
                // Pull cloud to local
                for remote in remoteSessions {
                    if !localSessionIds.contains(remote.id) {
                        print("SyncService: Pulling study session from cloud: \(remote.id)")
                        let newSession = PersistedStudySession(
                            date: remote.date,
                            durationMinutes: remote.durationMinutes,
                            type: remote.type
                        )
                        modelContext.insert(newSession)
                    }
                }
            }

            // 4. Reconcile Flashcards
            await reconcileFlashcards(modelContext: modelContext)

            print("SyncService: Finalizing context save... (Changes: \(modelContext.hasChanges))")
            try modelContext.save()
            
            // 5. Heuristic De-duplication
            deduplicateDeadlines(modelContext: modelContext)
            
            // Final results log (Refetch to show truth)
            let finalModules = (try? modelContext.fetch(localModulesDescriptor)) ?? []
            let finalDeadlines = (try? modelContext.fetch(localDeadlinesDescriptor)) ?? []
            print("SyncService: Reconciliation complete. (Modules: \(finalModules.count), Deadlines: \(finalDeadlines.count))")
        } catch {
            print("SyncService: CRITICAL Error during reconciliation: \(error)")
            if let nsError = error as NSError? {
                print("SyncService: Error Details - Domain: \(nsError.domain), Code: \(nsError.code), Info: \(nsError.userInfo)")
            }
        }
    }
    
    @MainActor
    private func reconcileFlashcards(modelContext: ModelContext) async {
        print("SyncService: Reconciling flashcards...")
        do {
            let remoteSets = try await SupabaseManager.shared.fetchFlashcardSets()
            let remoteIds = Set(remoteSets.map { $0.id })
            
            let localSetsDescriptor = FetchDescriptor<PersistedFlashcardSet>()
            let localSets = (try? modelContext.fetch(localSetsDescriptor)) ?? []

            // 1. Push local changes/tombstones
            for local in localSets {
                if !remoteIds.contains(local.id) || (local.isDeleted ?? false) {
                    if local.isDeleted ?? false && !remoteIds.contains(local.id) {
                        modelContext.delete(local)
                        continue
                    }
                    
                    print("SyncService: Pushing flashcard set: \(local.topic)")
                    let cardsJson: [[String: Any]] = local.cards.map { card in
                        var json: [String: Any] = [
                            "id": card.uuid, // Use uuid as primary identifier for cards
                            "question": card.question,
                            "answer": card.answer,
                            "type": card.type ?? "basic",
                            "interval": card.interval,
                            "ease_factor": card.easeFactor,
                            "repetitions": card.repetitions,
                            "next_review_date": ISO8601DateFormatter().string(from: card.nextReviewDate),
                            "is_learning": card.isLearning ?? true,
                            "learning_step": card.learningStep ?? 0,
                            "is_deleted": card.isDeleted ?? false
                        ]
                        if let fUrl = card.frontImageUrl { json["front_image_url"] = fUrl }
                        if let bUrl = card.backImageUrl { json["back_image_url"] = bUrl }
                        return json
                    }
                    
                    try? await SupabaseManager.shared.upsertFlashcardSet(
                        id: local.id,
                        topic: local.topic,
                        cards: cardsJson,
                        moduleId: local.moduleId,
                        isPublic: local.isPublic,
                        learningSteps: local.learningSteps,
                        graduatingInterval: local.graduatingInterval,
                        easyInterval: local.easyInterval
                    )
                }
            }

            // 2. Pull remote changes
            for remote in remoteSets {
                if remote.isDeleted {
                    if let local = localSets.first(where: { $0.id == remote.id }) {
                        print("SyncService: Deleting local flashcard set (remote tombstone): \(local.topic)")
                        modelContext.delete(local)
                    }
                    continue
                }

                let localSet: PersistedFlashcardSet
                if let existing = localSets.first(where: { $0.id == remote.id }) {
                    localSet = existing
                    localSet.topic = remote.topic
                    localSet.moduleId = remote.moduleId
                    localSet.moduleName = remote.moduleName
                    localSet.isPublic = remote.isPublic
                    localSet.learningSteps = remote.learningSteps
                    localSet.graduatingInterval = remote.graduatingInterval
                    localSet.easyInterval = remote.easyInterval
                    localSet.isDeleted = false
                } else {
                    print("SyncService: Pulling remote flashcard set: \(remote.topic)")
                    localSet = PersistedFlashcardSet(
                        id: remote.id,
                        topic: remote.topic,
                        moduleId: remote.moduleId,
                        moduleName: remote.moduleName,
                        learningSteps: remote.learningSteps,
                        graduatingInterval: remote.graduatingInterval,
                        easyInterval: remote.easyInterval
                    )
                    localSet.isPublic = remote.isPublic
                    localSet.isDeleted = false
                    modelContext.insert(localSet)
                }

                // Sync individual cards for this set
                let remoteCards = try await SupabaseManager.shared.fetchFlashcards(setId: remote.id)
                
                for rCard in remoteCards {
                    if rCard.isDeleted {
                        if let lCard = localSet.cards.first(where: { $0.uuid == rCard.id }) {
                            print("SyncService: Deleting local flashcard (remote tombstone): \(lCard.uuid)")
                            modelContext.delete(lCard)
                        }
                        continue
                    }

                    if let lCard = localSet.cards.first(where: { $0.uuid == rCard.id }) {
                        // Update existing card
                        lCard.question = rCard.question
                        lCard.answer = rCard.answer
                        lCard.type = rCard.type
                        lCard.interval = Int(rCard.interval)
                        lCard.easeFactor = rCard.easeFactor
                        lCard.repetitions = rCard.repetitions
                        lCard.nextReviewDate = rCard.nextReviewDate
                        lCard.isLearning = rCard.isLearning
                        lCard.learningStep = rCard.learningStep
                        lCard.frontImageUrl = rCard.frontImageUrl
                        lCard.backImageUrl = rCard.backImageUrl
                        lCard.isDeleted = false
                    } else {
                        // New local card
                        print("SyncService: Pulling remote flashcard: \(rCard.id)")
                        let lCard = PersistedFlashcard(
                            uuid: rCard.id,
                            question: rCard.question,
                            answer: rCard.answer,
                            type: rCard.type,
                            interval: Int(rCard.interval),
                            easeFactor: rCard.easeFactor,
                            repetitions: rCard.repetitions,
                            nextReviewDate: rCard.nextReviewDate,
                            isLearning: rCard.isLearning,
                            learningStep: rCard.learningStep,
                            frontImageUrl: rCard.frontImageUrl,
                            backImageUrl: rCard.backImageUrl
                        )
                        lCard.isDeleted = false
                        lCard.set = localSet
                        modelContext.insert(lCard)
                    }
                }
            }
            try modelContext.save()
        } catch {
            print("SyncService: Flashcard reconciliation failed -> \(error)")
        }
    }
    
    /// Heuristic to merge local deadlines that share the same Title, Date, and ModuleID
    /// This fixes past "double-tap" race conditions.
    private func deduplicateDeadlines(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<PersistedDeadline>()
        guard let allDeadlines = try? modelContext.fetch(descriptor) else { return }
        
        // Group by identification key: Title + Date + ModuleID
        var seen = [String: PersistedDeadline]()
        var toDelete = [PersistedDeadline]()
        
        for deadline in allDeadlines {
            // Normalize date to minute precision for comparison
            let cleanTitle = deadline.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "_")
            let minuteTimestamp = Int(deadline.date.timeIntervalSince1970 / 60)
            let key = "\(cleanTitle)_\(minuteTimestamp)_\(deadline.moduleId ?? "none")"
            
            if seen[key] != nil {
                print("SyncService: Found duplicate deadline: \(deadline.title). Scheduling deletion.")
                toDelete.append(deadline)
            } else {
                seen[key] = deadline
            }
        }
        
        if !toDelete.isEmpty {
            for d in toDelete {
                modelContext.delete(d)
            }
            try? modelContext.save()
            print("SyncService: De-duplicated \(toDelete.count) deadlines.")
        }
    }
}
