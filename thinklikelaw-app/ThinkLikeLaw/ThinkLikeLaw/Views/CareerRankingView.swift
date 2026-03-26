import SwiftUI

struct CareerRankingView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var xpService = XPService.shared
    
    let rankings = [
        (title: "Self-Represented Litigant", level: 1, icon: "person.badge.shield.exclamationmark", color: "#FF9500"),
        (title: "Law Graduate", level: 5, icon: "graduationcap.fill", color: "#5856D6"),
        (title: "Seasoned Lawyer", level: 15, icon: "briefcase.fill", color: "#007AFF"),
        (title: "King's Counsel", level: 30, icon: "crown.fill", color: "#AF52DE"),
        (title: "Supreme Court Justice", level: 100, icon: "building.columns.fill", color: "#FF2D55")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.bg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Current Status Card
                        currentStatusHeader
                        
                        // Ranking List
                        VStack(alignment: .leading, spacing: 16) {
                            Text("JUDICIAL HIERARCHY")
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .tracking(1.5)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                ForEach(rankings, id: \.title) { rank in
                                    RankingRow(rank: rank, currentLevel: xpService.level)
                                }
                            }
                        }
                        .padding(.top, 8)
                        
                        // XP Guide
                        xpGuideSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Career Rankings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private var currentStatusHeader: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Theme.Colors.accent.opacity(0.1), lineWidth: 8)
                    .frame(width: 110, height: 110)
                
                Circle()
                    .trim(from: 0, to: xpService.progressToNextLevel)
                    .stroke(
                        LinearGradient(colors: [Theme.Colors.accent, Theme.Colors.accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("\(xpService.level)")
                        .font(Theme.Fonts.outfit(size: 36, weight: .bold))
                    Text("LEVEL")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(.top, 8)
            
            VStack(spacing: 6) {
                Text(xpService.careerTitle)
                    .font(Theme.Fonts.outfit(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text("\(xpService.xpToNextLevel) XP to next promotion")
                    .font(Theme.Fonts.inter(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                Theme.Colors.surface.opacity(0.4)
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
            }
        )
        .cornerRadius(24)
        .padding(.horizontal, 4)
    }
    
    private var xpGuideSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ADVANCING YOUR CAREER")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(1.5)
            
            VStack(spacing: 16) {
                XPMethodRow(icon: "building.columns.fill", title: "Moot Court Oral Arguments", xp: "+100 - 1000 XP")
                XPMethodRow(icon: "checkmark.seal.fill", title: "Active Recall & SRS Mastery", xp: "+10 XP / Card")
                XPMethodRow(icon: "camera.viewfinder", title: "Smart Case Scanning", xp: "+30 XP / Scan")
                XPMethodRow(icon: "flame.fill", title: "Consistency (Daily Streak)", xp: "+20 XP / Day")
            }
        }
        .padding(24)
        .background(Theme.Colors.surface.opacity(0.3))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
    }
}

struct RankingRow: View {
    let rank: (title: String, level: Int, icon: String, color: String)
    let currentLevel: Int
    
    var isUnlocked: Bool { currentLevel >= rank.level }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color(hex: rank.color).opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: isUnlocked ? rank.icon : "lock.fill")
                    .foregroundColor(isUnlocked ? Color(hex: rank.color) : .gray)
                    .font(.system(size: 18, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(rank.title)
                    .font(Theme.Fonts.inter(size: 16, weight: .bold))
                    .foregroundColor(isUnlocked ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                
                Text(isUnlocked ? "Achieved at Level \(rank.level)" : "Unlocks at Level \(rank.level)")
                    .font(.system(size: 12))
                    .foregroundColor(isUnlocked ? Theme.Colors.accent.opacity(0.8) : Theme.Colors.textSecondary)
            }
            
            Spacer()
            
            if isUnlocked {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(Theme.Colors.accent)
                    .font(.system(size: 20))
            } else {
                ProgressView(value: Double(currentLevel), total: Double(rank.level))
                    .progressViewStyle(.linear)
                    .frame(width: 40)
                    .tint(.gray)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isUnlocked ? Theme.Colors.surface.opacity(0.6) : Theme.Colors.surface.opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isUnlocked ? Theme.Colors.accent.opacity(0.2) : Theme.Colors.glassBorder, lineWidth: 1)
        )
        .opacity(isUnlocked ? 1.0 : 0.7)
    }
}

struct XPMethodRow: View {
    let icon: String
    let title: String
    let xp: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Theme.Colors.accent)
                .font(.system(size: 14))
                .frame(width: 20)
            
            Text(title)
                .font(Theme.Fonts.inter(size: 14, weight: .medium))
                .foregroundColor(Theme.Colors.textPrimary)
            
            Spacer()
            
            Text(xp)
                .font(.system(size: 12, weight: .black))
                .foregroundColor(Theme.Colors.accent)
        }
    }
}

#Preview {
    CareerRankingView()
}
