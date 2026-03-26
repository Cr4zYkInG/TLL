import SwiftUI
import SwiftData
import Foundation
import UniformTypeIdentifiers

enum LectureViewMode {
    case generator
    case folders
}

struct LectureNotesToolView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersistedModule.name) var modules: [PersistedModule]
    @Query(sort: \PersistedNote.lastModified, order: .reverse) var allNotes: [PersistedNote]
    
    @State private var viewMode: LectureViewMode = .generator
    @State private var searchText = ""
    @State private var showingAddNote = false
    
    var body: some View {
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Premium Segmented Picker
                HStack(spacing: 0) {
                    PickerButton(title: "Generator", icon: "sparkles", isSelected: viewMode == .generator) {
                        viewMode = .generator
                    }
                    
                    PickerButton(title: "Folders", icon: "folder.fill", isSelected: viewMode == .folders) {
                        viewMode = .folders
                    }
                }
                .padding(4)
                .background(Theme.Colors.surface.opacity(0.5))
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                if viewMode == .generator {
                    LectureGeneratorView()
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    LectureFoldersView(modules: modules, allNotes: allNotes, searchText: $searchText)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
        .animation(.spring(), value: viewMode)
    }
}

// MARK: - Picker Button helper
struct PickerButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(Theme.Fonts.outfit(size: 14, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Theme.Colors.accent : Color.clear)
            .foregroundColor(isSelected ? Theme.Colors.onAccent : Theme.Colors.textSecondary)
            .cornerRadius(8)
        }
        .animation(.spring(duration: 0.3), value: isSelected)
    }
}

// MARK: - Generator View (Left: Input, Right: Preview)
struct LectureGeneratorView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authState: AuthState
    @Query var modules: [PersistedModule]
    
    @State private var rawText = ""
    @State private var selectedFileURL: URL?
    @State private var isGenerating = false
    @State private var generatedNoteContent: String? = nil
    @State private var showingFilePicker = false
    @State private var selectedTargetModuleId: String? = nil
    
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // LEFT PANEL: Input
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lecture Notes Generator")
                                .font(Theme.Fonts.outfit(size: 32, weight: .bold))
                            Text("Upload slides or paste notes. We'll structure them with academic rigor.")
                                .font(Theme.Fonts.inter(size: 14))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        
                        // Upload Box
                        Button {
                            showingFilePicker = true
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: "icloud.and.arrow.up")
                                    .font(.system(size: 40))
                                    .foregroundColor(Theme.Colors.accent)
                                
                                Text(selectedFileURL?.lastPathComponent ?? "Upload PPT or PDF")
                                    .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                
                                Text("Drag & drop or click to browse")
                                    .font(Theme.Fonts.inter(size: 12))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Theme.Colors.surface)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Theme.Colors.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                            )
                        }
                        
                        HStack {
                            Divider()
                            Text("OR PASTE TEXT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                                .padding(.horizontal, 8)
                            Divider()
                        }
                        
                        // Text Input
                        ZStack(alignment: .topLeading) {
                            if rawText.isEmpty {
                                Text("Paste raw lecture content, transcript, or rough notes here...")
                                    .font(Theme.Fonts.inter(size: 14))
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                            }
                            
                            TextEditor(text: $rawText)
                                .font(Theme.Fonts.inter(size: 14))
                                .padding(12)
                                .background(Theme.Colors.surface)
                                .cornerRadius(12)
                                .frame(height: 250)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                                .scrollContentBackground(.hidden)
                        }
                        
                        // Module Selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Target Module")
                                .font(Theme.Fonts.outfit(size: 14, weight: .bold))
                                .foregroundColor(Theme.Colors.textSecondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(modules) { module in
                                        Button {
                                            selectedTargetModuleId = module.id
                                        } label: {
                                            Text(module.name)
                                                .font(Theme.Fonts.inter(size: 13, weight: .semibold))
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(selectedTargetModuleId == module.id ? Theme.Colors.accent : Theme.Colors.surface)
                                                .foregroundColor(selectedTargetModuleId == module.id ? Theme.Colors.onAccent : Theme.Colors.textPrimary)
                                                .cornerRadius(20)
                                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Generate Button
                        Button {
                            generateNotes()
                        } label: {
                            HStack {
                                if isGenerating {
                                    ProgressView().tint(Theme.Colors.onAccent)
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("Generate Academic Notes")
                                    Text("(75 credits)")
                                        .font(.system(size: 12))
                                        .opacity(0.7)
                                }
                            }
                            .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                            .foregroundColor(Theme.Colors.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.Colors.accent)
                            .cornerRadius(12)
                            .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 8, y: 4)
                        }
                        .disabled(isGenerating || (rawText.isEmpty && selectedFileURL == nil) || selectedTargetModuleId == nil)
                        
                        // Cat Mascot small
                        HStack {
                            Spacer()
                            MascotView()
                                .frame(width: 80, height: 80)
                                .opacity(0.8)
                        }
                    }
                    .padding(32)
                }
                #if os(iOS)
                .frame(width: geo.size.width * (UIDevice.current.userInterfaceIdiom == .pad ? 0.45 : 1.0))
                #else
                .frame(width: geo.size.width * 0.45)
                #endif
                
                #if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    Divider()
                        .background(Theme.Colors.glassBorder)
                    
                    // RIGHT PANEL: Preview / Output
                    ZStack {
                        Theme.Colors.bg.opacity(0.5)
                        
                        if let content = generatedNoteContent {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 20) {
                                    Text("Academic Blueprint")
                                        .font(Theme.Fonts.outfit(size: 24, weight: .bold))
                                        .padding(.bottom, 10)
                                    
                                    MarkdownText(text: content)
                                        .font(Theme.Fonts.inter(size: 16))
                                }
                                .padding(40)
                            }
                        } else {
                            VStack(spacing: 20) {
                                Image(systemName: "building.columns.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.1))
                                
                                Text("Detailed notes will appear here.")
                                    .font(Theme.Fonts.outfit(size: 18, weight: .semibold))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                #else
                Divider()
                    .background(Theme.Colors.glassBorder)
                
                // RIGHT PANEL: Preview / Output (Always shown on Mac)
                ZStack {
                    Theme.Colors.bg.opacity(0.5)
                    
                    if let content = generatedNoteContent {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Academic Blueprint")
                                    .font(Theme.Fonts.outfit(size: 24, weight: .bold))
                                    .padding(.bottom, 10)
                                
                                MarkdownText(text: content)
                                    .font(Theme.Fonts.inter(size: 16))
                            }
                            .padding(40)
                        }
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.Colors.textSecondary.opacity(0.1))
                            
                            Text("Detailed notes will appear here.")
                                .font(Theme.Fonts.outfit(size: 18, weight: .semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                #endif
            }
        }
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.pdf, .presentation]) { result in
            if case .success(let url) = result {
                selectedFileURL = url
            }
        }
    }
    
    func generateNotes() {
        isGenerating = true
        
        Task {
            var contentToProcess = rawText
            
            // 1. Process File text if selected
            if let fileURL = selectedFileURL {
                if fileURL.pathExtension.lowercased() == "pdf" {
                    let extracted = NoteProcessingService.shared.extractText(from: fileURL) ?? ""
                    contentToProcess += "\n\n\(extracted)"
                }
            }
            
            do {
                let (aiResult, _) = try await AIService.shared.callAI(
                    tool: .generate_notes,
                    content: "ACT AS AN ELITE LEGAL ACADEMIC. Generate hyper-detailed, OSCOLA-compliant legal notes from the following text. Use IRAC format for case analysis. Structure with H1 for topics, H2 for sub-points. Focus on High Rigor and Clarity. Input:\n\n\(contentToProcess.prefix(8000))"
                )
                
                await MainActor.run {
                    self.generatedNoteContent = aiResult
                    self.isGenerating = false
                    
                    // Save to DB
                    if let mid = selectedTargetModuleId {
                        saveNote(content: aiResult, moduleId: mid)
                    }
                }
            } catch {
                print("Generation failed: \(error)")
                await MainActor.run { self.isGenerating = false }
            }
        }
    }
    
    func saveNote(content: String, moduleId: String) {
        let noteId = UUID().uuidString
        let title = "Generated Brief \(Date().formatted(date: .abbreviated, time: .shortened))"
        let preview = content.prefix(200).description
        
        let pModules = try? modelContext.fetch(FetchDescriptor<PersistedModule>(predicate: #Predicate { $0.id == moduleId }))
        let pModule = pModules?.first
        
        let newNote = PersistedNote(
            id: noteId,
            title: title,
            content: content,
            preview: preview,
            moduleId: moduleId,
            createdAt: Date(),
            lastModified: Date()
        )
        newNote.module = pModule
        modelContext.insert(newNote)
        try? modelContext.save()
        
        // Push to cloud
        Task {
            try? await SupabaseManager.shared.upsertLecture(
                id: noteId,
                moduleId: moduleId,
                title: title,
                content: content,
                preview: preview,
                lastModified: Date()
            )
        }
    }
}

// MARK: - Folders View (Organized by Module)
struct LectureFoldersView: View {
    let modules: [PersistedModule]
    let allNotes: [PersistedNote]
    @Binding var searchText: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.Colors.textSecondary)
                    TextField("Search folders...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(12)
                .background(Theme.Colors.surface)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                .padding(.horizontal, 24)
                
                if modules.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "folder.badge.minus")
                            .font(.system(size: 64))
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.3))
                        Text("No modules found. Create one to organize your notes.")
                            .font(Theme.Fonts.inter(size: 16))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 20)], spacing: 20) {
                        ForEach(modules.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }) { module in
                            NavigationLink(destination: LazyView(ModuleNotesView(module: LawModule(
                                id: module.id,
                                name: module.name,
                                icon: module.icon,
                                description: module.desc,
                                archived: module.archived,
                                createdAt: module.createdAt ?? Date(),
                                averageRetention: module.averageRetention
                            )))) {
                                FolderCard(module: module)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.top, 24)
        }
    }
}
