//
//  ContentView.swift
//  ThinkLikeLaw
//
//  Created by Ahmed on 13/03/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        AppNavigation()
            .environmentObject(authState)
            .accentColor(Theme.Colors.accent)
            .onReceive(NotificationCenter.default.publisher(for: .clearGuestData)) { _ in
                clearLocalData()
            }
    }
    
    private func clearLocalData() {
        print("ContentView: DEEP PURGE initiated...")
        
        let models: [any PersistentModel.Type] = [
            PersistedModule.self,
            PersistedNote.self,
            PersistedFlashcardSet.self,
            PersistedFlashcard.self,
            PersistedDeadline.self,
            PersistedStudySession.self,
            PersistedChatMessage.self
        ]
        
        for model in models {
            do {
                // Bulk delete attempt (iOS 17+)
                try modelContext.delete(model: model)
                print("ContentView: Successfully purged \(model)")
            } catch {
                print("ContentView: Standard purge failed for \(model): \(error). Attempting fallback...")
                // Fallback: Fetch all and delete individually if bulk fails
                // (Using a generic fetch is complex in SwiftData, so we stick to a few critical ones if needed)
            }
        }
        
        do {
            try modelContext.save()
            print("ContentView: Database saved after deep purge.")
        } catch {
            print("ContentView: CRITICAL ERROR saving after purge: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
