import SwiftUI
import SwiftData

/**
 * MootLauncherSheet — Career hub for Judicial Lab: Moot Court.
 * Allows selecting scenario, difficulty, and viewing career stats.
 */
struct MootLauncherSheet: View {
    var hideCloseButton: Bool = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersistedMootResult.date, order: .reverse) var history: [PersistedMootResult]
    
    @State private var selectedArea = "Tort Law"
    @State private var selectedDifficulty: MootDifficulty = .selfRep
    @State private var selectedSide: MootSide = .random
    @State private var isNavigating = false
    @State private var generatedBriefing: String?
    @State private var isGenerating = false
    @State private var showingRankings = false
    
    let areasOfLaw = [
        "Tort Law",
        "Contract Law",
        "Criminal Law",
        "Public Law",
        "Equity & Trusts",
        "Land Law",
        "EU Law"
    ]
    
    var stats: (wins: Int, losses: Int) {
        let wins = history.filter { $0.isWin }.count
        let losses = history.count - wins
        return (wins, losses)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.bg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Career Profile
                        careerProfileHeader
                        
                        // Configuration
                        VStack(alignment: .leading, spacing: 20) {
                            sectionHeader(title: "SELECT AREA OF LAW", icon: "briefcase.fill")
                            
                            Picker("Area of Law", selection: $selectedArea) {
                                ForEach(areasOfLaw, id: \.self) { area in
                                    Text(area).tag(area)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding()
                            .background(Theme.Colors.surface)
                            .cornerRadius(12)
                            .glassCard()
                            .onChange(of: selectedArea) { generatedBriefing = nil }
                            
                            sectionHeader(title: "SELECT YOUR SIDE", icon: "person.2.fill")
                            
                            Picker("Your Side", selection: $selectedSide) {
                                ForEach(MootSide.allCases, id: \.self) { side in
                                    Text(side.rawValue).tag(side)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding()
                            .background(Theme.Colors.surface)
                            .cornerRadius(12)
                            .glassCard()
                            
                            // The case briefing preview has been moved entirely into the Moot Briefing Area
                            
                            sectionHeader(title: "SELECT CAREER LEVEL", icon: "crown.fill")
                            
                            VStack(spacing: 12) {
                                ForEach(MootDifficulty.allCases, id: \.self) { diff in
                                    DifficultyRow(
                                        difficulty: diff,
                                        isSelected: selectedDifficulty == diff,
                                        onSelect: { selectedDifficulty = diff }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Recent History
                        if !history.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                sectionHeader(title: "RECENT COURT APPEARANCES", icon: "clock.arrow.circlepath")
                                
                                ForEach(history.prefix(3)) { result in
                                    HistoryRow(result: result)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Action: Generates the case then auto-navigates
                        Button {
                            generateCase()
                        } label: {
                            HStack {
                                if isGenerating {
                                    Text("Drafting Case Bundle...")
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Don the Gown")
                                    Image(systemName: "building.columns.fill")
                                }
                            }
                            .font(Theme.Fonts.outfit(size: 18, weight: .bold))
                            .foregroundColor(Theme.Colors.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(colors: [isGenerating ? Color.gray : Theme.Colors.accent, isGenerating ? Color.gray.opacity(0.8) : Theme.Colors.accent.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                            )
                            .cornerRadius(16)
                            .shadow(color: (isGenerating ? Color.clear : Theme.Colors.accent.opacity(0.3)), radius: 10, y: 5)
                        }
                        .disabled(isGenerating)
                        .padding(24)
                        .padding(.top, 10)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Moot Career Hub")
            .toolbar {
                if !hideCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
            .navigationDestination(isPresented: $isNavigating) {
                if let briefing = generatedBriefing {
                    MootCourtView(scenario: briefing, difficulty: selectedDifficulty, userSide: effectiveSide)
                        .navigationBarBackButtonHidden()
                }
            }
            .sheet(isPresented: $showingRankings) {
                CareerRankingView()
            }
        }
    }
    
    private var careerProfileHeader: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.accent)
                    .frame(width: 80, height: 80)
                Image("ben_sitting")
                    .resizable()
                    .frame(width: 60, height: 60)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(XPService.shared.careerTitle)
                    .font(Theme.Fonts.outfit(size: 22, weight: .bold))
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("\(stats.wins)")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.green)
                        Text("Wins")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    
                    HStack(spacing: 4) {
                        Text("\(stats.losses)")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.red)
                        Text("Losses")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                
                Button(action: { showingRankings = true }) {
                    HStack(spacing: 4) {
                        Text("View Rankings")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.accent)
                    .padding(.top, 4)
                }
            }
            Spacer()
        }
        .padding(24)
        .background(Theme.Colors.surface.opacity(0.4))
        .cornerRadius(24)
        .glassCard()
        .padding(.horizontal)
    }
    
    private var effectiveSide: MootSide {
        if selectedSide == .random {
            return [.claimant, .respondent].randomElement() ?? .claimant
        }
        return selectedSide
    }
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.accent)
            Text(title)
                .font(.system(size: 10, weight: .black))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(1.5)
        }
    }
    
    private func generateCase() {
        isGenerating = true
        Task {
            do {
                let prompt = """
                Generate a comprehensive Moot Court case for the area of '\(selectedArea)'.
                Difficulty Level: \(selectedDifficulty.rawValue).
                The User is representing the side of: \(effectiveSide.rawValue).
                
                REQUIREMENTS:
                1. Provide a detailed section for **FACTS OF THE CASE**.
                2. Identify the **LEGAL ISSUES** for the appellate court.
                3. List **KEY AUTHORITIES & PRECEDENTS** (OSCOLA compliant).
                4. Tone: High-fidelity academic legal language.
                5. Structure: Use Markdown headers.
                
                CRITICAL INSTRUCTION: Since the user is the \(effectiveSide.rawValue), the facts or legal issues should be slightly nuanced to allow for a challenging but fair adversarial argument from the other side.
                
                Be thorough and simulate a real Supreme Court level problem.
                """
                let (response, _) = try await AIService.shared.callAI(tool: .moot_trial, content: prompt)
                
                await MainActor.run {
                    self.generatedBriefing = response
                    self.isGenerating = false
                    self.isNavigating = true
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                }
            }
        }
    }
}

struct DifficultyRow: View {
    let difficulty: MootDifficulty
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var isUnlocked: Bool {
        XPService.shared.level >= difficulty.unlockLevel
    }
    
    var body: some View {
        Button(action: {
            if isUnlocked {
                onSelect()
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isUnlocked ? Color(hex: difficulty.color).opacity(0.1) : Color.gray.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isUnlocked ? difficulty.icon : "lock.fill")
                        .foregroundColor(isUnlocked ? Color(hex: difficulty.color) : .gray)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(difficulty.rawValue)
                            .font(Theme.Fonts.inter(size: 16, weight: .bold))
                            .foregroundColor(isUnlocked ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                        
                        if !isUnlocked {
                            Text("Lvl \(difficulty.unlockLevel)+")
                                .font(.system(size: 8, weight: .black))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(isUnlocked ? difficultyDescription : "Ascend your career to unlock this tier.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                
                Spacer()
                
                if isSelected && isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Colors.accent)
                }
            }
            .padding(12)
            .background(isSelected && isUnlocked ? Theme.Colors.accent.opacity(0.05) : Theme.Colors.surface)
            .cornerRadius(16)
            .opacity(isUnlocked ? 1.0 : 0.6)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected && isUnlocked ? Theme.Colors.accent.opacity(0.3) : Theme.Colors.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
    }
    
    private var difficultyDescription: String {
        switch difficulty {
        case .selfRep: return "No lawyers present. Leniency is high."
        case .graduate: return "Standard legal precision required."
        case .lawyer: return "Seasoned adversaries & strict judicial conduct."
        case .kc: return "Elite technicality. No room for error."
        }
    }
}

struct HistoryRow: View {
    let result: PersistedMootResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.scenario)
                    .font(Theme.Fonts.inter(size: 13, weight: .bold))
                HStack(spacing: 8) {
                    Text(result.difficulty)
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.accent.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text(result.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(result.isWin ? "VERDICT: WIN" : "VERDICT: LOSS")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(result.isWin ? .green : .red)
                Text("\(Int(result.score))%")
                    .font(.caption2)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .padding()
        .background(Theme.Colors.surface.opacity(0.5))
        .cornerRadius(12)
        .glassCard()
    }
}
