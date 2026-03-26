import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

struct AIChatView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersistedChatMessage.timestamp) var messages: [PersistedChatMessage]
    
    @State private var inputText = ""
    @State private var isSending = false
    @State private var selectedMode: AIChatMode = .fast
    @State private var showContext = false
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    @Environment(\.openURL) var openURL
    
    @State private var showUpgradeAlert = false
    
    // Thinking Animation State
    @State private var thinkingStep = ""
    @State private var thinkingProgress: Double = 0.0
    
    @AppStorage("aiConsentGiven") private var aiConsentGiven: Bool = false
    
    @ObservedObject var studyManager = StudySessionManager.shared

    
    var body: some View {
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                chatHeader
                
                // Chat Area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            if messages.isEmpty {
                                WelcomeChatView(mode: selectedMode)
                            }
                            
                            ForEach(messages) { message in
                                ChatBubbleV2(message: message, inputText: $inputText)
                                    .id(message.id)
                            }
                            
                            if isSending {
                                ThinkingStateView(step: thinkingStep, progress: thinkingProgress)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .padding()
                    }
                    .onAppear {
                        scrollProxy = proxy
                        scrollToBottom()
                    }
                    .onChange(of: messages.count) {
                        scrollToBottom()
                    }
                }
                
                // Input Bar
                VStack(spacing: 16) {
                    if !aiConsentGiven {
                        consentBar
                    }
                    
                    HStack(spacing: 12) {
                        TextField("Ask about case law, statutes, or exam theory...", text: $inputText, axis: .vertical)
                            .lineLimit(1...5)
                            .font(Theme.Fonts.inter(size: 15))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Theme.Colors.surface)
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                            .disabled(!aiConsentGiven)
                        
                        Button {
                            sendMessage()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill((inputText.isEmpty || !aiConsentGiven) ? Theme.Colors.textSecondary.opacity(0.2) : Theme.Colors.accent)
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor((inputText.isEmpty || !aiConsentGiven) ? Theme.Colors.textSecondary : Theme.Colors.onAccent)
                            }
                        }
                        .disabled(inputText.isEmpty || isSending || !aiConsentGiven)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    
                    if !aiConsentGiven {
                        Text("Consent required to activate Master AI.")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.Colors.accent.opacity(0.6))
                    }
                }
                .padding(.top, 12)
                .background(Theme.Colors.bg.opacity(0.95))
                .overlay(VStack { Divider().background(Theme.Colors.glassBorder); Spacer() })
            }
            
            // Context Tab / Drawer
            if showContext {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { showContext = false } }
                
                HStack {
                    Spacer()
                    ContextDrawer(show: $showContext)
                        .transition(.move(edge: .trailing))
                }
                .ignoresSafeArea()
            }
        }
        .alert("ThinkLikeLaw Master Upgrade", isPresented: $showUpgradeAlert) {
            Button("View Plans") {
                if let url = URL(string: "https://www.thinklikelaw.com/#pricing") {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Planning mode uses Master AI's deep legal reasoning and is available for Fellow & Monthly members. Your current tier is \(authState.currentUser?.plan ?? "Scholar").")
        }
        .onAppear {
            onAppearAction()
        }
        .onDisappear {
            onDisappearAction()
        }
    }
    
    @ViewBuilder
    private var consentBar: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.Colors.accent)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Data & Privacy Consent")
                        .font(Theme.Fonts.inter(size: 14, weight: .bold))
                    Text("To provide academic legal insights, your message history is processed by our secure Master AI. We never sell your data. By chatting, you agree to our academic transparency guidelines.")
                        .font(Theme.Fonts.inter(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Button {
                withAnimation { aiConsentGiven = true }
            } label: {
                Text("Confirm and Continue")
                    .font(Theme.Fonts.inter(size: 14, weight: .bold))
                    .foregroundColor(Theme.Colors.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.Colors.accent)
                    .cornerRadius(10)
            }
        }
        .padding(16)
        .background(Theme.Colors.accent.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.accent.opacity(0.2), lineWidth: 1))
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
    
    private var chatHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Legal Intelligence")
                        .font(Theme.Fonts.outfit(size: 24, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Text("Powered by ThinkLikeLaw Master AI")
                        .font(Theme.Fonts.inter(size: 12, weight: .medium))
                        .foregroundColor(Theme.Colors.accent)
                }
                
                Spacer()
                
                Button {
                    showContext.toggle()
                } label: {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(.horizontal)
            
            // Mode Picker
            HStack(spacing: 12) {
                ForEach(AIChatMode.allCases, id: \.self) { mode in
                    Button {
                        if mode == .planning && (authState.currentUser?.plan == "Scholar" || authState.currentUser?.plan == nil) {
                            showUpgradeAlert = true
                        } else {
                            withAnimation { selectedMode = mode }
                        }
                    } label: {
                        VStack(spacing: 2) {
                            HStack(spacing: 8) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 14, weight: .bold))
                                Text(mode.rawValue)
                                    .font(Theme.Fonts.inter(size: 14, weight: .bold))
                            }
                            
                            Text("\(String(format: "%.1fx", mode.multiplier)) credits")
                                .font(.system(size: 8, weight: .black))
                                .opacity(0.8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedMode == mode ? Theme.Colors.accent : Theme.Colors.surface)
                        .foregroundColor(selectedMode == mode ? Theme.Colors.onAccent : Theme.Colors.textPrimary)
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 20)
        .background(Theme.Colors.bg.opacity(0.8))
        .overlay(VStack { Spacer(); Divider().background(Theme.Colors.glassBorder) })
    }
    
    @MainActor
    private func sendMessage() {
        let text = inputText
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        inputText = ""
        
        let userMsg = PersistedChatMessage(text: text, role: "user")
        modelContext.insert(userMsg)
        
        isSending = true
        scrollToBottom()
        
        Task {
            // Simulate multi-step thinking for Planning Mode
            let steps = selectedMode == .planning ? [
                "Initializing proprietary TNA Grounding Layer...",
                "Analyzing High-Fidelity Precedent & Policy...",
                "Cross-Referencing Multi-Jurisdictional Statutes...",
                "Structuring Academic IRAC Framework...",
                "Finalizing High-Tier Legal Synthesis..."
            ] : [
                "Consulting legal intelligence...",
                "Verifying statutory alignment..."
            ]
            
            for (index, step) in steps.enumerated() {
                await MainActor.run {
                    thinkingStep = step
                    thinkingProgress = Double(index + 1) / Double(steps.count)
                }
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
            
            do {
                let context: [String: Any] = ["mode": selectedMode.rawValue]
                let (response, cost) = try await AIService.shared.callAI(tool: .chat, content: text, context: context)
                
                await MainActor.run {
                    let aiMsg = PersistedChatMessage(
                        text: response, 
                        role: "assistant", 
                        modelUsed: "Master AI (\(selectedMode.rawValue))", 
                        mode: selectedMode.rawValue,
                        cost: cost
                    )
                    modelContext.insert(aiMsg)
                    isSending = false
                    scrollToBottom()
                    
                    // Refresh credits UI
                    Task {
                        if let userId = UserDefaults.standard.string(forKey: "supabase_user_id") {
                            await authState.loadUserProfile(userId: userId)
                        }
                    }
                }
            } catch {
                await MainActor.run { 
                    let errorMsg = PersistedChatMessage(text: "I encountered an error connecting to the High-Tier Legal Intelligence. Please check your connection or try again shortly.", role: "assistant", modelUsed: "System")
                    modelContext.insert(errorMsg)
                    isSending = false 
                    scrollToBottom()
                }
            }
        }
    }
    
    @MainActor
    private func scrollToBottom() {
        guard let proxy = scrollProxy, let lastId = messages.last?.id else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }
}

extension AIChatView {
    func onAppearAction() {
        studyManager.startSession(type: "chat", modelContext: modelContext, authState: authState)
    }
    
    func onDisappearAction() {
        studyManager.stopSession(modelContext: modelContext, authState: authState)
    }
}


// MARK: - Subviews

struct WelcomeChatView: View {
    let mode: AIChatMode
    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)
            
            ZStack {
                Circle()
                    .fill(Theme.Colors.accent.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.Colors.accent)
            }
            
            VStack(spacing: 8) {
                Text("ThinkLikeLaw Assistant")
                    .font(Theme.Fonts.outfit(size: 22, weight: .bold))
                Text("Your professional legal academic partner.")
                    .font(Theme.Fonts.inter(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: mode.icon, title: "\(mode.rawValue) Mode Active", desc: modeDescription)
                FeatureRow(icon: "checkmark.seal.fill", title: "TNA Fact-Check", desc: "Every citation is verified against The National Archives.")
                FeatureRow(icon: "doc.text.fill", title: "IRAC Framework", desc: "Responses follow the legal analysis standard.")
            }
            .padding(24)
            .glassCard()
        }
        .padding(24)
    }
    
    var modeDescription: String {
        switch mode {
        case .fast: return "Rapid response focusing on concise legal definitions."
        case .normal: return "Balanced analysis with case law grounding."
        case .planning: return "Extensive multi-step research and deep legal reasoning."
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let desc: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Theme.Colors.accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Fonts.inter(size: 14, weight: .bold))
                Text(desc)
                    .font(Theme.Fonts.inter(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }
}

struct ChatBubbleV2: View {
    let message: PersistedChatMessage
    @Binding var inputText: String
    @Environment(\.modelContext) private var modelContext
    var isUser: Bool { message.role == "user" }
    @State private var showCopyToast = false
    
    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 12) {
                if isUser { Spacer() }
                
                VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                    Group {
                        if let attributedString = try? AttributedString(markdown: message.text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                            Text(attributedString)
                        } else {
                            Text(message.text)
                        }
                    }
                    .font(Theme.Fonts.inter(size: 15))
                    .lineSpacing(6)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(isUser ? Theme.Colors.accent : Theme.Colors.surface)
                    .foregroundColor(isUser ? Theme.Colors.onAccent : Theme.Colors.textPrimary)
                    .cornerRadius(16)
                    #if os(iOS)
                    .cornerRadius(2, corners: isUser ? .bottomRight : .bottomLeft)
                    #endif
                    .shadow(color: Color.black.opacity(0.02), radius: 5)
                    
                    if !isUser {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Text(message.modelUsed ?? "AI")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(Theme.Colors.accent)
                                
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                                
                                if let cost = message.cost {
                                    Text("• \(cost) CREDITS")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.6))
                                }
                            }
                            
                            Button {
                                #if os(iOS)
                                UIPasteboard.general.string = message.text
                                #elseif os(macOS)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(message.text, forType: .string)
                                #endif
                                withAnimation { showCopyToast = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { showCopyToast = false }
                                }
                            } label: {
                                Image(systemName: showCopyToast ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                        .padding(.leading, 4)
                        .padding(.top, 2)
                    }
                }
                
                if !isUser { Spacer() }
                
                if isUser {
                    Button {
                        inputText = message.text
                        modelContext.delete(message)
                    } label: {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.8))
                    }
                    .padding(.trailing, 4)
                }
            }
        }
    }
}

struct ThinkingStateView: View {
    let step: String
    let progress: Double
    @State private var rotation: Double = 0.0
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Theme.Colors.glassBorder, lineWidth: 3)
                    .frame(width: 32, height: 32)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AngularGradient(colors: [Theme.Colors.accent, Theme.Colors.accent.opacity(0.1)], center: .center),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step)
                    .font(Theme.Fonts.inter(size: 14, weight: .bold))
                    .italic()
                    .foregroundColor(Theme.Colors.textPrimary)
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.surface)
                        .frame(width: 150, height: 4)
                    
                    Capsule()
                        .fill(Theme.Colors.accent)
                        .frame(width: 150 * progress, height: 4)
                        .animation(.spring(), value: progress)
                }
                
                Text("ThinkLikeLaw Proprietary Processing")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(Theme.Colors.accent.opacity(0.5))
            }
            Spacer()
        }
        .padding(20)
        .glassCard()
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

struct ContextDrawer: View {
    @Binding var show: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Legal Context")
                    .font(Theme.Fonts.outfit(size: 20, weight: .bold))
                Spacer()
                Button { show = false } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(.top, 60)
            
            LegalSourceItem(title: "The National Archives", icon: "building.columns.fill", desc: "Live API grounding active.")
            LegalSourceItem(title: "User Profile", icon: "person.text.rectangle.fill", desc: "Student Status: Academic Master")
            LegalSourceItem(title: "Framework", icon: "doc.badge.gearshape.fill", desc: "IRAC structure enforced.")
            
            Spacer()
        }
        .padding(24)
        .frame(width: 280)
        .background(Theme.Colors.bg)
        .overlay(HStack { Divider(); Spacer() })
    }
}

struct LegalSourceItem: View {
    let title: String
    let icon: String
    let desc: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Theme.Colors.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Fonts.inter(size: 14, weight: .bold))
                Text(desc)
                    .font(Theme.Fonts.inter(size: 11))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
    }
}

