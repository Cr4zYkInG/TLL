import SwiftUI


enum NavigationItem: String, CaseIterable, Identifiable {
    // --- MAIN ---
    case dashboard, community, news, hub
    // --- LEGAL TOOLS ---
    case modules, notes
    // --- AI POWERED ---
    case chat, dictation, flashcards, simulator, spotter
    // --- SUPPORT ---
    case interpret, marking, oscola, deadlines, settings
    // --- JUDICIAL LAB ---
    case moot, scanner, weaver
    
    var id: String { self.rawValue }
    
    var section: String {
        switch self {
        case .dashboard, .community, .news, .hub: return "MAIN"
        case .modules, .notes: return "LEGAL TOOLS"
        case .chat, .dictation, .flashcards, .simulator, .spotter: return "AI POWERED"
        case .interpret, .marking, .oscola, .deadlines, .settings: return "SUPPORT & REFERENCES"
        case .moot, .scanner, .weaver: return "JUDICIAL LAB"
        }
    }
    
    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .community: return "Community Hub"
        case .news: return "Legal News"
        case .hub: return "Legal Hub"
        case .modules: return " My Modules"
        case .notes: return "Lecture Note Maker"
        case .chat: return "AI Chat"
        case .dictation: return "AI Lecture Dictation"
        case .flashcards: return "Revision Cards"
        case .simulator: return "Exam Simulator"
        case .spotter: return "Issue Spotter"
        case .interpret: return "Interpret AI"
        case .marking: return "Essay Marking"
        case .oscola: return "OSCOLA Assistant"
        case .deadlines: return "Upcoming Deadlines"
        case .settings: return "Settings"
        case .moot: return "Moot Career Hub"
        case .scanner: return "Case Briefing Scanner"
        case .weaver: return "The Statute Weaver"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .community: return "globe.europe.africa.fill"
        case .news: return "newspaper.fill"
        case .hub: return "circle.grid.3x3.fill"
        case .modules: return "folder.fill"
        case .notes: return "doc.text.fill"
        case .chat: return "sparkles"
        case .dictation: return "waveform.and.mic"
        case .flashcards: return "square.stack.3d.up.fill"
        case .simulator: return "pencil.and.outline"
        case .spotter: return "magnifyingglass.circle.fill"
        case .interpret: return "brain.head.profile"
        case .marking: return "checkmark.seal.fill"
        case .oscola: return "quote.bubble.fill"
        case .deadlines: return "calendar.badge.clock"
        case .settings: return "gearshape.fill"
        case .moot: return "building.columns.fill"
        case .scanner: return "camera.viewfinder"
        case .weaver: return "sparkles.rectangle.stack"
        }
    }
    
    var isPro: Bool {
        return [.interpret, .marking, .oscola].contains(self)
    }
    
    var isAI: Bool {
        return [.dictation, .simulator, .spotter, .interpret, .marking, .oscola, .moot, .scanner, .weaver].contains(self)
    }
}

struct AppNavigation: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var sharingService = ModuleSharingService.shared
    
    @State private var selectedItem: NavigationItem? = .dashboard
    
    private var isCompact: Bool {
        Theme.isPhone || horizontalSizeClass == .compact
    }
    
    var body: some View {
        Group {
            if isCompact {
                // iPhone Tab Bar (Simplified)
                TabView(selection: Binding($selectedItem, deselectValue: .dashboard)) {
                    DashboardView()
                        .tabItem { Label("Dash", systemImage: "square.grid.2x2.fill") }
                        .tag(NavigationItem.dashboard)
                    
                    ModulesListView()
                        .tabItem { Label("Study", systemImage: "book.fill") }
                        .tag(NavigationItem.modules)
                    
                    FeatureGalleryView()
                        .tabItem { Label("Hub", systemImage: "circle.grid.3x3.fill") }
                        .tag(NavigationItem.hub)
                    
                    AIChatView()
                        .tabItem { Label("Chat", systemImage: "sparkles") }
                        .tag(NavigationItem.chat)
                    
                    SettingsView()
                        .tabItem { Label("Me", systemImage: "person.circle.fill") }
                        .tag(NavigationItem.settings)
                }
                .accentColor(Theme.Colors.accent)
            } else {
                // iPad / Mac Premium Sidebar
                NavigationSplitView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Sidebar Header (Logo)
                        HStack {
                            LogoView()
                                .frame(height: 44)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                        
                        List(selection: $selectedItem) {
                            ForEach(groupedItems, id: \.key) { section, items in
                                Section(header: Text(section)
                                    .font(Theme.Fonts.outfit(size: 11, weight: .bold))
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.6))) {
                                    ForEach(items) { item in
                                        let isLocked = authState.isGuest && item.isAI
                                        NavigationLink(value: item) {
                                            HStack {
                                                Label(item.label, systemImage: isLocked ? "lock.fill" : item.icon)
                                                    .font(Theme.Fonts.outfit(size: 15, weight: .medium))
                                                    .foregroundColor(isLocked ? Theme.Colors.textSecondary.opacity(0.5) : Theme.Colors.textPrimary)
                                                
                                                Spacer()
                                                
                                                if item.isPro {
                                                    Text("PRO")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Theme.Colors.accent.opacity(0.1))
                                                        .cornerRadius(4)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(SidebarListStyle())
                        
                        // Sidebar Footer (Credits & Profile)
                        VStack(alignment: .leading, spacing: 16) {
                            Divider().background(Theme.Colors.glassBorder)
                            
                            // User Profile & AI Credit Widget
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    if let avatarUrl = authState.currentUser?.avatarUrl, let url = URL(string: avatarUrl) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 36, height: 36)
                                                    .clipShape(Circle())
                                            default:
                                                Circle()
                                                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                    .frame(width: 36, height: 36)
                                                    .overlay(
                                                        Text(String((authState.currentUser?.firstName.prefix(1) ?? "C")))
                                                            .foregroundColor(.white)
                                                            .font(.system(size: 14, weight: .bold))
                                                    )
                                            }
                                        }
                                    } else {
                                        Circle()
                                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Text(String((authState.currentUser?.firstName.prefix(1) ?? "C")))
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 14, weight: .bold))
                                            )
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(authState.currentUser?.firstName ?? "Counsel")
                                            .font(Theme.Fonts.inter(size: 14, weight: .bold))
                                        HStack(spacing: 4) {
                                            Text("FREE TIER")
                                                .font(.system(size: 10, weight: .black))
                                                .foregroundColor(.blue)
                                            
                                            Image(systemName: "ellipsis")
                                                .font(.system(size: 10))
                                                .foregroundColor(Theme.Colors.textSecondary)
                                        }
                                    }
                                    Spacer()
                                    
                                    Menu {
                                        Button(role: .destructive, action: { authState.logout() }) {
                                            Label("Sign Out", systemImage: "arrow.right.square")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .foregroundColor(Theme.Colors.textSecondary)
                                    }
                                }
                                
                                // Credit Bar
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Label("AI CREDITS", systemImage: "sparkles")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(Theme.Colors.textSecondary)
                                        Spacer()
                                        Text("\(authState.currentUser?.credits ?? 0)")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Theme.Colors.textSecondary.opacity(0.1))
                                                .frame(height: 4)
                                            
                                            Capsule()
                                                .fill(Theme.Colors.accent)
                                                .frame(width: geo.size.width * 0.65, height: 4)
                                        }
                                    }
                                    .frame(height: 4)
                                    
                                    Text("Free Plan")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
                                }
                                .padding(14)
                                .background(Theme.Colors.surface)
                                .cornerRadius(16)
                                .shadow(color: Theme.Shadows.soft, radius: 5, y: 2)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                            }
                            .padding(.horizontal, 12)
                        }
                        .padding(.bottom, 24)
                    }
                    .navigationTitle("")
                    .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
                } detail: {
                    NavigationStack {
                        detailView(for: selectedItem)
                    }
                    .background(Theme.Colors.bg.ignoresSafeArea())
                }
                .accentColor(Theme.Colors.accent)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TriggerModuleImport"))) { notification in
            if let info = notification.object as? SharedModuleInfo {
                Task {
                    await sharingService.importModule(id: info.id, ownerId: info.ownerId, name: info.name, modelContext: modelContext)
                }
            }
        }
        .overlay {
            if sharingService.isImporting {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                        Text("Entering New Chambers...")
                            .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    #if os(iOS)
                    .background(BlurView(style: .systemUltraThinMaterialDark))
                    #else
                    .background(Theme.Colors.surface.opacity(0.8))
                    #endif
                    .cornerRadius(20)
                }
            }
        }
        .task {
            // Centralized Sync: Run once on app navigation session start
            if !authState.isGuest {
                await SyncService.shared.reconcile(modelContext: modelContext)
            }
        }
    }
    
    private var groupedItems: [Dictionary<String, [NavigationItem]>.Element] {
        let items = NavigationItem.allCases.filter { item in
            if !isCompact && item == .hub {
                return false
            }
            return true
        }
        
        let itemsBySection = Dictionary(grouping: items) { $0.section }
        let order = ["MAIN", "LEGAL TOOLS", "AI POWERED", "JUDICIAL LAB", "SUPPORT & REFERENCES"]
        return order.compactMap { section in
            itemsBySection.first { $0.key == section }
        }
    }
    
    @ViewBuilder
    private func detailView(for item: NavigationItem?) -> some View {
        let selected = item ?? .dashboard
        
        // Restriction logic: Guests can't use AI tools
        if authState.isGuest && selected.isAI {
            GuestRestrictionView(feature: selected.label)
        } else {
            switch selected {
            case .dashboard: DashboardView()
            case .community: CommunityHubView()
            case .news: NewsView()
            case .hub: FeatureGalleryView()
            case .modules: ModulesListView()
            case .notes: LectureNotesToolView()
            case .chat: AIChatView()
            case .dictation: LectureRecorderView()
            case .flashcards: FlashcardsView()
            case .simulator: ExamSimulatorView()
            case .spotter: IssueSpotterView()
            case .interpret: InterpretAIView()
            case .marking: EssayMarkingView()
            case .oscola: OSCOLAAssistantView()
            case .deadlines: DeadlinesView()
            case .settings: SettingsView()
            case .moot: MootLauncherSheet(hideCloseButton: true)
            case .scanner: CaseScannerView(hideCloseButton: true)
            case .weaver: StatuteWeaverView(hideCloseButton: true, initialTopic: "Duty of Care")
            }
        }
    }
}

struct GuestRestrictionView: View {
    let feature: String
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.accent)
            
            VStack(spacing: 8) {
                Text("\(feature) is for Counsel")
                    .font(Theme.Fonts.outfit(size: 24, weight: .bold))
                Text("Sign in to unlock AI-powered legal assistants and sync your chambers across devices.")
                    .font(Theme.Fonts.inter(size: 16))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            NavigationLink(destination: LoginView()) {
                Text("Join the Inn")
                    .font(Theme.Fonts.outfit(size: 18, weight: .bold))
                    .foregroundColor(Theme.Colors.onAccent)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Theme.Colors.accent)
                    .cornerRadius(100)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.bg.ignoresSafeArea())
    }
}

struct PlaceholderView: View {
    let title: String
    var body: some View {
        VStack {
            Text(title)
                .font(Theme.Fonts.outfit(size: 32, weight: .bold))
            Text("Coming soon to the Chambers.")
                .font(Theme.Fonts.playfair(size: 18))
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
}

extension Binding {
    init(_ source: Binding<Value?>, deselectValue: Value) {
        self.init(
            get: { source.wrappedValue ?? deselectValue },
            set: { source.wrappedValue = $0 }
        )
    }
}

struct LogoView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Image(colorScheme == .dark ? "logo_light_text" : "logo_dark_text")
            .resizable()
            .scaledToFit()
    }
}

#Preview {
    AppNavigation()
        .environmentObject(AuthState())
}
