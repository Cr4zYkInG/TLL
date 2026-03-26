import SwiftUI

struct DashboardMetricsHeader: View {
    @EnvironmentObject var authState: AuthState
    
    var body: some View {
        HStack(spacing: Theme.isPhone ? 8 : 16) {
            // Study Time
            MetricMiniCard(
                icon: "clock.fill",
                title: "Study Time",
                value: formatTime(authState.todayStudyMinutes),
                subtitle: "+\(authState.todayStudyMinutes)m",
                color: Color.blue
            )
            
            // Streak
            MetricMiniCard(
                icon: "flame.fill",
                title: "Streak",
                value: "\(authState.currentStreak) Days",
                subtitle: "Keep it up!",
                color: Color.orange
            )
            
            // Leaderboard Rank
            NavigationLink(destination: LeaderboardView()) {
                MetricMiniCard(
                    icon: "trophy.fill",
                    title: "Rank",
                    value: "#42",
                    subtitle: "Top 10%",
                    color: Color.yellow
                )
            }
        }
    }
    
    private func formatTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

struct MetricMiniCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14, weight: .bold))
                
                Text(title)
                    .font(Theme.Fonts.outfit(size: 10, weight: .black))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            
            Text(value)
                .font(Theme.Fonts.outfit(size: 22, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            Text(subtitle)
                .font(Theme.Fonts.inter(size: 11, weight: .medium))
                .foregroundColor(Theme.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.isPhone ? 12 : 16)
        .glassCard()
    }
}

#Preview {
    ZStack {
        Theme.Colors.bg.ignoresSafeArea()
        DashboardMetricsHeader()
            .padding()
    }
}
