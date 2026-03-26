import SwiftUI

/**
 * ThinkingModeView — A premium, interactive "thinking" overlay for AI actions.
 * Mirrored from the ThinkLikeLaw Website's ThinkingManager.
 */
struct ThinkingModeView: View {
    let type: AIService.AITool
    @Binding var isFinished: Bool
    
    @State private var currentStepIndex = 0
    @State private var steps: [String] = []
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 24) {
            header
            stepsList
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(PlatformColor.windowBackgroundColor).opacity(0.9))
                .glassCard()
        )
        .padding(40)
        .onAppear {
            setupSteps()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.Colors.accent)
                    .frame(width: 8, height: 8)
                    .pulse()
                
                Text("DEEP RESEARCH MODE")
                    .font(Theme.Fonts.outfit(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundColor(Theme.Colors.accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.Colors.accent.opacity(0.1))
            .cornerRadius(20)
            
            Spacer()
            
            Text("🧠")
                .font(.system(size: 24))
                .pulse()
        }
    }
    
    private var stepsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(0..<steps.count, id: \.self) { index in
                HStack(spacing: 12) {
                    stepIcon(for: index)
                    
                    Text(steps[index])
                        .font(Theme.Fonts.inter(size: 14, weight: index == currentStepIndex ? .bold : .medium))
                        .foregroundColor(index <= currentStepIndex ? Theme.Colors.textPrimary : Theme.Colors.textSecondary.opacity(0.5))
                        .animation(.easeInOut, value: currentStepIndex)
                }
            }
        }
    }
    
    @ViewBuilder
    private func stepIcon(for index: Int) -> some View {
        ZStack {
            if index < currentStepIndex {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
            } else if index == currentStepIndex {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(Theme.Colors.accent)
            } else {
                Circle()
                    .stroke(Theme.Colors.textSecondary.opacity(0.2), lineWidth: 1)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.3))
                    )
            }
        }
        .frame(width: 24, height: 24)
    }
    
    private func setupSteps() {
        switch type {
        case .audit:
            steps = [
                "Extracting NCN citations...",
                "Searching National Archives (TNA)...",
                "Cross-referencing official record...",
                "Analyzing formatting compliance...",
                "Generating authoritative feedback..."
            ]
        case .generate_notes:
            steps = [
                "Scanning case law database...",
                "Extracting Ratio Decidendi...",
                "Synthesizing legal principles...",
                "Structuring IRAC components...",
                "Polishing academic tone..."
            ]
        case .mark:
            steps = [
                "Analyzing assessment criteria...",
                "Evaluating AO1/AO2/AO3 levels...",
                "Detecting argumentative gaps...",
                "Benchmarking against first-class standards...",
                "Finalizing grade projection..."
            ]
        default:
            steps = [
                "Analyzing query intent...",
                "Consulting training data...",
                "Grounding with legal sources...",
                "Synthesizing response..."
            ]
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            if currentStepIndex < steps.count - 1 {
                withAnimation(.spring()) {
                    currentStepIndex += 1
                }
            } else {
                timer?.invalidate()
            }
        }
    }
}

extension View {
    func pulse() -> some View {
        self.modifier(PulseModifier())
    }
}

struct PulseModifier: ViewModifier {
    @State private var scale: CGFloat = 1.0
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    scale = 1.1
                }
            }
    }
}
