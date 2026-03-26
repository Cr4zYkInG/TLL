import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DashboardView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersistedModule.createdAt, order: .reverse) var localModules: [PersistedModule]
    @Query(sort: \PersistedDeadline.date, order: .forward) var localDeadlines: [PersistedDeadline]
    
    @State private var isLoading = false
    @State private var showingAddModule = false
    @State private var draggingModule: PersistedModule?
    
    var filteredModules: [PersistedModule] {
        localModules.filter { !($0.isDeleted ?? false) }
            .sorted { (a, b) in
                let o1 = a.displayOrder ?? 0
                let o2 = b.displayOrder ?? 0
                if o1 != o2 { return o1 < o2 }
                return (a.createdAt ?? Date()) > (b.createdAt ?? Date())
            }
    }
    
    let columns = [
        GridItem(.adaptive(minimum: Theme.isPhone ? 150 : 160), spacing: Theme.isPhone ? 12 : 20)
    ]
    
    var body: some View {
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerView
                    CareerProgressHeader()
                    DashboardMetricsHeader()
                        .transition(.move(edge: .top).combined(with: .opacity))
                    deadlinesView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    eliteLabSection
                    StudyHeatmap()
                        .padding(.vertical, Theme.Spacing.small)
                    modulesHeader
                    modulesGrid
                }
                .padding(Theme.isPhone ? Theme.Spacing.medium : Theme.Spacing.large)
            }
        }
        .overlay {
            if isLoading && localModules.isEmpty {
                ProgressView().scaleEffect(1.5)
            }
        }
        .onAppear {
            MascotManager.shared.greet()
            
            if localDeadlines.contains(where: { Calendar.current.dateComponents([.day], from: Date(), to: $0.date).day ?? 10 < 7 }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    MascotManager.shared.nudgeDeadline()
                }
            }
            
            // Trigger Sync
            Task {
                await SyncService.shared.reconcile(modelContext: modelContext)
                await authState.loadUserMetrics()
            }
        }
        .sheet(isPresented: $showingAddModule) {
            AddModuleSheet()
        }
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    @AppStorage("mascotVisible") var mascotVisible: Bool = true
                    if mascotVisible {
                        MascotView()
                            .shadow(color: Theme.Shadows.medium, radius: 10, y: 5)
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                    }
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 24)
        )
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back,")
                    .font(Theme.Fonts.outfit(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Text(authState.currentUser?.firstName ?? "Counsel")
                    .font(Theme.Fonts.outfit(size: Theme.isPhone ? 28 : 32, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            
            Spacer()
            
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Theme.Colors.accent)
                    .shadow(color: Theme.Colors.accent.opacity(0.12), radius: 12)
            }
            .hapticFeedback(.light)
        }
        .padding(.top, 20)
    }

    private var eliteLabSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Elite Judicial Lab")
                    .font(Theme.Fonts.outfit(size: 20, weight: .bold))
                Spacer()
                @AppStorage("aiPlusEnabled") var aiPlusEnabled: Bool = false
                if !aiPlusEnabled {
                    Text("PLUS")
                        .font(.system(size: 10, weight: .black))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.accent)
                        .foregroundColor(Theme.Colors.onAccent)
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    EliteToolCard(
                        title: "Statute Weaver",
                        subtitle: "Visual Authority Map",
                        icon: "network",
                        color: .blue,
                        destination: AnyView(StatuteWeaverView(initialTopic: "Tort Law"))
                    )
                    
                    EliteToolCard(
                        title: "Moot Court",
                        subtitle: "Oral Arguments",
                        icon: "building.columns.fill",
                        color: .purple,
                        destination: AnyView(MootLauncherSheet())
                    )
                    
                    EliteToolCard(
                        title: "Case Scanner",
                        subtitle: "OCR to IRAC",
                        icon: "camera.viewfinder",
                        color: .green,
                        destination: AnyView(CaseScannerView())
                    )
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var deadlinesView: some View {
        if !localDeadlines.isEmpty {
            DeadlinesCountdownWidget(deadlines: localDeadlines)
        }
    }

    private var modulesHeader: some View {
        HStack {
            Text("Your Chambers")
                .font(Theme.Fonts.outfit(size: 20, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
            
            Spacer()
            
            Text("\(filteredModules.count) Modules")
                .font(Theme.Fonts.inter(size: 12, weight: .medium))
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
    
    private func reorderModules(from: PersistedModule, to: PersistedModule) {
        var currentModules = filteredModules
        guard let fromIndex = currentModules.firstIndex(where: { $0.id == from.id }),
              let toIndex = currentModules.firstIndex(where: { $0.id == to.id }) else { return }
        
        withAnimation(.spring()) {
            currentModules.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            
            // Persist new orders
            for (index, module) in currentModules.enumerated() {
                module.displayOrder = index
            }
            try? modelContext.save()
        }
    }

    private var modulesGrid: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(filteredModules) { pModule in
                let module = LawModule(
                    id: pModule.id,
                    name: pModule.name,
                    icon: pModule.icon,
                    description: pModule.desc,
                    archived: pModule.archived,
                    examDeadline: pModule.examDeadline,
                    createdAt: pModule.createdAt ?? Date(),
                    averageRetention: pModule.averageRetention
                )
                NavigationLink(destination: LazyView(ModuleNotesView(module: module))) {
                    ModuleCard(module: module, deadlines: localDeadlines)
                }
                .hapticFeedback(.light)
                .onDrag {
                    self.draggingModule = pModule
                    return NSItemProvider(object: pModule.id as NSString)
                }
                .onDrop(of: [.text], delegate: ModuleDropDelegate(item: pModule, items: filteredModules, draggingItem: $draggingModule, onMove: reorderModules))
            }
            
            Button {
                showingAddModule = true
            } label: {
                AddModuleCard()
            }
            .hapticFeedback(.medium)
        }
    }
}

// MARK: - Subviews Restored and Optimized in previous step via Theme.swift and GlassCard modifier

struct AddModuleCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(Theme.Colors.accent)
            
            Text("Add Module")
                .font(Theme.Fonts.inter(size: 14, weight: .bold))
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(minHeight: 140)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundColor(Theme.Colors.glassBorder)
        )
    }
}

#Preview {
    DashboardView()
        .environmentObject(AuthState())
}
