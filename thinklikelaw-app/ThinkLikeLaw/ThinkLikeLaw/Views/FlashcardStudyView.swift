import SwiftUI
import SwiftData
import AVFoundation

struct FlashcardStudyView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    let set: PersistedFlashcardSet
    var isCramMode: Bool = false
    
    @State private var cardsToReview: [PersistedFlashcard] = []
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var isSessionComplete = false
    @State private var cardOffset: CGFloat = 0
    @State private var bounceValue: Bool = false
    
    // Session stats
    @State private var correctCount = 0
    @State private var incorrectCount = 0
    @State private var sessionStartTime = Date()
    @State private var selectedConfidence: SRSService.ConfidenceLevel = .solid
    @State private var userTypedAnswer = ""
    @State private var aiFeedback: String?
    @State private var isVerifyingAnswer = false
    @State private var srsFlashColor: Color? = nil
    @State private var cardFailures: [String: Int] = [:]
    @State private var verifiedCards: Set<String> = []
    @AppStorage("useAIGrading") var useAIGrading: Bool = true
    @AppStorage("useButtonMode") var useButtonMode: Bool = false
    private let synthesizer = AVSpeechSynthesizer()
    
    var progress: Double {
        guard !cardsToReview.isEmpty else { return 0 }
        return Double(currentIndex) / Double(cardsToReview.count)
    }
    
    @EnvironmentObject var authState: AuthState
    @ObservedObject var studyManager = StudySessionManager.shared
    
    var body: some View {
        ZStack {
            // Premium Dynamic Background
            Theme.Colors.bg.ignoresSafeArea()
            
            // Fading Laser Pen Overlay for Background Drawing
            LaserPenOverlay()
            
            // Subtle Mesh-like Overlays
            Circle()
                .fill(Theme.Colors.accent.opacity(0.12))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: -200, y: -300)
            
            Circle()
                .fill(Theme.Colors.accent.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: 200, y: 300)
            
            VStack(spacing: 0) {
                // Top Bar
                studyHeader
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                
                // Progress Bar
                progressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                
                ZStack {
                    if let flashColor = srsFlashColor {
                        flashColor.opacity(0.15)
                            .ignoresSafeArea()
                            .transition(.opacity)
                    }
                    
                    VStack(spacing: 0) {
                        if isSessionComplete {
                            sessionCompleteView
                        } else if cardsToReview.isEmpty {
                            emptyDueView
                        } else {
                            // Card Area
                            Spacer()
                            
                            cardView
                                .padding(.horizontal, 24)
                                .padding(.vertical, 20)
                                .overlay {
                                    if let flashColor = srsFlashColor {
                                        RoundedRectangle(cornerRadius: 32)
                                            .stroke(flashColor, lineWidth: 4)
                                            .blur(radius: 10)
                                    }
                                }
                            
                            Spacer()
                            
                            // Bottom Controls
                            controlsArea
                                .padding(.bottom, 24)
                        }
                    }
                }
            }
            
            // Mascot Pop-in
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    if MascotManager.shared.isVisible {
                        MascotView()
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .padding(.trailing, 10)
            .padding(.bottom, 140) // Adjusted for full view
            .ignoresSafeArea(.keyboard)
        }
        .onAppear {
            print("DEBUG: FlashcardStudyView appeared for deck: \(set.topic)")
            print("DEBUG: Card count in set: \(set.cards.count)")
            print("STUDY: Starting session with steps: \(set.learningSteps), gradInt: \(set.graduatingInterval), easyInt: \(set.easyInterval)")
            sessionStartTime = Date()
            if isCramMode {
                cardsToReview = set.cards.shuffled()
            } else {
                let cutoff = Date().addingTimeInterval(60)
                cardsToReview = set.cards.filter { $0.nextReviewDate <= cutoff }
                    .sorted { $0.nextReviewDate < $1.nextReviewDate }
            }
            print("DEBUG: Cards to review after filter: \(cardsToReview.count)")
            studyManager.startSession(type: "flashcards", modelContext: modelContext, authState: authState)
        }
        .onDisappear {
            studyManager.stopSession(modelContext: modelContext, authState: authState)
            if !isCramMode { syncToSupabase() }
        }
        .background {
            // Keyboard Shortcuts for Mac
            Button("") { if !isFlipped { withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { isFlipped = true } } }
                .keyboardShortcut(.space, modifiers: [])
            
            if isFlipped {
                Button("") { submitReview(grade: .again) }.keyboardShortcut("1", modifiers: [])
                Button("") { submitReview(grade: .hard) }.keyboardShortcut("2", modifiers: [])
                Button("") { submitReview(grade: .good) }.keyboardShortcut("3", modifiers: [])
                Button("") { submitReview(grade: .easy) }.keyboardShortcut("4", modifiers: [])
            }
        }
    }
    
    // MARK: - Header
    
    private var studyHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(8)
                    .background(Theme.Colors.surface)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(set.topic)
                    .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if isCramMode {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                    }
                    Text(isCramMode ? "CRAM MODE" : "SPACED REPETITION")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(isCramMode ? .orange : Theme.Colors.accent)
                        .tracking(1.5)
                }
            }
            
            Spacer()
            
            // Card Counter
            HStack(spacing: 2) {
                Text("\(min(currentIndex + 1, cardsToReview.count))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("/\(cardsToReview.count)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.glassBorder, lineWidth: 1))
            
            // Study Settings
            Menu {
                Toggle(isOn: $useButtonMode) {
                    Label("Button Mode", systemImage: "hand.point.up.fill")
                }
                
                if !isCramMode {
                    Button(action: { /* Show SRS Stats */ }) {
                        Label("Deck Statistics", systemImage: "chart.bar.fill")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(8)
                    .background(Theme.Colors.surface)
                    .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.Colors.textSecondary.opacity(0.06))
                    .frame(height: 5)
                
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Theme.Colors.accent, Theme.Colors.accent.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * progress), height: 5)
                    .animation(.spring(response: 0.4), value: progress)
            }
        }
        .frame(height: 5)
    }
    
    // MARK: - Card View
    
    private var cardView: some View {
        ZStack {
            // Swipe Feedback Overlays
            if isFlipped {
                // Green Overlay (Right)
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.green.opacity(Double(max(0, cardOffset / 150) * 0.3)))
                    .overlay(
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                            .opacity(Double(max(0, cardOffset / 100)))
                    )
                    .zIndex(10)
                    .allowsHitTesting(false)
                
                // Red Overlay (Left)
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.red.opacity(Double(max(0, -cardOffset / 150) * 0.3)))
                    .overlay(
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                            .opacity(Double(max(0, -cardOffset / 100)))
                    )
                    .zIndex(10)
                    .allowsHitTesting(false)
            }
            
            // Front
            cardFace(isFront: true)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 0 : 1)
            
            // Back
            cardFace(isFront: false)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .frame(maxWidth: 600)
        .frame(minHeight: 350, maxHeight: 450)
        .offset(x: cardOffset)
        .rotationEffect(.degrees(Double(cardOffset / 25)))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    if isFlipped {
                        cardOffset = gesture.translation.width
                    }
                }
                .onEnded { gesture in
                    if isFlipped {
                        if gesture.translation.width > 100 {
                            submitReview(grade: .good)
                        } else if gesture.translation.width < -100 {
                            submitReview(grade: .again)
                        }
                        withAnimation(.spring(response: 0.3)) {
                            cardOffset = 0
                        }
                    }
                }
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                isFlipped.toggle()
            }
        }
        .shadow(color: Color.black.opacity(0.08), radius: 30, x: 0, y: 15)
        .padding(.vertical, 10) // Extra space for shadow
    }
    
    @ViewBuilder
    private func cardFace(isFront: Bool) -> some View {
        let card = cardsToReview.indices.contains(currentIndex) ? cardsToReview[currentIndex] : nil

        ZStack {
            #if os(iOS)
            RoundedRectangle(cornerRadius: 32)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(LinearGradient(colors: [.white.opacity(0.5), .clear, .white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                )
            #else
            RoundedRectangle(cornerRadius: 32)
                .fill(Theme.Colors.surface.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Theme.Colors.glassBorder, lineWidth: 1.5)
                )
            #endif
            
            // Subtle internal glow
            RoundedRectangle(cornerRadius: 32)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.Colors.accent.opacity(isFront ? 0.03 : 0.08),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            if let card = card {
                VStack(spacing: 16) {
                    // Card Type Label
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: isFront ? "questionmark.circle.fill" : "lightbulb.fill")
                                .font(.system(size: 12))
                            Text(isFront ? "QUESTION" : "ANSWER")
                                .font(.system(size: 9, weight: .black))
                                .tracking(2)
                        }
                        .foregroundColor(Theme.Colors.accent.opacity(0.7))
                        
                        Spacer()
                        
                        // Confidence Selection (Pre-flip)
                        if isFront && !isFlipped {
                            HStack(spacing: 12) {
                                confidencePill(level: .uncertain, icon: "questionmark.circle", label: "Uncertain")
                                confidencePill(level: .solid, icon: "checkmark.circle", label: "Solid")
                                confidencePill(level: .certain, icon: "bolt.circle", label: "Certain")
                            }
                            .padding(.bottom, 8)
                        }
                        
                        if card.repetitions > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("\(card.repetitions)")
                            }
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Theme.Colors.textSecondary.opacity(0.05))
                            .clipShape(Capsule())
                        }
                        
                        if !isFront {
                            HStack(spacing: 8) {
                                if card.repetitions > 0 {
                                    HStack(spacing: 3) {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text("\(card.repetitions)")
                                    }
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.Colors.textSecondary.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                
                                if verifiedCards.contains(card.uuid) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(Color.green.opacity(0.8))
                                        .font(.system(size: 16))
                                }
                            }
                        }
                    }
                    
                    Divider().background(Theme.Colors.glassBorder)
                    
                    Spacer()
                    
                    // Image (if any)
                    renderImage(card: card, isFront: isFront)
                    
                    // AI grading input removed by user request
                    
                    // Text Content
                    renderText(card: card, isFront: isFront)
                    
                    if let feedback = aiFeedback, !isFront { // Show verification failure directly on back of card
                        Text(feedback)
                            .font(Theme.Fonts.inter(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    if isFront && !isFlipped && useButtonMode {
                        Button {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                                isFlipped = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "eye.fill")
                                Text("REVEAL ANSWER")
                            }
                            .font(Theme.Fonts.outfit(size: 14, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Theme.Colors.accent)
                            .cornerRadius(16)
                            .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 10, y: 5)
                        }
                        .padding(.top, 10)
                    }
                    
                    if isFront && !useButtonMode {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 12))
                            Text("Tap to reveal")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.4))
                    }
                }
                .padding(28)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    isFlipped && !isFront
                        ? Theme.Colors.accent.opacity(0.2)
                        : Theme.Colors.glassBorder,
                    lineWidth: 1.5
                )
        )
        .overlay(alignment: .bottomTrailing) {
            if let card = card {
                HStack(spacing: 12) {
                    // TNA Fact Checking Verify Button
                    if !isFront && !verifiedCards.contains(card.uuid) {
                        Button {
                            verifyFlashcardFact(card: card)
                        } label: {
                            HStack(spacing: 6) {
                                if isVerifyingAnswer {
                                    ProgressView().tint(Theme.Colors.accent).scaleEffect(0.7)
                                } else {
                                    Image(systemName: "checkmark.seal")
                                }
                                Text(isVerifyingAnswer ? "Verifying..." : "Verify (5cr)")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(Theme.Colors.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Theme.Colors.surface.opacity(0.8))
                            .clipShape(Capsule())
                            .glassCard()
                        }
                        .disabled(isVerifyingAnswer)
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Voice Mastery (TTS)
                    Button {
                        speak(text: isFront ? card.question : card.answer)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.accent)
                            .padding(12)
                            .background(Theme.Colors.surface.opacity(0.8))
                            .clipShape(Circle())
                            .glassCard()
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .animation(.spring(response: 0.4), value: isVerifyingAnswer)
            }
        }
    }
    
    private func confidencePill(level: SRSService.ConfidenceLevel, icon: String, label: String) -> some View {
        Button {
            selectedConfidence = level
            MascotManager.shared.handleConfidence(level)
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
            VStack(spacing: 4) {
                Image(systemName: selectedConfidence == level ? "\(icon).fill" : icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(selectedConfidence == level ? Theme.Colors.accent : Theme.Colors.textSecondary)
            .frame(width: 60)
            .padding(.vertical, 6)
            .background(selectedConfidence == level ? Theme.Colors.accent.opacity(0.1) : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func speak(text: String) {
        let utterance = VoiceService.shared.createUtterance(text: text)
        synthesizer.speak(utterance)
    }
    
    private func verifyFlashcardFact(card: PersistedFlashcard) {
        isVerifyingAnswer = true
        aiFeedback = nil
        
        Task {
            do {
                let context = [
                    "question": card.question
                ]
                let (response, _) = try await AIService.shared.callAI(tool: .verify_answer, content: card.answer, context: context)
                await MainActor.run {
                    isVerifyingAnswer = false
                    if response.contains("VERIFIED: Correct") || response.uppercased().contains("VERIFIED: CORRECT") {
                        verifiedCards.insert(card.uuid)
                        #if os(iOS)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        #endif
                    } else {
                        aiFeedback = response // Show hallucination or inaccuracy
                        #if os(iOS)
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                        #endif
                    }
                }
            } catch {
                await MainActor.run {
                    isVerifyingAnswer = false
                    aiFeedback = "Unable to contact Chambers for verification."
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderImage(card: PersistedFlashcard, isFront: Bool) -> some View {
        let urlString = isFront ? card.frontImageUrl : card.backImageUrl
        if let urlStr = urlString, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView().frame(height: 100)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 140)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                case .failure:
                    EmptyView()
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderText(card: PersistedFlashcard, isFront: Bool) -> some View {
        let type = card.type ?? "basic"
        let text = isFront ? card.question : (type == "cloze" ? card.question : card.answer)
        
        if type == "cloze" {
            let processed = processCloze(text: text, hide: isFront)
            Text(processed)
                .font(Theme.Fonts.inter(size: 20, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .minimumScaleFactor(0.5)
        } else if let markdown = try? AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(markdown)
                .font(Theme.Fonts.inter(size: 20, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .minimumScaleFactor(0.5)
        } else {
            Text(text)
                .font(Theme.Fonts.inter(size: 20, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .minimumScaleFactor(0.5)
        }
    }
    
    private func processCloze(text: String, hide: Bool) -> AttributedString {
        let pattern = "\\{\\{c1::(.*?)\\}\\}"
        if hide {
            let replaced = text.replacingOccurrences(of: pattern, with: " [...] ", options: .regularExpression)
            return (try? AttributedString(markdown: replaced)) ?? AttributedString(replaced)
        } else {
            let cleaned = text.replacingOccurrences(of: "{{c1::", with: "**").replacingOccurrences(of: "}}", with: "**")
            return (try? AttributedString(markdown: cleaned)) ?? AttributedString(cleaned)
        }
    }
    
    // MARK: - Controls Area
    
    private var controlsArea: some View {
        VStack(spacing: 12) {
            if isFlipped {
                srsButtons
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Tap hint with animation
                VStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.Colors.accent.opacity(0.5))
                        .offset(y: bounceValue ? -6 : 0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                                bounceValue = true
                            }
                        }
                    
                    Text("TAP CARD OR PRESS SPACE")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.4))
                        .tracking(2)
                }
                .padding(.bottom, 30)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFlipped)
    }
    
    // MARK: - SRS Buttons
    
    private var srsButtons: some View {
        VStack(spacing: 12) {
            Text("HOW WELL DID YOU KNOW THIS?")
                .font(.system(size: 9, weight: .black))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(1.5)
            
            HStack(spacing: 8) {
                gradeButton(
                    title: "Again",
                    subtitle: intervalPreview(grade: .again),
                    color: .red,
                    shortcut: "1",
                    grade: .again
                )
                gradeButton(
                    title: "Hard",
                    subtitle: intervalPreview(grade: .hard),
                    color: .orange,
                    shortcut: "2",
                    grade: .hard
                )
                gradeButton(
                    title: "Good",
                    subtitle: intervalPreview(grade: .good),
                    color: .blue,
                    shortcut: "3",
                    grade: .good
                )
                gradeButton(
                    title: "Easy",
                    subtitle: intervalPreview(grade: .easy),
                    color: .green,
                    shortcut: "4",
                    grade: .easy
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Theme.Colors.surface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.glassBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
        .padding(.horizontal, 16)
    }
    
    private func gradeButton(title: String, subtitle: String, color: Color, shortcut: String, grade: SRSService.SRSGrade) -> some View {
        Button(action: { submitReview(grade: grade) }) {
            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .opacity(0.7)
                
                // Keyboard shortcut hint
                Text(shortcut)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(color.opacity(0.4))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.06))
                    .cornerRadius(4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.08))
            .foregroundColor(color)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    /// Compute what interval the SRS engine would give for each grade
    private func intervalPreview(grade: SRSService.SRSGrade) -> String {
        guard cardsToReview.indices.contains(currentIndex) else { return "" }
        let card = cardsToReview[currentIndex]
        
        let result = SRSService.shared.processReview(
            interval: card.interval,
            easeFactor: card.easeFactor,
            repetitions: card.repetitions,
            grade: grade,
            confidence: selectedConfidence,
            isLearning: card.isLearning ?? true,
            learningStep: card.learningStep ?? 0,
            learningSteps: set.learningSteps,
            graduatingInterval: set.graduatingInterval,
            easyInterval: set.easyInterval
        )
        
        if isCramMode { return "—" }
        
        let seconds = result.nextReviewDate.timeIntervalSince(Date())
        if seconds < 3600 { // < 1 hour
            return "\(max(1, Int(seconds / 60)))m"
        } else if seconds < 86400 { // < 1 day
            return "\(Int(seconds / 3600))h"
        } else {
            return "\(max(1, Int(seconds / 86400)))d"
        }
    }
    
    // MARK: - Empty Due View
    
    private var emptyDueView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.08))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green.opacity(0.6))
            }
            
            VStack(spacing: 8) {
                Text("All caught up!")
                    .font(Theme.Fonts.outfit(size: 24, weight: .bold))
                Text("No cards are due for review.\nUse **Cram Mode** to study all cards.")
                    .font(Theme.Fonts.inter(size: 15))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { dismiss() }) {
                Text("Back to Decks")
                    .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                    .foregroundColor(Theme.Colors.onAccent)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.accent)
                    .cornerRadius(12)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Session Complete
    
    private var sessionCompleteView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Mastery Trophy
            ZStack {
                Circle()
                    .fill(Theme.Colors.accent.opacity(0.1))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.Colors.accent, Theme.Colors.accent.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            
            VStack(spacing: 12) {
                Text(isCramMode ? "Cramming Mastery" : "Study Session Mastery")
                    .font(Theme.Fonts.outfit(size: 32, weight: .bold))
                
                Text("Your judicial knowledge has been refined and synchronized with the chambers.")
                    .font(Theme.Fonts.inter(size: 16))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Stats Grid - Glassmorphic
            let duration = Int(Date().timeIntervalSince(sessionStartTime))
            VStack(spacing: 20) {
                HStack(spacing: 16) {
                    sessionStat(value: "\(cardsToReview.count)", label: "REVIEWED", icon: "rectangle.stack.fill", color: .blue)
                    sessionStat(value: "\(correctCount)", label: "MASTERY", icon: "checkmark.seal.fill", color: .green)
                    sessionStat(value: "\(incorrectCount)", label: "LAPSE", icon: "arrow.counterclockwise", color: .red)
                    sessionStat(value: formatDuration(duration), label: "DURATION", icon: "clock.fill", color: .purple)
                }
            }
            .padding(24)
            #if os(iOS)
            .background(.ultraThinMaterial)
            #else
            .background(Theme.Colors.surface.opacity(0.8))
            #endif
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.Colors.glassBorder, lineWidth: 1.5))
            .padding(.horizontal, 24)
            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            
            Button(action: { dismiss() }) {
                HStack(spacing: 12) {
                    Text("Return to Chambers")
                    Image(systemName: "arrow.right")
                }
                .font(Theme.Fonts.outfit(size: 18, weight: .bold))
                .foregroundColor(Theme.Colors.onAccent)
                .padding(.horizontal, 40)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(Theme.Colors.accent)
                        .shadow(color: Theme.Colors.accent.opacity(0.4), radius: 15, y: 8)
                )
            }
            .padding(.top, 10)
            
            Spacer()
        }
    }
    
    private func sessionStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return "\(m):\(String(format: "%02d", s))"
    }
    
    // MARK: - Review Logic
    
    private func submitReview(grade: SRSService.SRSGrade) {
        if isCramMode {
            if grade == .good || grade == .easy { correctCount += 1 }
            else { incorrectCount += 1 }
            
            // Award XP for cramming
            XPService.shared.addXP(.flashcardReview(correct: grade == .good || grade == .easy))
            
            // Track completion count even in Cram Mode
            let card = cardsToReview[currentIndex]
            card.repetitions += 1
            card.lastReviewedAt = Date()
            try? modelContext.save()
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                if currentIndex < cardsToReview.count - 1 {
                    isFlipped = false
                    selectedConfidence = .solid 
                    userTypedAnswer = "" // Reset
                    aiFeedback = nil // Reset
                    currentIndex += 1
                } else {
                    isSessionComplete = true
                }
            }
            return
        }
        
        let card = cardsToReview[currentIndex]
        let result = SRSService.shared.processReview(
            interval: card.interval,
            easeFactor: card.easeFactor,
            repetitions: card.repetitions,
            grade: grade,
            confidence: selectedConfidence,
            isLearning: card.isLearning ?? true,
            learningStep: card.learningStep ?? 0,
            learningSteps: set.learningSteps,
            graduatingInterval: set.graduatingInterval,
            easyInterval: set.easyInterval
        )
        
        // Visual & Haptic Feedback
        withAnimation(.easeIn(duration: 0.1)) {
            srsFlashColor = grade == .again ? .red : (grade == .hard ? .orange : (grade == .good ? .blue : .green))
        }
        
        #if os(iOS)
        switch grade {
        case .again: UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .hard: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .good: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .easy: UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation { srsFlashColor = nil }
        }
        
        // Track stats
        if grade == .good || grade == .easy { correctCount += 1 }
        else { incorrectCount += 1 }
        
        // Update persisted model
        card.interval = result.interval
        card.easeFactor = result.easeFactor
        card.repetitions = result.repetitions
        card.nextReviewDate = result.nextReviewDate
        card.lastReviewedAt = Date()
        card.isLearning = result.isLearning
        card.learningStep = result.learningStep
        
        // Award XP for spaced repetition review
        XPService.shared.addXP(.flashcardReview(correct: grade != .again))
        
        // Track Failures for Contextual Ben
        if grade == .again {
            let cardId = card.uuid
            let currentFails = (cardFailures[cardId] ?? 0) + 1
            cardFailures[cardId] = currentFails
            
            if currentFails == 3 {
                MascotManager.shared.triggerContextualHelp(topic: set.topic, reason: "repeated lapses")
            }
        }
        
        try? modelContext.save()
        
        // Mascot Reaction
        MascotManager.shared.handleGrade(grade)
        MascotManager.shared.handleSessionMilestone(index: currentIndex, total: cardsToReview.count)
        
        // Next card
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if currentIndex < cardsToReview.count - 1 {
                isFlipped = false
                selectedConfidence = .solid // Reset for next card
                currentIndex += 1
            } else {
                isSessionComplete = true
                syncToSupabase()
            }
        }
    }
    
    // MARK: - Sync
    
    private func syncToSupabase() {
        let deckId = set.id
        let topic = set.topic
        let moduleId = set.moduleId
        let isPublic = set.isPublic
        
        let cardsJson: [[String: Any]] = set.cards.map { card in
            var dict: [String: Any] = [
                "question": card.question,
                "answer": card.answer,
                "type": card.type ?? "basic",
                "interval": card.interval,
                "easeFactor": card.easeFactor,
                "repetitions": card.repetitions,
                "nextReviewDate": ISO8601DateFormatter().string(from: card.nextReviewDate),
                "isLearning": card.isLearning ?? true,
                "learningStep": card.learningStep ?? 0
            ]
            if let last = card.lastReviewedAt {
                dict["lastReviewedAt"] = ISO8601DateFormatter().string(from: last)
            }
            if let fUrl = card.frontImageUrl { dict["frontImageUrl"] = fUrl }
            if let bUrl = card.backImageUrl { dict["backImageUrl"] = bUrl }
            if let occ = card.occlusionRectsJson { dict["occlusionRectsJson"] = occ }
            return dict
        }
        
        Task {
            do {
                try await SupabaseManager.shared.upsertFlashcardSet(
                    id: deckId,
                    topic: topic,
                    cards: cardsJson,
                    moduleId: moduleId,
                    isPublic: isPublic,
                    learningSteps: set.learningSteps,
                    graduatingInterval: set.graduatingInterval,
                    easyInterval: set.easyInterval
                )
                print("Supabase: Flashcard set synchronized successfully.")
            } catch {
                print("Supabase: Sync failed -> \(error)")
            }
        }
    }
}

// MARK: - Laser Pen Overlay

struct LaserStroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var isDrawing: Bool = true
    var endTime: Date? = nil
}

struct LaserPenOverlay: View {
    @State private var strokes: [LaserStroke] = []
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date
                let duration: TimeInterval = 0.8 // Duration of fade-out after finger lifted
                
                for stroke in strokes {
                    guard stroke.points.count > 1 else { continue }
                    
                    var opacity: Double = 1.0
                    if !stroke.isDrawing, let endTime = stroke.endTime {
                        let timeSinceRelease = now.timeIntervalSince(endTime)
                        if timeSinceRelease >= duration { continue }
                        opacity = max(0, 1.0 - (timeSinceRelease / duration))
                    }
                    
                    var path = Path()
                    path.move(to: stroke.points[0])
                    for i in 1..<stroke.points.count {
                        path.addLine(to: stroke.points[i])
                    }
                    
                    // Stroking a single continuous path inherently prevents overlapping dots
                    context.stroke(
                        path,
                        with: .color(.white.opacity(opacity)),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if strokes.isEmpty || !strokes[strokes.count - 1].isDrawing {
                        strokes.append(LaserStroke(points: [value.location]))
                    } else {
                        strokes[strokes.count - 1].points.append(value.location)
                    }
                }
                .onEnded { _ in
                    if !strokes.isEmpty {
                        strokes[strokes.count - 1].isDrawing = false
                        strokes[strokes.count - 1].endTime = Date()
                    }
                }
        )
        .onAppear {
            _ = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await MainActor.run {
                        let now = Date()
                        strokes.removeAll { stroke in
                            if stroke.isDrawing { return false }
                            guard let endTime = stroke.endTime else { return true }
                            return now.timeIntervalSince(endTime) > 1.5
                        }
                    }
                }
            }
        }
    }
}
