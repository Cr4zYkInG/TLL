import SwiftUI

struct FeatureGalleryView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // Group items by section
    private var groupedItems: [Dictionary<String, [NavigationItem]>.Element] {
        let itemsForHub = NavigationItem.allCases.filter { $0 != .hub && $0 != .dashboard }
        let itemsBySection = Dictionary(grouping: itemsForHub) { $0.section }
        let order = ["MAIN", "LEGAL TOOLS", "AI POWERED", "JUDICIAL LAB", "SUPPORT & REFERENCES"]
        return order.compactMap { section in
            itemsBySection.first { $0.key == section }
        }
    }
    
    private var isCompact: Bool {
        Theme.isPhone || horizontalSizeClass == .compact
    }
    
    private var columns: [GridItem] {
        let spacing: CGFloat = isCompact ? 12 : 16
        return [
            GridItem(.adaptive(minimum: isCompact ? 160 : 200), spacing: spacing)
        ]
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.bg.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Legal Hub")
                                .font(Theme.Fonts.outfit(size: 32, weight: .bold))
                                .foregroundColor(Theme.Colors.textPrimary)
                            Text("Access your full suite of AI legal assistants and community tools.")
                                .font(.custom("Inter-Regular", size: 14))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .padding(.horizontal, isCompact ? 16 : 24)
                        .padding(.top, 20)
                        
                        ForEach(groupedItems, id: \.key) { section, items in
                            VStack(alignment: .leading, spacing: 16) {
                                Text(section)
                                    .font(Theme.Fonts.outfit(size: 13, weight: .black))
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.6))
                                    .kerning(1.2)
                                    .padding(.horizontal, isCompact ? 16 : 24)
                                
                                LazyVGrid(columns: columns, spacing: isCompact ? 12 : 16) {
                                    ForEach(items) { item in
                                        FeatureGridItem(item: item)
                                    }
                                }
                                .padding(.horizontal, isCompact ? 16 : 24)
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
        }
    }
}

struct FeatureGridItem: View {
    let item: NavigationItem
    @EnvironmentObject var authState: AuthState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isCompact: Bool {
        Theme.isPhone || horizontalSizeClass == .compact
    }
    
    var body: some View {
        NavigationLink(destination: detailView(for: item)) {
            let isLocked = authState.isGuest && item.isAI
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: item.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isLocked ? Theme.Colors.textSecondary : Theme.Colors.accent)
                        .frame(width: 48, height: 48)
                        .background(Theme.Colors.accent.opacity(isLocked ? 0.05 : 0.1))
                        .cornerRadius(12)
                    
                    if item.isPro {
                        Text("PRO")
                            .font(.system(size: 8, weight: .black))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.accent)
                            .foregroundColor(Theme.Colors.onAccent)
                            .cornerRadius(4)
                            .offset(x: 4, y: -4)
                    }
                    
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .offset(x: 4, y: -4)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.label)
                        .font(Theme.Fonts.outfit(size: 14, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(tagline(for: item))
                        .font(Theme.Fonts.inter(size: 11))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(isCompact ? 12 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.surface)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func tagline(for item: NavigationItem) -> String {
        switch item {
        case .dashboard: return "Overview"
        case .community: return "Peer Network"
        case .news: return "Daily Updates"
        case .hub: return "Central Hub"
        case .modules: return "Course Management"
        case .notes: return "AI Note Maker"
        case .chat: return "Legal Consultant"
        case .dictation: return "Recording Helper"
        case .flashcards: return "Revision Tools"
        case .simulator: return "Mock Exams"
        case .spotter: return "Critical Thinking"
        case .interpret: return "Complex Analysis"
        case .marking: return "Essay Feedback"
        case .oscola: return "Citation Expert"
        case .deadlines: return "Schedule Tracking"
        case .settings: return "Preferences"
        case .moot: return "Adversarial Trials"
        case .scanner: return "OCR to IRAC"
        case .weaver: return "Authority Maps"
        @unknown default: return ""
        }
    }
    
    @ViewBuilder
    private func detailView(for item: NavigationItem) -> some View {
        if authState.isGuest && item.isAI {
            GuestRestrictionView(feature: item.label)
        } else {
            switch item {
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
            case .moot: MootLauncherSheet()
            case .scanner: CaseScannerView()
            case .weaver: StatuteWeaverView(initialTopic: "Duty of Care")
            @unknown default: EmptyView()
            }
        }
    }
}

#Preview {
    FeatureGalleryView()
        .environmentObject(AuthState())
}
