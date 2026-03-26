import SwiftUI
import SwiftData

struct HeatmapView: View {
    @Query(sort: \PersistedStudySession.date) var sessions: [PersistedStudySession]
    
    private let calendar = Calendar.current
    private let columns = [GridItem(.fixed(12), spacing: 2)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Study Activity")
                    .font(Theme.Fonts.inter(size: 14, weight: .bold))
                Spacer()
                Text("\(totalMinutes) total mins")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(0..<15, id: \.self) { weekIndex in
                        VStack(spacing: 2) {
                            ForEach(0..<7, id: \.self) { dayIndex in
                                heatmapCell(for: weekIndex, day: dayIndex)
                            }
                        }
                    }
                }
                .padding(4)
            }
        }
        .padding(16)
        .glassCard()
    }
    
    private var totalMinutes: Int {
        sessions.reduce(0) { $0 + $1.durationMinutes }
    }
    
    private func heatmapCell(for week: Int, day: Int) -> some View {
        let date = calendar.date(byAdding: .day, value: -(104 - (week * 7 + day)), to: Date()) ?? Date()
        let startOfDay = calendar.startOfDay(for: date)
        
        let activity = sessions.filter { $0.date == startOfDay }.reduce(0) { $0 + $1.durationMinutes }
        
        return RoundedRectangle(cornerRadius: 2)
            .fill(colorForActivity(activity))
            .frame(width: 10, height: 10)
    }
    
    private func colorForActivity(_ minutes: Int) -> Color {
        if minutes == 0 { return Color.primary.opacity(0.05) }
        if minutes < 15 { return Theme.Colors.accent.opacity(0.3) }
        if minutes < 45 { return Theme.Colors.accent.opacity(0.6) }
        return Theme.Colors.accent
    }
}

struct StudyHeatmap: View {
    var body: some View {
        HeatmapView()
    }
}
