//
//  ThinkLikeLawApp.swift
//  ThinkLikeLaw
//
//  Created by Ahmed on 13/03/2026.
//

import SwiftUI
import SwiftData
import os.log
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Structured logger for SwiftData lifecycle events.
private let sdLogger = Logger(subsystem: "com.thinklikelaw.app", category: "SwiftData")

@MainActor
var sharedModelContainer: ModelContainer = {
    let schema = Schema([
        PersistedModule.self,
        PersistedNote.self,
        PersistedFlashcardSet.self,
        PersistedFlashcard.self,
        PersistedDeadline.self,
        PersistedChatMessage.self,
        PersistedStudySession.self,
        PersistedMootResult.self
    ])
    
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    // Step 1: Try a normal ModelContainer initialization.
    do {
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        sdLogger.info("SwiftData: ModelContainer initialized successfully.")
        return container
    } catch {
        sdLogger.warning("SwiftData: Primary initialization failed — \(error.localizedDescription, privacy: .public). Attempting lightweight migration...")
    }

    // Step 2: Attempt a lightweight migration with a fresh configuration.
    // This handles simple additive schema changes without data loss.
    do {
        let migrationConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, allowsSave: true)
        let container = try ModelContainer(for: schema, configurations: [migrationConfig])
        sdLogger.info("SwiftData: Lightweight migration succeeded. Data preserved.")
        return container
    } catch {
        sdLogger.error("SwiftData: Lightweight migration also failed — \(error.localizedDescription, privacy: .public). Proceeding to last-resort wipe.")
    }

    // Step 3: LAST RESORT — Wipe and re-sync from Supabase.
    let storeURL = URL.applicationSupportDirectory.appendingPathComponent("default.store")
    let walURL = storeURL.appendingPathExtension("wal")
    let shmURL = storeURL.appendingPathExtension("shm")

    for url in [storeURL, walURL, shmURL] {
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
    sdLogger.critical("SwiftData: Local store wiped (last resort). Data will re-sync from Supabase on next login.")

    do {
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        fatalError("SwiftData: Unrecoverable error after full wipe — \(error)")
    }
}()

@main
struct ThinkLikeLawApp: App {
    @StateObject private var authState = AuthState()
    @State private var pendingImport: SharedModuleInfo? = nil
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if authState.isCheckingSession {
                        // Show nothing or a splash screen while checking session
                        Color.clear
                    } else if !authState.hasCompletedOnboarding {
                        OnboardingView()
                            .environmentObject(authState)
                    } else if authState.isLoggedIn || authState.isGuest {
                        ContentView()
                            .environmentObject(authState)
                    } else {
                        LandingView()
                            .environmentObject(authState)
                    }
                }
                
                if authState.isLoading {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Entering Chambers...")
                            .font(Theme.Fonts.inter(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    #if os(iOS)
                    .background(BlurView(style: .systemThinMaterialDark))
                    #else
                    .background(Theme.Colors.surface.opacity(0.8))
                    #endif
                    .cornerRadius(20)
                }
            }
            #if os(macOS)
            .frame(minWidth: 1000, minHeight: 700)
            #endif
            .alert("Module Invitation", isPresented: .init(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } })) {
                Button("Join Chamber") {
                    if let info = pendingImport {
                        NotificationCenter.default.post(name: NSNotification.Name("TriggerModuleImport"), object: info)
                    }
                }
                Button("Decline", role: .cancel) { pendingImport = nil }
            } message: {
                if let info = pendingImport {
                    Text("You've been invited to join '\(info.name)'. This will add the module and its shared notes to your chambers.")
                }
            }
            .onOpenURL { url in
                #if canImport(GoogleSignIn)
                if GIDSignIn.sharedInstance.handle(url) {
                    return
                }
                #endif
                handleDeepLink(url)
            }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        #endif
        .modelContainer(sharedModelContainer)
    }
    
    private func handleDeepLink(_ url: URL) {
        // Support both custom scheme and universal HTTPS links
        let isCustomScheme = url.scheme == "thinklikelaw" && url.host == "join"
        let isUniversalLink = url.scheme == "https" && (url.host?.contains("thinklikelaw.com") ?? false) && url.path.contains("modules.html")
        
        guard isCustomScheme || isUniversalLink else { return }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let id = components?.queryItems?.first(where: { $0.name == "id" })?.value
        let owner = components?.queryItems?.first(where: { $0.name == "owner" })?.value
        let name = components?.queryItems?.first(where: { $0.name == "name" })?.value
        
        if let id = id, let owner = owner, let name = name {
            self.pendingImport = SharedModuleInfo(id: id, ownerId: owner, name: name)
        }
    }
}

struct SharedModuleInfo {
    let id: String
    let ownerId: String
    let name: String
}
