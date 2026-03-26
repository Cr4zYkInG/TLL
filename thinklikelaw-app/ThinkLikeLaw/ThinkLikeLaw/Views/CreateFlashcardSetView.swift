import SwiftUI
import SwiftData

struct CreateFlashcardSetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    enum CreationMode { case ai, manual }
    @State private var mode: CreationMode = .ai
    
    // AI Mode State
    @State private var topic = ""
    @State private var cardCount = 10
    @State private var isGenerating = false
    
    // Manual Mode State
    @State private var manualTopic = ""
    @State private var manualCards: [ManualCard] = [ManualCard()]
    
    @Query(sort: \PersistedModule.name) var modules: [PersistedModule]
    @State private var selectedModuleId: String?
    
    // Anki-style Deck Settings
    @State private var showAdvancedSettings = false
    @State private var step1: Int = 1
    @State private var step2: Int = 10
    @State private var gradInt: Int = 1
    @State private var easyInt: Int = 4
    
    @State private var errorMessage: String?
    
    struct ManualCard: Identifiable {
        let id = UUID()
        var question = ""
        var answer = ""
        var type = "basic"
        var frontImageUrl = ""
        var backImageUrl = ""
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.bgLight.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Mode Picker
                    modePicker
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 28) {
                            // Module Link
                            moduleLinkSection
                            
                            if mode == .ai {
                                aiSection
                                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                            } else {
                                manualSection
                                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                            }
                            
                            advancedSettingsSection
                        }
                        .padding(24)
                    }
                    
                    // Footer Action
                    footerAction
                }
            }
            .navigationTitle("Initialize Deck")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(Theme.Fonts.inter(size: 15, weight: .medium))
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach([CreationMode.ai, .manual], id: \.self) { item in
                Button(action: { withAnimation(.spring(response: 0.35)) { mode = item } }) {
                    HStack(spacing: 8) {
                        Image(systemName: item == .ai ? "sparkles" : "pencil.and.outline")
                            .font(.system(size: 14, weight: .bold))
                        Text(item == .ai ? "AI Generation" : "Manual Entry")
                            .font(Theme.Fonts.outfit(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(mode == item ? Theme.Colors.accent : Color.clear)
                    .foregroundColor(mode == item ? Theme.Colors.onAccent : Theme.Colors.textSecondary)
                    .cornerRadius(10)
                }
            }
        }
        .padding(4)
        .background(Theme.Colors.surface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.glassBorder, lineWidth: 1))
    }
    
    private var moduleLinkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("LINK TO CHAMBER", systemImage: "link")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(1.5)
            
            HStack {
                Text(modules.first(where: { $0.id == selectedModuleId })?.name ?? "No Module Linked")
                    .font(Theme.Fonts.inter(size: 15, weight: .medium))
                    .foregroundColor(selectedModuleId == nil ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                
                Spacer()
                
                Menu {
                    Button("No Module") { selectedModuleId = nil }
                    ForEach(modules) { module in
                        Button(module.name) { selectedModuleId = module.id }
                    }
                } label: {
                    Image(systemName: "chevron.up.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.Colors.accent)
                        .padding(8)
                        .background(Theme.Colors.accent.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.Colors.surface)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder, lineWidth: 1))
        }
    }
    
    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Counsel Assistant")
                    .font(Theme.Fonts.outfit(size: 20, weight: .bold))
                Text("Our legal-tuned AI will research authorities and draft precise ratios.")
                    .font(Theme.Fonts.inter(size: 14))
                    .foregroundColor(Theme.Colors.textSecondaryLight)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("LEGAL TOPIC")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .tracking(1.5)
                
                TextField("e.g. Terms of the Postal Rule...", text: $topic)
                    .font(Theme.Fonts.inter(size: 16))
                    .padding(18)
                    .background(Theme.Colors.surface)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder, lineWidth: 1))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("CARD QUANTITY")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .tracking(1.5)
                    Spacer()
                    Text("\(cardCount)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.accent)
                }
                
                Slider(value: .init(get: { Double(cardCount) }, set: { cardCount = Int($0) }), in: 5...25, step: 1)
                    .tint(Theme.Colors.accent)
            }
            .padding(18)
            .background(Theme.Colors.surface)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder, lineWidth: 1))
        }
    }
    
    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Manual Draft")
                    .font(Theme.Fonts.outfit(size: 20, weight: .bold))
                Text("Compose your own high-fidelity cards for specific case law.")
                    .font(Theme.Fonts.inter(size: 14))
                    .foregroundColor(Theme.Colors.textSecondaryLight)
            }
            
            TextField("Deck Topic (e.g. Contract Formation)", text: $manualTopic)
                .font(Theme.Fonts.inter(size: 18, weight: .bold))
                .padding(18)
                .background(Theme.Colors.surface)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder, lineWidth: 1))
            
            VStack(spacing: 16) {
                ForEach($manualCards.indices, id: \.self) { index in
                    manualCardInput(index: index)
                }
            }
            
            Button(action: { 
                withAnimation(.spring()) {
                    manualCards.append(ManualCard())
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Next Card")
                        .font(Theme.Fonts.outfit(size: 15, weight: .bold))
                }
                .foregroundColor(Theme.Colors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.Colors.accent.opacity(0.1))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.accent.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4])))
            }
        }
    }
    
    @ViewBuilder
    private func manualCardInput(index: Int) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("CARD \(index + 1)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Spacer()
                
                Menu {
                    Button("Basic") { manualCards[index].type = "basic" }
                    Button("Cloze Deletion") { manualCards[index].type = "cloze" }
                    Button("Reverse (A↔B)") { manualCards[index].type = "reverse" }
                    Divider()
                    Button(role: .destructive) { 
                        if manualCards.count > 1 {
                            manualCards.remove(at: index)
                        }
                    } label: {
                        Label("Remove Card", systemImage: "trash")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(manualCards[index].type.uppercased())
                            .font(.system(size: 10, weight: .bold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(Theme.Colors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.accent.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(16)
            
            Divider().background(Theme.Colors.glassBorder)
            
            VStack(spacing: 14) {
                // Question
                VStack(alignment: .leading, spacing: 6) {
                    Text(manualCards[index].type == "cloze" ? "CLOZE TEXT" : "FRONT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    TextEditor(text: $manualCards[index].question)
                        .font(Theme.Fonts.inter(size: 15))
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(Theme.Colors.bgLight.opacity(0.5))
                        .cornerRadius(8)
                }
                
                // Answer (if not cloze)
                if manualCards[index].type != "cloze" {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("BACK")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        TextEditor(text: $manualCards[index].answer)
                            .font(Theme.Fonts.inter(size: 15))
                            .frame(minHeight: 60)
                            .padding(8)
                            .background(Theme.Colors.bgLight.opacity(0.5))
                            .cornerRadius(8)
                    }
                }
                
                // Advanced Media URLs
                HStack(spacing: 10) {
                    Label("Media (Optional)", systemImage: "photo")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    TextField("Image URL (Front)", text: $manualCards[index].frontImageUrl)
                        .font(.system(size: 10))
                        .padding(6)
                        .background(Theme.Colors.bgLight.opacity(0.5))
                        .cornerRadius(6)
                }
            }
            .padding(16)
        }
        .background(Theme.Colors.surface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.glassBorder, lineWidth: 1))
    }
    
    private var advancedSettingsSection: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation { showAdvancedSettings.toggle() } }) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("Algorithm Settings")
                        .font(Theme.Fonts.outfit(size: 15, weight: .bold))
                    Spacer()
                    Image(systemName: showAdvancedSettings ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(18)
            }
            
            if showAdvancedSettings {
                VStack(alignment: .leading, spacing: 20) {
                    Divider().background(Theme.Colors.glassBorder)
                    
                    Text("Fine-tune the SM-2 Spaced Repetition logic for this deck.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    VStack(spacing: 14) {
                        SettingRow(label: "Learning Steps (mins)", help: "1, 10") {
                            HStack {
                                TextField("1", value: $step1, format: .number)
                                    .textFieldStyle(.roundedBorder).frame(width: 44)
                                Text("→")
                                TextField("10", value: $step2, format: .number)
                                    .textFieldStyle(.roundedBorder).frame(width: 44)
                            }
                        }
                        
                        SettingRow(label: "Graduating Interval", help: "Days") {
                            TextField("1", value: $gradInt, format: .number)
                                .textFieldStyle(.roundedBorder).frame(width: 60)
                        }
                        
                        SettingRow(label: "Easy Interval", help: "Days") {
                            TextField("4", value: $easyInt, format: .number)
                                .textFieldStyle(.roundedBorder).frame(width: 60)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
        .background(Theme.Colors.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder, lineWidth: 1))
    }
    
    private var footerAction: some View {
        VStack(spacing: 12) {
            if let error = errorMessage {
                Text(error)
                    .font(Theme.Fonts.inter(size: 13, weight: .medium))
                    .foregroundColor(.red)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            Button(action: {
                if mode == .ai { generateAISet() }
                else { saveManualSet() }
            }) {
                HStack(spacing: 12) {
                    if isGenerating {
                        ProgressView().tint(.white)
                    }
                    Text(mode == .ai ? (isGenerating ? "Consulting Case Law..." : "Generate AI Flashcards") : "Save Deck to Chambers")
                        .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isButtonDisabled || isGenerating ? Theme.Colors.textSecondaryLight.opacity(0.3) : Theme.Colors.accent)
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: (isButtonDisabled || isGenerating) ? .clear : Theme.Colors.accent.opacity(0.3), radius: 10, y: 5)
            }
            .disabled(isButtonDisabled || isGenerating)
        }
        .padding(24)
        .background(Theme.Colors.bgLight)
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: -5)
    }
    
    // MARK: - Logic (Unchanged from original but cleanified)
    
    private var isButtonDisabled: Bool {
        if mode == .ai { return topic.isEmpty }
        return manualTopic.isEmpty || manualCards.filter({ !$0.question.isEmpty }).isEmpty
    }
    
    private func generateAISet() {
        isGenerating = true
        errorMessage = nil
        Task {
            do {
                let steps = ["Analyzing Judicial Precedent...", "Filtering Ratio Decidendi...", "Cross-Referencing Authorities..."]
                for _ in steps { try? await Task.sleep(nanoseconds: 600_000_000) }
                
                let moduleName = modules.first(where: { $0.id == selectedModuleId })?.name
                let context: [String: Any] = ["module": moduleName ?? "General Law", "card_count": cardCount]
                let (response, _) = try await AIService.shared.callAI(tool: .flashcards, content: "Generate academic flashcards on: \(topic)", context: context)
                guard let data = response.data(using: .utf8) else { throw NSError(domain: "Parse", code: 0) }
                
                var cards: [FlashcardData] = []
                let decoder = JSONDecoder()
                if let decoded = try? decoder.decode(FlashcardResponse.self, from: data) { cards = decoded.flashcards }
                else if let arrayDecoded = try? decoder.decode([FlashcardData].self, from: data) { cards = arrayDecoded }
                
                if cards.isEmpty { throw NSError(domain: "Parse", code: 2) }
                
                let newSet = PersistedFlashcardSet(topic: topic, moduleId: selectedModuleId, moduleName: moduleName, learningSteps: [step1, step2], graduatingInterval: gradInt, easyInterval: easyInt)
                
                // Link to module object
                if let module = modules.first(where: { $0.id == selectedModuleId }) {
                    newSet.module = module
                }
                
                modelContext.insert(newSet)
                
                for cardData in cards {
                    let card = PersistedFlashcard(question: cardData.question, answer: cardData.answer, type: cardData.type ?? "basic")
                    card.set = newSet
                    modelContext.insert(card)
                }
                try modelContext.save()
                syncSetToSupabase(newSet)
                
                await MainActor.run { isGenerating = false; dismiss() }
            } catch {
                await MainActor.run { isGenerating = false; errorMessage = "AI failed to build valid legal cards." }
            }
        }
    }
    
    private func saveManualSet() {
        let validCards = manualCards.filter { !$0.question.isEmpty }
        guard !validCards.isEmpty else { return }
        
        let module = modules.first(where: { $0.id == selectedModuleId })
        let newSet = PersistedFlashcardSet(topic: manualTopic, moduleId: selectedModuleId, moduleName: module?.name, learningSteps: [step1, step2], graduatingInterval: gradInt, easyInterval: easyInt)
        newSet.module = module
        modelContext.insert(newSet)
        
        for mc in validCards {
            let card = PersistedFlashcard(question: mc.question, answer: mc.answer, type: mc.type == "reverse" ? "basic" : mc.type,
                                          frontImageUrl: mc.frontImageUrl.isEmpty ? nil : mc.frontImageUrl,
                                          backImageUrl: mc.backImageUrl.isEmpty ? nil : mc.backImageUrl)
            card.set = newSet
            modelContext.insert(card)
            
            if mc.type == "reverse" {
                let rCard = PersistedFlashcard(question: mc.answer, answer: mc.question, type: "basic",
                                               frontImageUrl: mc.backImageUrl.isEmpty ? nil : mc.backImageUrl,
                                               backImageUrl: mc.frontImageUrl.isEmpty ? nil : mc.frontImageUrl)
                rCard.set = newSet
                modelContext.insert(rCard)
            }
        }
        try? modelContext.save()
        syncSetToSupabase(newSet)
        dismiss()
    }
    
    private func syncSetToSupabase(_ set: PersistedFlashcardSet) {
        let cardsJson: [[String: Any]] = set.cards.map { card in
            var json: [String: Any] = ["question": card.question, "answer": card.answer, "type": card.type ?? "basic", "interval": card.interval, "easeFactor": card.easeFactor, "repetitions": card.repetitions, "nextReviewDate": ISO8601DateFormatter().string(from: card.nextReviewDate), "isLearning": card.isLearning ?? true, "learningStep": card.learningStep ?? 0]
            if let fUrl = card.frontImageUrl { json["frontImageUrl"] = fUrl }
            if let bUrl = card.backImageUrl { json["backImageUrl"] = bUrl }
            return json
        }
        Task {
            try? await SupabaseManager.shared.upsertFlashcardSet(id: set.id, topic: set.topic, cards: cardsJson, moduleId: set.moduleId, isPublic: set.isPublic, learningSteps: set.learningSteps, graduatingInterval: set.graduatingInterval, easyInterval: set.easyInterval)
        }
    }
}

private struct SettingRow<Content: View>: View {
    let label: String
    let help: String
    let content: () -> Content
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                Text(help)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            Spacer()
            content()
        }
    }
}

private struct FlashcardResponse: Codable {
    let flashcards: [FlashcardData]
}

private struct FlashcardData: Codable {
    let question: String
    let answer: String
    let type: String?
}
