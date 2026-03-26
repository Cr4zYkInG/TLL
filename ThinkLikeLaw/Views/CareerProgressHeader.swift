import SwiftUI

/**
 * CareerProgressHeader — Displays the user's Jurisprudence XP and Career Rank.
 * High-fidelity glassmorphic design for the Dashboard.
 */
struct CareerProgressHeader: View {
    @ObservedObject var xpService = XPService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.fill")
                            .foregroundColor(Theme.Colors.accent)
                            .font(.system(size: 14))
                        Text(xpService.careerTitle.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(Theme.Colors.accent)
                            .tracking(2)
                    }
                    
                    Text("Level \(xpService.level)")
                        .font(Theme.Fonts.outfit(size: 24, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                }
                
                Spacer()
                
                XPBadge(xp: xpService.totalXP)
            }
            
            // Progress Bar
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.Colors.glassBorder.opacity(0.5))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.Colors.accent, Theme.Colors.accent.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(xpService.progressToNextLevel), height: 8)
                            .shadow(color: Theme.Colors.accent.opacity(0.2), radius: 5, x: 0, y: 2)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("\(Int(xpService.progressToNextLevel * 100))% to next rank")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text("\(xpService.xpToNextLevel) XP needed")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .padding(20)
        .background(Theme.Colors.surface.opacity(0.4))
        .cornerRadius(24)
        .glassCard()
        .shadow(color: Theme.Shadows.soft, radius: 20, y: 10)
    }
}

struct XPBadge: View {
    let xp: Int
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .foregroundColor(.yellow)
            Text("\(xp) XP")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.2), lineWidth: 1))
    }
}

#Preview {
    ZStack {
        Theme.Colors.bg.ignoresSafeArea()
        CareerProgressHeader()
            .padding()
    }
}
