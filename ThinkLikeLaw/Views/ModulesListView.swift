import SwiftUI
import SwiftData
import Combine
import UniformTypeIdentifiers

struct ModulesListView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersistedModule.createdAt, order: .reverse) var localModules: [PersistedModule]
    @Query(sort: \PersistedDeadline.date, order: .forward) var localDeadlines: [PersistedDeadline]
    
    @State private var showingAddModule = false
    @State private var isLoading = false
    
    let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 20)
    ]
    
    @State private var moduleToEdit: PersistedModule? = nil
    @State private var moduleToDelete: PersistedModule? = nil
    @State private var draggingModule: PersistedModule?
    @State private var filter: ModuleFilter = .active
    
    enum ModuleFilter: String, CaseIterable {
        case active = "Active"
        case archived = "Archived"
    }
    
    var filteredModules: [PersistedModule] {
        localModules.filter { m in
            if m.isDeleted ?? false { return false }
            switch filter {
            case .active: return !m.archived
            case .archived: return m.archived
            }
        }
        .sorted { (a, b) in
            let o1 = a.displayOrder ?? 0
            let o2 = b.displayOrder ?? 0
            if o1 != o2 { return o1 < o2 }
            return (a.createdAt ?? Date()) > (b.createdAt ?? Date())
        }
    }
    
    var body: some View {
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("My Modules")
                            .font(Theme.Fonts.outfit(size: 28, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        Spacer()
                        
                        Button {
                            showingAddModule = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Theme.Colors.accent)
                        }
                    }
                    .padding(.top, 20)
                    
                    Picker("Filter", selection: $filter) {
                        ForEach(ModuleFilter.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .background(Theme.Colors.surface.opacity(0.1))
                    .cornerRadius(8)
                    
                    if filteredModules.isEmpty {
                        EmptyModulesView(filter: filter, action: { showingAddModule = true })
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 20)], spacing: 20) {
                            ForEach(filteredModules) { pModule in
                                let module = LawModule(
                                    id: pModule.id,
                                    name: pModule.name,
                                    icon: pModule.icon,
                                    description: pModule.desc,
                                    archived: pModule.archived,
                                    examDeadline: pModule.examDeadline,
                                    createdAt: pModule.createdAt ?? Date(),
                                    isShared: pModule.isShared ?? false,
                                    isDeleted: pModule.isDeleted ?? false,
                                    averageRetention: pModule.averageRetention
                                )
                                
                                NavigationLink(destination: LazyView(ModuleNotesView(module: module))) {
                                    FolderCard(module: pModule)
                                }
                                .onDrag {
                                    self.draggingModule = pModule
                                    return NSItemProvider(object: pModule.id as NSString)
                                }
                                .onDrop(of: [.text], delegate: ModuleDropDelegate(item: pModule, items: filteredModules, draggingItem: $draggingModule, onMove: reorderModules))
                                .contextMenu {
                                    Button {
                                        moduleToEdit = pModule
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    
                                    Button {
                                        toggleArchive(pModule)
                                    } label: {
                                        Label(pModule.archived ? "Restore" : "Archive", systemImage: pModule.archived ? "arrow.up.bin" : "archivebox")
                                    }
                                    
                                    Button(role: .destructive) {
                                        moduleToDelete = pModule
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.large)
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
        .sheet(isPresented: $showingAddModule) {
            AddModuleSheet()
                .frame(minWidth: 500, minHeight: 500)
        }
        .sheet(item: $moduleToEdit) { module in
            EditModuleSheet(module: module)
                .frame(minWidth: 500, minHeight: 500)
        }
        .alert(item: $moduleToDelete) { module in
            Alert(
                title: Text("Delete \(module.name)?"),
                message: Text("This will permanently delete the module and all its notes. This cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteModule(module)
                },
                secondaryButton: .cancel()
              )
        }
    }
    
    // Logic for mutations (Syncing handled by centralized AppNavigation)
    func deleteModule(_ module: PersistedModule) {
        print("DEBUG_DELETE: Starting deletion for module: \(module.name) [\(module.id)]")
        
        let mid = module.id
        
        // 1. Mark module as deleted locally
        module.isDeleted = true
        
        // 2. Mark associated deadlines as deleted locally
        for deadline in localDeadlines where deadline.moduleId == mid {
            deadline.isDeleted = true
        }
        
        do {
            try modelContext.save()
            print("DEBUG_DELETE: Local state saved as deleted")
        } catch {
            print("DEBUG_DELETE: Failed to save local delete state: \(error)")
        }
        
        // 3. Push to cloud
        if !authState.isGuest {
            Task {
                do {
                    // Use deleteModule which cascades soft-delete to lectures + deadlines
                    try await SupabaseManager.shared.deleteModule(id: mid)
                    print("DEBUG_DELETE: Cloud tombstone successful for \(mid)")
                    
                    // Also trigger a background sync to be safe
                    await SyncService.shared.reconcile(modelContext: modelContext)
                } catch {
                    print("DEBUG_DELETE: Cloud tombstone FAILED: \(error)")
                }
            }
        }
    }
    
    private func toggleArchive(_ module: PersistedModule) {
        withAnimation {
            module.archived.toggle()
            try? modelContext.save()
            
            // Sync to Supabase
            if !authState.isGuest {
                Task {
                    try? await SupabaseManager.shared.upsertModule(
                        id: module.id,
                        name: module.name,
                        icon: module.icon,
                        description: module.desc,
                        archived: module.archived,
                        isShared: module.isShared ?? false
                    )
                }
            }
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
}

struct EmptyModulesView: View {
    let filter: ModulesListView.ModuleFilter
    let action: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 100)
            Image(systemName: filter == .active ? "folder.badge.plus" : "archivebox")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.textSecondary.opacity(0.3))
            
            Text(filter == .active ? "No modules yet" : "No archived modules")
                .font(Theme.Fonts.outfit(size: 20, weight: .semibold))
            
            Text(filter == .active ? "Add your first law module to start tracking your revision." : "You haven't archived any modules yet.")
                .font(Theme.Fonts.inter(size: 14))
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if filter == .active {
                Button(action: action) {
                    Text("Add Module")
                        .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                        .foregroundColor(Theme.Colors.onAccent)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.accent)
                        .cornerRadius(12)
                }
            }
        }
        .padding(Theme.Spacing.huge)
        .frame(maxWidth: .infinity)
    }
}

struct AddModuleSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authState: AuthState
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedIcon = "folder.fill"
    @State private var isSaving = false

    
    let icons = [
        "folder.fill", "doc.text.fill", "hammer.fill", "scalemass.fill", "bookmark.fill", 
        "book.fill", "building.columns.fill", "briefcase.fill", "books.vertical.fill",
        "chart.bar.doc.horizontal.fill", "shield.lefthalf.filled", "graduationcap.fill",
        "scroll.fill", "magnifyingglass.circle.fill", "doc.richtext.fill"
    ]
    
    let columns = [
        GridItem(.adaptive(minimum: 50), spacing: 20)
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Module Details")) {
                    TextField("Module Name (e.g. Contract Law)", text: $name)
                    TextField("Description", text: $description)
                }
                
                
                Section(header: Text("Icon")) {
                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .frame(width: 50, height: 50)
                                .background(selectedIcon == icon ? Theme.Colors.accent.opacity(0.2) : Color.clear)
                                .clipShape(Circle())
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Module")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(name.isEmpty || isSaving)
                }

            }
        }
    }
    
    func save() {
        guard !isSaving else { return }
        isSaving = true
        
        let moduleId = UUID().uuidString
        let newModule = PersistedModule(
            id: moduleId,
            name: name,
            icon: selectedIcon,
            desc: description,
            archived: false,
            createdAt: Date()
        )
        modelContext.insert(newModule)
        try? modelContext.save()
        
        // If not a guest, push to Supabase
        if !authState.isGuest {
            Task {
                do {
                    try await SupabaseManager.shared.upsertModule(
                        id: moduleId,
                        name: name,
                        icon: selectedIcon,
                        description: description,
                        archived: false
                    )
                } catch {
                    print("Error pushing module to cloud: \(error)")
                }
                await MainActor.run {
                    dismiss()
                }
            }
        } else {
            dismiss()
        }
    }

}

struct EditModuleSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authState: AuthState
    
    let module: PersistedModule
    var dismissParent: (() -> Void)? = nil
    
    @State private var name: String
    @State private var description: String
    @State private var selectedIcon: String
    @State private var isShared: Bool
    @State private var isSaving = false

    
    init(module: PersistedModule, dismissParent: (() -> Void)? = nil) {
        self.module = module
        self.dismissParent = dismissParent
        _name = State(initialValue: module.name)
        _description = State(initialValue: module.desc)
        _selectedIcon = State(initialValue: module.icon)
        _isShared = State(initialValue: module.isShared ?? false)
    }
    
    let icons = [
        "folder.fill", "doc.text.fill", "hammer.fill", "scalemass.fill", "bookmark.fill", 
        "book.fill", "building.columns.fill", "briefcase.fill", "books.vertical.fill",
        "chart.bar.doc.horizontal.fill", "shield.lefthalf.filled", "graduationcap.fill",
        "scroll.fill", "magnifyingglass.circle.fill", "doc.richtext.fill"
    ]
    
    let columns = [
        GridItem(.adaptive(minimum: 50), spacing: 20)
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Module Details")) {
                    TextField("Module Name (e.g. Contract Law)", text: $name)
                    TextField("Description", text: $description)
                }
                

                
                Section(header: Text("Icon")) {
                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .frame(width: 50, height: 50)
                                .background(selectedIcon == icon ? Theme.Colors.accent.opacity(0.2) : Color.clear)
                                .clipShape(Circle())
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Privacy & Sharing")) {
                    Toggle(isOn: $isShared) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Share Module")
                                .font(.body)
                            Text("Allow friends with a link to view these notes.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(Theme.Colors.accent)
                }
                
                Section {
                    Button("Delete Module") {
                        delete()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Edit Module")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Done")
                        }
                    }
                    .disabled(name.isEmpty || isSaving)
                }

            }
        }
    }
    
    func save() {
        guard !isSaving else { return }
        isSaving = true
        
        module.name = name
        module.desc = description
        module.icon = selectedIcon
        module.isShared = isShared
        
        try? modelContext.save()
        
        // If not a guest, push to Supabase
        if !authState.isGuest {
            let id = module.id
            let archived = module.archived
            Task {
                do {
                    try await SupabaseManager.shared.upsertModule(
                        id: id,
                        name: name,
                        icon: selectedIcon,
                        description: description,
                        archived: archived,
                        isShared: isShared
                    )
                } catch {
                    print("Error pushing module update to cloud: \(error)")
                }
                await MainActor.run {
                    dismiss()
                }
            }
        } else {
            dismiss()
        }
    }
    
    func delete() {
        guard !isSaving else { return }
        isSaving = true
        
        module.isDeleted = true
        try? modelContext.save()
        
        if !authState.isGuest {
            let id = module.id
            
            Task {
                do {
                    // Use deleteModule which cascades soft-delete to lectures + deadlines
                    try await SupabaseManager.shared.deleteModule(id: id)
                } catch {
                    print("EditModuleSheet: Cloud delete failed: \(error)")
                }
                await MainActor.run {
                    dismiss()
                    dismissParent?()
                }
            }
        } else {
            dismiss()
            dismissParent?()
        }
    }

}
