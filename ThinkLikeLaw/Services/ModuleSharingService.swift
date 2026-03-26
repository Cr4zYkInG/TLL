import Foundation
import SwiftData
import Combine

class ModuleSharingService: ObservableObject {
    static let shared = ModuleSharingService()
    
    @Published var isImporting = false
    @Published var importError: String?
    
    private init() {}
    
    /**
     * Generate a sharing URL for a module
     */
    func generateShareURL(moduleId: String, moduleName: String) -> URL? {
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { return nil }
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.thinklikelaw.com"
        components.path = "/modules.html"
        components.queryItems = [
            URLQueryItem(name: "id", value: moduleId),
            URLQueryItem(name: "owner", value: userId),
            URLQueryItem(name: "name", value: moduleName)
        ]
        
        return components.url
    }
    
    /**
     * Import a module from a shared link
     */
    func importModule(id: String, ownerId: String, name: String, modelContext: ModelContext) async {
        await MainActor.run {
            self.isImporting = true
            self.importError = nil
        }
        
        do {
            // 1. Fetch remote notes from the owner
            let sharedNotes = try await SupabaseManager.shared.fetchLecturesForSharing(moduleId: id, ownerId: ownerId)
            
            await MainActor.run {
                // 2. Create the local module
                let newModule = PersistedModule(
                    id: id,
                    name: name,
                    icon: "book.closed.fill", // Default for shared
                    desc: "Shared by a fellow scholar",
                    archived: false
                )
                modelContext.insert(newModule)
                
                // 3. Import notes
                for sn in sharedNotes {
                    let newNote = PersistedNote(
                        id: sn.id,
                        title: sn.title,
                        content: sn.content,
                        preview: sn.preview,
                        createdAt: sn.createdAt,
                        lastModified: sn.lastModified ?? sn.createdAt,
                        reviewCount: sn.reviewCount,
                        retentionScore: sn.retentionScore,
                        aiHistory: sn.aiHistory
                    )
                    newNote.module = newModule
                    modelContext.insert(newNote)
                }
                
                try? modelContext.save()
                
                // 4. Sync new module to current user's Supabase (Forking)
                Task {
                    try? await SupabaseManager.shared.upsertModule(
                        id: id,
                        name: name,
                        icon: "book.closed.fill",
                        description: "Shared by a fellow scholar",
                        archived: false
                    )
                    
                    for sn in sharedNotes {
                        try? await SupabaseManager.shared.upsertLecture(
                            id: sn.id,
                            moduleId: id,
                            title: sn.title,
                            content: sn.content,
                            preview: sn.preview,
                            lastModified: sn.lastModified ?? sn.createdAt,
                            reviewCount: sn.reviewCount,
                            retentionScore: sn.retentionScore,
                            aiHistory: sn.aiHistory
                        )
                    }
                }
                
                self.isImporting = false
            }
        } catch {
            await MainActor.run {
                self.importError = "Failed to import module: \(error.localizedDescription)"
                self.isImporting = false
            }
        }
    }
}
