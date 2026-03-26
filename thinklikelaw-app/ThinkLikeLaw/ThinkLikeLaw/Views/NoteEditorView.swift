import SwiftUI
import Combine
import SwiftData
#if canImport(PencilKit)
import PencilKit
#endif
import UniformTypeIdentifiers

struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authState: AuthState
    @State var note: LectureNote
    @State private var editorText: String
    @State private var isAIProcessing = false
    @State private var currentAITool: AIService.AITool? = nil
    @State private var aiResponse: String? = nil
    @State private var showAISheet = false
    @State private var selectedCitation: String? = nil
    @State private var showLecturePlayer = false
    @State private var showComingSoonAlert = false
    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    @State private var localPdfData: Data?
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var debouncedCitations: [String] = []
    @State private var citationSearchTask: Task<Void, Never>? = nil
    
    // PencilKit State
    #if canImport(PencilKit) && canImport(UIKit)
    @State private var canvasView = PKCanvasView()
    #endif
    @State private var isDrawingMode = false
    @State private var isOCRProcessing = false
    @AppStorage("mascotVisible") var mascotVisible: Bool = true
    
    // Paper Template State
    @State private var paperStyle: String
    @State private var paperColor: String
    
    // Custom Ink State
    #if canImport(PencilKit) && canImport(UIKit)
    @State private var currentInk = PKInkingTool(.pen, color: .black, width: 3)
    #endif
    
    // Focus Tracking
    @ObservedObject var studyManager = StudySessionManager.shared
    @ObservedObject var collaborationManager = CollaborationManager.shared
    
    init(note: LectureNote) {
        self._note = State(initialValue: note)
        self._editorText = State(initialValue: note.content)
        
        // Use defaults if missing
        self._paperStyle = State(initialValue: note.paperStyle ?? "blank")
        self._paperColor = State(initialValue: note.paperColor ?? "white")
        
        // Initialize canvas if data exists
        #if os(iOS)
        if let data = note.drawingData, let drawing = try? PencilKit.PKDrawing(data: data) {
            let canvas = PKCanvasView()
            canvas.drawing = drawing
            self._canvasView = State(initialValue: canvas)
            // Phase 79: Initialize sync counter
            DrawingSyncService.shared.resetSyncState(strokeCount: drawing.strokes.count)
        }
        #endif
        
        self._localPdfData = State(initialValue: note.pdfData)
    }
    
    #if os(iOS)
    @Environment(\.verticalSizeClass) var verticalSizeClass
    #endif
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerToolbar
                editorContent
                htmlBanner
                bottomControls
            }
            .applyEditorSheets(
                selectedCitation: $selectedCitation,
                showAISheet: $showAISheet,
                showShareSheet: $showShareSheet,
                showLecturePlayer: $showLecturePlayer,
                aiResponse: aiResponse,
                exportURL: exportURL,
                note: note,
                modelContext: modelContext
            )
            
            if isAIProcessing, let tool = currentAITool {
                ThinkingModeView(type: tool, isFinished: $isAIProcessing)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            studyManager.startSession(type: "notes", modelContext: modelContext, authState: authState)
            updateCitations()
        }
        .onChange(of: editorText) { _, _ in
            updateCitations()
        }
        .onDisappear {
            studyManager.stopSession(modelContext: modelContext, authState: authState)
            saveNoteState()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: Binding(get: { nil }, set: { _ in }))
        }
    }

    @ViewBuilder
    private var editorContent: some View {
        ZStack(alignment: .topLeading) {
            mainCanvas
            
            // Background Layer (Text/HTML)
            Group {
                if isDrawingMode {
                    TextEditor(text: $editorText)
                        .font(Theme.Fonts.inter(size: Theme.isPhone ? 16 : 18))
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(Theme.isPhone ? 16 : 30)
                } else if isHTMLNote {
                    NoteContentView(content: editorText, paperColor: paperColor)
                } else {
                    ScrollView {
                        NoteContentView(content: editorText, paperColor: paperColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Theme.isPhone ? 16 : 30)
                    }
                }
            }
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
            .onChange(of: editorText) {
                AudioManager.shared.playTypingHaptic()
            }
            
            // Overlay Layer (Drawing)
            if !isHTMLNote {
                #if canImport(UIKit) && canImport(PencilKit)
                DrawingCanvasView(canvasView: $canvasView, ink: $currentInk, moduleId: note.moduleId)
                    .allowsHitTesting(isDrawingMode)
                    .opacity(1.0)
                #else
                Color.clear
                #endif
            }
        }
    }

    @ViewBuilder
    private var bottomControls: some View {
        VStack {
            if isAIProcessing {
                ProgressView("Ben is thinking...")
                    .padding()
            }
            
            groundingBar
            aiActionBar
        }
        .frame(maxWidth: .infinity)
    }

    private var isLandscape: Bool {
        #if os(iOS)
        return verticalSizeClass == .compact
        #else
        return false
        #endif
    }

    @ViewBuilder
    private var headerToolbar: some View {
        HStack {
            Spacer()
            
            HStack(spacing: Theme.isPhone ? 12 : (isLandscape ? 12 : 20)) {
                Button(action: {}) { Image(systemName: "square.grid.2x2") }
                Button(action: {}) { Image(systemName: "magnifyingglass") }
                Button(action: {}) { Image(systemName: "bookmark") }
                Button(action: {}) { Image(systemName: "square.and.arrow.up") }
            }
            .font(.system(size: Theme.isPhone ? 15 : (isLandscape ? 16 : 18)))
            
            Spacer()
            
            if !isLandscape {
                HStack(spacing: 8) {
                    Text(note.title)
                        .font(Theme.Fonts.outfit(size: Theme.isPhone ? 15 : 17, weight: .bold))
                        .lineLimit(1)
                    
                    if !collaborationManager.activeUsers.isEmpty {
                        presenceIndicators
                    }
                }
                Spacer()
            }
            
            HStack(spacing: isLandscape ? 12 : 20) {
                if note.audioUrl != nil {
                    Button(action: { showLecturePlayer = true }) {
                        Image(systemName: "headphones")
                            .foregroundColor(Theme.Colors.accent)
                    }
                }
                #if canImport(PencilKit) && os(iOS)
                Button(action: { canvasView.undoManager?.undo() }) { Image(systemName: "arrow.uturn.backward") }
                Button(action: { canvasView.undoManager?.redo() }) { Image(systemName: "arrow.uturn.forward") }
                
                if !isHTMLNote {
                    PremiumToolPalette(ink: $currentInk, isDrawingMode: $isDrawingMode)
                }
                #endif
                
                settingsMenu
            }
            .font(.system(size: isLandscape ? 16 : 18))
        }
        .padding(.horizontal)
        .padding(.vertical, isLandscape ? 6 : 10)
        .background(Color(PlatformColor.windowBackgroundColor).opacity(0.95))
        .overlay(Divider(), alignment: .bottom)
    }

    @ViewBuilder
    private var presenceIndicators: some View {
        HStack(spacing: -8) {
            ForEach(collaborationManager.activeUsers.prefix(3)) { user in
                Circle()
                    .fill(Theme.Colors.accent)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(String(user.fullName.prefix(1)))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
            
            if collaborationManager.activeUsers.count > 3 {
                Text("+\(collaborationManager.activeUsers.count - 3)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.leading, 12)
            }
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private var settingsMenu: some View {
        Menu {
            Section("Media") {
                Button(action: { showDocumentPicker = true }) {
                    Label("Insert Document (PDF)", systemImage: "doc")
                }
                Button(action: { showImagePicker = true }) {
                    Label("Insert Image", systemImage: "photo")
                }
            }
            
            Section("Paper Type") {
                Button(action: { paperStyle = "blank" }) {
                    Label("Blank", systemImage: paperStyle == "blank" ? "checkmark" : "rectangle.dashed")
                }
                Button(action: { paperStyle = "lined" }) {
                    Label("Lined", systemImage: paperStyle == "lined" ? "checkmark" : "line.horizontal.3")
                }
                Button(action: { paperStyle = "grid" }) {
                    Label("Grid", systemImage: paperStyle == "grid" ? "checkmark" : "squareshape.split.3x3")
                }
            }
            
            Section("Export") {
                Button(action: { exportAsPDF() }) {
                    Label("Export as PDF", systemImage: "doc.richtext")
                }
                Button(action: { exportAsMarkdown() }) {
                    Label("Export as Markdown", systemImage: "text.quote.rtl")
                }
            }
            
            Section("Paper Color") {
                Button(action: { paperColor = "white" }) {
                    Label("White", systemImage: paperColor == "white" ? "checkmark" : "circle")
                }
                Button(action: { paperColor = "yellow" }) {
                    Label("Legal Yellow", systemImage: paperColor == "yellow" ? "checkmark" : "circle.fill")
                }
                Button(action: { paperColor = "dark" }) {
                    Label("Dark Slate", systemImage: paperColor == "dark" ? "checkmark" : "moon.fill")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    @ViewBuilder
    private var mainCanvas: some View {
        if let pdfData = localPdfData {
            PDFKitView(pdfData: pdfData)
                .ignoresSafeArea()
        } else {
            resolvePaperColor()
                .overlay(
                    LinearGradient(colors: [Theme.Colors.accent.opacity(0.02), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(resolvePaperStyle())
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var htmlBanner: some View {
        if isHTMLNote {
            HStack {
                Image(systemName: "globe")
                    .font(.system(size: 12))
                Text("WEBSITE RICH-TEXT: VIEW ONLY")
                    .font(.system(size: 10, weight: .bold))
                Spacer()
                Button(action: convertToMarkdown) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.and.outline")
                        Text("Convert to App Note (Enable Drawing)")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.accent)
                    .foregroundColor(Theme.Colors.onAccent)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Theme.Colors.accent.opacity(0.1))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var groundingBar: some View {
        let citations = detectedCitations
        if !citations.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.righthalf.filled")
                        .foregroundColor(Theme.Colors.accent)
                    Text("SMART GROUNDING:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    ForEach(citations, id: \.self) { citation in
                        Button(action: { selectedCitation = citation }) {
                            Text(citation)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Theme.Colors.accent.opacity(0.1))
                                .foregroundColor(Theme.Colors.accent)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Theme.Colors.accent.opacity(0.2), lineWidth: 1)
                                )
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var aiActionBar: some View {
        HStack(spacing: Theme.isPhone ? 8 : (isLandscape ? 10 : 20)) {
            AIActionButton(icon: "sparkles", label: Theme.isPhone ? "Suggest" : (isLandscape ? "Summarize" : "Summarize (IRAC)")) {
                performAIAction(tool: .summarize)
            }
            
            AIActionButton(icon: "checkmark.seal", label: Theme.isPhone ? "Audit" : (isLandscape ? "Audit" : "OSCOLA Audit")) {
                performAIAction(tool: .audit)
            }
            
            AIActionButton(icon: "graduationcap", label: Theme.isPhone ? "Mark" : (isLandscape ? "Mark" : "Exam Mark")) {
                performAIAction(tool: .mark)
            }
            
            if aiResponse != nil {
                AIActionButton(icon: "antenna.radiowaves.left.and.right", label: "Broadcast") {
                    collaborationManager.broadcast(content: aiResponse?.prefix(100).description ?? "Check out this brief!", type: "brief")
                    MascotManager.shared.speak("Broadcasted your insight to all scholars in this module!")
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(Theme.isPhone ? 8 : (isLandscape ? 8 : 12))
        .glassCard()
        .shadow(color: Theme.Shadows.medium, radius: 15, y: 10)
        .frame(maxWidth: Theme.isPhone ? .infinity : (isLandscape ? 400 : 700)) 
        .padding(.horizontal)
        .padding(.bottom, Theme.isPhone ? 10 : (isLandscape ? 10 : 20))
        .animation(Theme.Animation.spring, value: aiResponse != nil)
    }
    
    var detectedCitations: [String] { debouncedCitations }
    
    private func updateCitations() {
        citationSearchTask?.cancel()
        citationSearchTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second debounce
            if Task.isCancelled { return }
            
            let textToSearch = isHTMLNote ? editorText.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) : editorText
            let pattern = "((?:[A-Z][a-zA-Z0-9\\s'\",]+(?:v\\.?|v|Re|Ex\\s+parte|In\\s+re|In\\s+the\\s+matter\\s+of)\\s+[A-Z][a-zA-Z0-9\\s'\",]+)|(?:(?:Re|In\\s+re|Ex\\s+parte)\\s+[A-Z][a-zA-Z0-9\\s'\",]+))\\s+(\\[\\d{4}\\]\\s+[A-Z]+(?:\\s+[A-Z]+)?\\s+\\d+)"
            
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
            
            let matches = regex.matches(in: textToSearch, options: [], range: NSRange(textToSearch.startIndex..., in: textToSearch))
            var citations = Set<String>()
            
            for match in matches {
                if let nsRange = Range(match.range, in: textToSearch) {
                    citations.insert(String(textToSearch[nsRange]))
                }
            }
            
            if citations.isEmpty {
                let ncnPattern = "\\[\\d{4}\\]\\s+[A-Z]+(?:\\s+[A-Z]+)?\\s+\\d+"
                if let ncnRegex = try? NSRegularExpression(pattern: ncnPattern, options: [.caseInsensitive]) {
                    let ncnMatches = ncnRegex.matches(in: textToSearch, options: [], range: NSRange(textToSearch.startIndex..., in: textToSearch))
                    for m in ncnMatches {
                        if let r = Range(m.range, in: textToSearch) {
                            citations.insert(String(textToSearch[r]))
                        }
                    }
                }
            }
            
            let final = Array(citations).sorted()
            await MainActor.run {
                withAnimation { self.debouncedCitations = final }
            }
        }
    }
    
    func saveNoteState() {
        print("Saving note state: \(note.id)")
        
        let nid = note.id
        let contentToSave = editorText
        let previewToSave = editorText.prefix(200).description
        let moduleId = note.moduleId ?? ""
        
        // Update local SwiftData model
        let descriptor = FetchDescriptor<PersistedNote>(predicate: #Predicate { $0.id == nid })
        if let pNote = try? modelContext.fetch(descriptor).first {
            pNote.content = contentToSave
            pNote.preview = previewToSave
            pNote.lastModified = Date()
            #if canImport(PencilKit) && os(iOS)
            pNote.drawingData = canvasView.drawing.dataRepresentation()
            #endif
            pNote.paperStyle = paperStyle
            pNote.paperColor = paperColor
            pNote.pdfData = localPdfData
            try? modelContext.save()
        }
        
        // Push to cloud if not guest
        if !authState.isGuest {
            Task {
                do {
                    // Sync note content
                    if !moduleId.isEmpty {
                        try await SupabaseManager.shared.upsertLecture(
                            id: nid,
                            moduleId: moduleId,
                            title: note.title,
                            content: contentToSave,
                            preview: previewToSave,
                            lastModified: Date(),
                            reviewCount: note.reviewCount,
                            retentionScore: note.retentionScore,
                            aiHistory: note.aiHistory
                        )
                    }
                } catch {
                    print("Error syncing to cloud: \(error)")
                }
            }
        }
    }
    
    func handleOCR() {
        #if canImport(PencilKit) && os(iOS)
        guard !canvasView.drawing.bounds.isEmpty else { return }
        isOCRProcessing = true
        Task {
            do {
                let text = try await OCRService.shared.recognizeText(from: canvasView.drawing)
                await MainActor.run {
                    if !text.isEmpty {
                        self.editorText += "\n\n\(text)"
                        self.isDrawingMode = false 
                    }
                    self.isOCRProcessing = false
                }
            } catch {
                print("OCR Error: \(error)")
                self.isOCRProcessing = false
            }
        }
        #endif
    }
    
    func performAIAction(tool: AIService.AITool) {
        currentAITool = tool
        isAIProcessing = true
        Task {
            do {
                let (response, _) = try await AIService.shared.callAI(tool: tool, content: editorText)
                await MainActor.run {
                    self.aiResponse = response
                    withAnimation {
                        self.isAIProcessing = false
                        self.currentAITool = nil
                    }
                    self.showAISheet = true
                }
            } catch {
                print("AI Error: \(error)")
                await MainActor.run {
                    self.isAIProcessing = false
                    self.currentAITool = nil
                }
            }
        }
    }
    
    // MARK: - HTML Hygiene
    
    var isHTMLNote: Bool {
        let htmlTriggers = ["<p", "<h3", "<div", "<span", "<br", "style="]
        let content = editorText.lowercased()
        return htmlTriggers.contains { content.contains($0) }
    }
    
    func convertToMarkdown() {
        // Strip tags but keep some structure
        var clean = editorText
        
        // Headers
        clean = clean.replacingOccurrences(of: "<h3>", with: "### ")
        clean = clean.replacingOccurrences(of: "</h3>", with: "\n")
        
        // Paragraphs
        clean = clean.replacingOccurrences(of: "<p>", with: "\n")
        clean = clean.replacingOccurrences(of: "</p>", with: "\n")
        
        // Line breaks
        clean = clean.replacingOccurrences(of: "<br>", with: "\n")
        
        // Strip remaining tags using regex
        let pattern = "<[^>]+>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(location: 0, length: clean.utf16.count)
            clean = regex.stringByReplacingMatches(in: clean, options: [], range: range, withTemplate: "")
        }
        
        // Decode common HTML entities
        clean = clean.replacingOccurrences(of: "&nbsp;", with: " ")
        clean = clean.replacingOccurrences(of: "&amp;", with: "&")
        clean = clean.replacingOccurrences(of: "&quot;", with: "\"")
        
        withAnimation(Theme.Animation.spring) {
            self.editorText = clean.trimmingCharacters(in: .whitespacesAndNewlines)
            self.isDrawingMode = false // Switch to text to see result
        }
        
        MascotManager.shared.speak("Converted to clean Markdown! You can now draw and highlight.")
        AudioManager.shared.playSuccessHaptic()
        saveNoteState()
    }
    
    func exportAsPDF() {
        let nid = note.id
        let descriptor = FetchDescriptor<PersistedNote>(predicate: #Predicate { $0.id == nid })
        if let pNote = try? modelContext.fetch(descriptor).first {
            if let url = ExportService.shared.exportNoteToPDF(note: pNote) {
                self.exportURL = url
                self.showShareSheet = true
            }
        }
    }
    
    func exportAsMarkdown() {
        let nid = note.id
        let descriptor = FetchDescriptor<PersistedNote>(predicate: #Predicate { $0.id == nid })
        if let pNote = try? modelContext.fetch(descriptor).first {
            if let url = ExportService.shared.exportNoteToMarkdown(note: pNote) {
                self.exportURL = url
                self.showShareSheet = true
            }
        }
    }
    
    // MARK: - Paper Rendering Helpers
    
    @ViewBuilder
    func resolvePaperColor() -> some View {
        switch paperColor {
        case "yellow":
            Color(red: 255/255, green: 249/255, blue: 210/255) // Muted legal pad yellow
        case "dark":
            Color(red: 28/255, green: 28/255, blue: 30/255) // Classic dark slate
        case "white":
            Theme.Colors.bg
        default:
            Theme.Colors.bg // Standard dynamically adaptive theme background
        }
    }
    
    @ViewBuilder
    func resolvePaperStyle() -> some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width
                let h = geo.size.height
                
                if paperStyle == "lined" {
                    let spacing: CGFloat = 30
                    let startY: CGFloat = 100
                    for y in stride(from: startY, to: h, by: spacing) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: w, y: y))
                    }
                    // Left margin line (Legal pad style)
                    path.move(to: CGPoint(x: 80, y: 0))
                    path.addLine(to: CGPoint(x: 80, y: h))
                } else if paperStyle == "grid" {
                    let spacing: CGFloat = 20
                    for y in stride(from: 0, to: h, by: spacing) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: w, y: y))
                    }
                    for x in stride(from: 0, to: w, by: spacing) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: h))
                    }
                }
            }
            .stroke(paperColor == "dark" ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
            
            if paperStyle == "lined" {
                // Red margin line overlay
                Path { path in
                    path.move(to: CGPoint(x: 80, y: 0))
                    path.addLine(to: CGPoint(x: 80, y: geo.size.height))
                }
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Subviews


struct ColorDot: View {
    let color: Color
    let isSelected: Bool
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 20, height: 20)
            .overlay(
                Circle().stroke(Color.white, lineWidth: 2)
                    .opacity(isSelected ? 1 : 0)
            )
            .shadow(radius: 1)
    }
}

struct ThicknessLine: View {
    let width: CGFloat
    var isSelected: Bool = false
    var body: some View {
        Rectangle()
            .fill(isSelected ? Theme.Colors.accent : .primary.opacity(0.3))
            .frame(width: 20, height: width + 2)
            .cornerRadius(2)
    }
}

struct AIActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(Theme.Fonts.inter(size: 10, weight: .medium))
            }
            .foregroundColor(Theme.Colors.accent)
            .frame(maxWidth: .infinity)
        }
    }
}


struct CitationWrapper: Identifiable {
    let id: String
}

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
struct ShareSheet: View {
    let activityItems: [Any]
    var body: some View {
        Text("Sharing not implemented for native macOS yet. Use Export.")
    }
}
#endif

struct NoteEditorView_Previews: PreviewProvider {
    static var previews: some View {
        let mockNote = LectureNote(id: "1", title: "Contract Law 101", content: "Write some law here...", moduleId: "mod1", preview: "Write some...", createdAt: Date(), lastModified: Date(), reviewCount: 0, retentionScore: 1.0)
        NoteEditorView(note: mockNote)
    }
}

extension View {
    func applyEditorSheets(
        selectedCitation: Binding<String?>,
        showAISheet: Binding<Bool>,
        showShareSheet: Binding<Bool>,
        showLecturePlayer: Binding<Bool>,
        aiResponse: String?,
        exportURL: URL?,
        note: LectureNote,
        modelContext: ModelContext
    ) -> some View {
        self.sheet(item: Binding<CitationWrapper?>(
            get: { selectedCitation.wrappedValue.map { CitationWrapper(id: $0) } },
            set: { selectedCitation.wrappedValue = $0?.id }
        )) { wrapper in
            CitationPopupView(citation: wrapper.id)
        }
        .sheet(isPresented: showAISheet) {
            if let response = aiResponse {
                AIResultView(result: response)
            }
        }
        .sheet(isPresented: showShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: showLecturePlayer) {
            let nid = note.id
            let descriptor = FetchDescriptor<PersistedNote>(predicate: #Predicate { $0.id == nid })
            if let pNote = try? modelContext.fetch(descriptor).first {
                LecturePlayerView(note: pNote)
            }
        }
        #else
        .sheet(isPresented: showLecturePlayer) {
            let nid = note.id
            let descriptor = FetchDescriptor<PersistedNote>(predicate: #Predicate { $0.id == nid })
            if let pNote = try? modelContext.fetch(descriptor).first {
                LecturePlayerView(note: pNote)
            }
        }
        #endif
    }
}
