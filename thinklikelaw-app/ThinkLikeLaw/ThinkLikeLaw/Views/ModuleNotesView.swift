import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ModuleNotesView: View {
    let module: LawModule
    @Environment(\.modelContext) private var modelContext
    @Query var localNotes: [PersistedNote]
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authState: AuthState
    
    @State private var isLoading = false
    @State private var showingAddNote = false
    @State private var showingEditModule = false
    @State private var moduleToEdit: PersistedModule? = nil
    
    // Custom init to filter Query by moduleId
    init(module: LawModule) {
        print("DEBUG_CRASH: ModuleNotesView init for: \(module.name)")
        self.module = module
        let mid = module.id
        _localNotes = Query(filter: #Predicate<PersistedNote> { note in
            note.moduleId == mid && note.isDeleted != true
        }, sort: \.lastModified, order: .reverse)
    }
    
    var body: some View {
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if isLoading && localNotes.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if localNotes.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 70))
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.3))
                        
                        Text("No notes found in \(module.name)")
                            .font(Theme.Fonts.outfit(size: 18, weight: .semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        Text("Start by creating your first brief.")
                            .font(Theme.Fonts.inter(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
                        
                        Button {
                            showingAddNote = true
                        } label: {
                            Text("Create Brief")
                                .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                                .foregroundColor(Theme.Colors.onAccent)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Theme.Colors.accent)
                                .cornerRadius(12)
                        }
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(localNotes) { pNote in
                                noteRow(for: pNote)
                            }
                            .onDelete(perform: deleteNotes)
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationTitle(module.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button {
                        if let existing = try? modelContext.fetch(FetchDescriptor<PersistedModule>(predicate: #Predicate { $0.id == module.id })).first {
                            moduleToEdit = existing
                            showingEditModule = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .bold))
                            Text("Edit")
                                .font(Theme.Fonts.outfit(size: 14, weight: .bold))
                        }
                        .foregroundColor(Theme.Colors.onAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.accent)
                        .clipShape(Capsule())
                        .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    
                    if let shareURL = ModuleSharingService.shared.generateShareURL(moduleId: module.id, moduleName: module.name) {
                        ShareLink(item: shareURL) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18))
                                .foregroundColor(Theme.Colors.accent)
                        }
                    }
                    
                    Button {
                        showingAddNote = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.Colors.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddNote) {
            AddNoteSheet(module: module)
                .frame(minWidth: 500, minHeight: 600)
        }
        .sheet(isPresented: $showingEditModule) {
            if let target = moduleToEdit {
                EditModuleSheet(module: target, dismissParent: { dismiss() })
            }
        }
        .onAppear {
            print("DEBUG_CRASH: ModuleNotesView onAppear - local count: \(localNotes.count)")
            syncNotes()
        }
    }
    
    @ViewBuilder
    private func noteRow(for pNote: PersistedNote) -> some View {
        let nCreated = pNote.createdAt ?? Date()
        let note = LectureNote(
            id: pNote.id,
            title: pNote.title,
            content: pNote.content,
            moduleId: pNote.moduleId,
            preview: pNote.preview,
            createdAt: nCreated,
            lastModified: pNote.lastModified ?? nCreated,
            reviewCount: pNote.reviewCount,
            retentionScore: pNote.retentionScore,
            attachmentUrl: pNote.attachmentUrl,
            audioUrl: pNote.audioUrl,
            aiHistory: pNote.aiHistory
        )
        NavigationLink(destination: NoteEditorView(note: note)) {
            NoteRow(note: note)
        }
    }
    
    func syncNotes() {
        isLoading = true
        Task {
            do {
                print("DEBUG_CRASH: syncNotes - fetching remote for \(module.id)")
                let remote = try await SupabaseManager.shared.fetchLectures(moduleId: module.id)
                print("DEBUG_CRASH: syncNotes - fetched \(remote.count) lectures")
                await MainActor.run {
                    updateLocalNotes(with: remote)
                    self.isLoading = false
                }
            } catch {
                print("Note sync error: \(error)")
                self.isLoading = false
            }
        }
    }
    
    @MainActor
    func updateLocalNotes(with remote: [LectureNote]) {
        print("DEBUG_CRASH: updateLocalNotes - starting with \(remote.count) items")
        let pModules = try? modelContext.fetch(FetchDescriptor<PersistedModule>(predicate: #Predicate { $0.id == module.id }))
        let pModule = pModules?.first
        
        for r in remote {
            if let existing = localNotes.first(where: { $0.id == r.id }) {
                if r.isDeleted {
                    print("SyncService: Setting local note to deleted (remote tombstone): \(existing.title)")
                    existing.isDeleted = true
                } else {
                    existing.title = r.title
                    existing.content = r.content
                    existing.preview = r.preview
                    existing.lastModified = r.lastModified ?? r.createdAt
                }
            } else if !r.isDeleted {
                let newNote = PersistedNote(id: r.id, title: r.title, content: r.content, preview: r.preview, moduleId: module.id, createdAt: r.createdAt, lastModified: r.lastModified ?? r.createdAt, reviewCount: r.reviewCount, retentionScore: r.retentionScore, aiHistory: r.aiHistory, isDeleted: false)
                newNote.module = pModule
                modelContext.insert(newNote)
            }
        }
        try? modelContext.save()
    }
    
    func deleteNotes(at offsets: IndexSet) {
        let notesToDelete = offsets.map { localNotes[$0] }
        
        for pNote in notesToDelete {
            print("DEBUG_DELETE: Deleting note: \(pNote.title) [\(pNote.id)]")
            pNote.isDeleted = true
            
            // Delete from cloud (Soft delete)
            if !authState.isGuest {
                let noteId = pNote.id
                let title = pNote.title
                let content = pNote.content
                let mid = pNote.moduleId ?? module.id
                let preview = pNote.preview
                let modified = pNote.lastModified ?? Date()
                let reviewCount = pNote.reviewCount
                let retention = pNote.retentionScore
                let aiHistory = pNote.aiHistory
                let attach = pNote.attachmentUrl
                
                Task {
                    do {
                        try await SupabaseManager.shared.upsertLecture(
                            id: noteId,
                            moduleId: mid,
                            title: title,
                            content: content,
                            preview: preview,
                            lastModified: modified,
                            reviewCount: reviewCount,
                            retentionScore: retention,
                            aiHistory: aiHistory,
                            attachmentUrl: attach,
                            isDeleted: true
                        )
                        print("DEBUG_DELETE: Cloud tombstone successful for note \(title)")
                    } catch {
                        print("DEBUG_DELETE: Cloud tombstone FAILED for note \(title): \(error)")
                    }
                }
            }
        }
        
        do {
            try modelContext.save()
            print("DEBUG_DELETE: Local note state saved as deleted")
        } catch {
            print("DEBUG_DELETE: Failed to save local note delete: \(error)")
        }
    }
}

struct AddNoteSheet: View {
    let module: LawModule
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authState: AuthState
    
    @State private var title = ""
    @State private var preview = ""
    @State private var selectedFileURL: URL?
    @State private var isUploading = false
    @State private var showingFilePicker = false
    @State private var useAIMaker = true
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Brief Details")) {
                    TextField("Title (e.g. Duty of Care)", text: $title)
                    TextField("Short Preview/Context", text: $preview)
                }
                
                Section(header: Text("AI Assistant")) {
                    Toggle(isOn: $useAIMaker) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI Note Maker")
                                .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                            Text("Automatically structure and summarize your document into a legal brief.")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Brief")
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
                        if isUploading {
                            ProgressView().tint(Theme.Colors.accent)
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(title.isEmpty || isUploading)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    if let url = selectedFileURL {
                        HStack {
                            Image(systemName: url.pathExtension.lowercased() == "pdf" ? "doc.richtext.fill" : "doc.child.fill")
                                .foregroundColor(Theme.Colors.accent)
                            Text(url.lastPathComponent)
                                .font(Theme.Fonts.inter(size: 14, weight: .medium))
                            Spacer()
                            Button { selectedFileURL = nil } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                        .padding()
                        .background(Theme.Colors.surface)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                        .padding(.horizontal)
                    }
                    
                    Button {
                        showingFilePicker = true
                    } label: {
                        Label("Upload PDF/PPT", systemImage: "doc.badge.plus")
                            .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                            .foregroundColor(Theme.Colors.accent)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.Colors.accent.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.pdf, .presentation],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        selectedFileURL = url
                        if title.isEmpty {
                            title = url.deletingPathExtension().lastPathComponent
                        }
                    }
                case .failure(let error):
                    print("File picker error: \(error)")
                }
            }
        }
    }
    
    func save() {
        isUploading = true
        
        Task {
            var extractedContent = ""
            var attachmentUrl: String? = nil
            let noteId = UUID().uuidString
            
            // 1. Process File if selected
            if let fileURL = selectedFileURL {
                // Extract text if it's a PDF
                if fileURL.pathExtension.lowercased() == "pdf" {
                    extractedContent = NoteProcessingService.shared.extractText(from: fileURL) ?? ""
                    
                    // 1.1 AI Interpretation if enabled
                    if useAIMaker && !extractedContent.isEmpty {
                        do {
                            let (aiStructured, _) = try await AIService.shared.callAI(
                                tool: .generate_notes,
                                content: "Generate a comprehensive, structured legal note from this extracted text. Include Key Cases, Core Principles, and a Summary. Extracted Text:\n\n\(extractedContent.prefix(8000))" // Limit context to 8k chars
                            )
                            extractedContent = aiStructured
                        } catch {
                            print("AI Note Maker error: \(error)")
                        }
                    }
                }
                
                // Upload to Supabase Storage if not guest
                if !authState.isGuest {
                    do {
                        let secured = fileURL.startAccessingSecurityScopedResource()
                        let fileData = try Data(contentsOf: fileURL)
                        if secured { fileURL.stopAccessingSecurityScopedResource() }
                        
                        let mimeType = fileURL.pathExtension.lowercased() == "pdf" ? "application/pdf" : "application/vnd.ms-powerpoint"
                        let path = "lectures/\(noteId).\(fileURL.pathExtension.lowercased())"
                        
                        attachmentUrl = try await SupabaseManager.shared.uploadFile(data: fileData, path: path, mimeType: mimeType)
                    } catch {
                        print("File upload error: \(error)")
                    }
                }
            }
            
            // 2. Save locally
            await MainActor.run {
                let pModules = try? modelContext.fetch(FetchDescriptor<PersistedModule>(predicate: #Predicate { $0.id == module.id }))
                let pModule = pModules?.first
                
                let newNote = PersistedNote(
                    id: noteId,
                    title: title,
                    content: extractedContent,
                    preview: preview.isEmpty ? (extractedContent.prefix(200).description) : preview,
                    moduleId: module.id,
                    createdAt: Date(),
                    lastModified: Date(),
                    attachmentUrl: attachmentUrl
                )
                newNote.module = pModule
                modelContext.insert(newNote)
                try? modelContext.save()
            }
            
            // 3. Push to cloud if not guest
            if !authState.isGuest {
                do {
                    try await SupabaseManager.shared.upsertLecture(
                        id: noteId,
                        moduleId: module.id,
                        title: title,
                        content: extractedContent,
                        preview: preview.isEmpty ? (extractedContent.prefix(200).description) : preview,
                        lastModified: Date(),
                        reviewCount: 0,
                        retentionScore: 100.0,
                        aiHistory: [],
                        attachmentUrl: attachmentUrl
                    )
                } catch {
                    print("Error pushing note to cloud: \(error)")
                }
            }
            
            await MainActor.run {
                isUploading = false
                dismiss()
            }
        }
    }
}

// MARK: - Subviews

struct NoteRow: View {
    let note: LectureNote
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Theme.Colors.accent.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: note.audioUrl != nil ? "headphones" : "doc.text.fill")
                        .foregroundColor(Theme.Colors.accent)
                )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(note.title)
                    .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                HStack(spacing: 8) {
                    Text(note.preview)
                        .font(Theme.Fonts.inter(size: 13))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                        Text("\(Int(note.activeRetentionScore))%")
                    }
                    .font(Theme.Fonts.inter(size: 11, weight: .semibold))
                    .foregroundColor(note.activeRetentionScore < 80 ? Theme.Colors.accent : Theme.Colors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((note.activeRetentionScore < 80 ? Theme.Colors.accent : Theme.Colors.textSecondary).opacity(0.1))
                    .cornerRadius(4)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.Colors.textSecondary.opacity(0.4))
        }
        .padding(16)
        .glassCard()
    }
}

// MARK: - Lazy Loading Utility
struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: some View {
        build()
    }
}

#Preview {
    NavigationView {
        ModuleNotesView(module: LawModule(id: "1", name: "Contract Law", icon: "doc.fill", description: "Offer and Acceptance", archived: false, examDeadline: Date(), createdAt: Date()))
            .environmentObject(AuthState())
    }
}
