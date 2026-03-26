import SwiftUI
import SwiftData

struct StudyStatsView: View {
    @Environment(\.dismiss) var dismiss
    @Query(sort: \PersistedStudySession.date, order: .reverse) var sessions: [PersistedStudySession]
    @Query var flashcards: [PersistedFlashcard]
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.bgLight.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Summary Cards
                        HStack(spacing: 16) {
                            StatCard(title: "Mastery", value: "\(calculateMastery())%", icon: "target", color: .blue)
                            StatCard(title: "Due Today", value: "\(calculateDueToday())", icon: "clock.fill", color: .orange)
                        }
                        
                        // Deck Progress Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("CARD PROGRESS (ALL DECKS)")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .tracking(2)
                            
                            DeckProgressView(flashcards: flashcards)
                                .padding()
                                .glassCard()
                        }
                        
                        // Heatmap Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("STUDY ACTIVITY")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .tracking(2)
                            
                            StatsHeatmap(sessions: sessions)
                                .padding()
                                .glassCard()
                        }
                        
                        // Forecast Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("30-DAY FORECAST")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .tracking(2)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                ForecastChart(flashcards: flashcards)
                                    .padding()
                            }
                            .glassCard()
                        }
                        
                        // Accuracy Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("RETENTION STRENGTH")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .tracking(2)
                            
                            RetentionMeter(score: calculateRetentionScore())
                                .padding()
                                .glassCard()
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Analytics")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Theme.Fonts.inter(size: 16, weight: .bold))
                }
            }
        }
    }
    
    private func calculateMastery() -> Int {
        let total = flashcards.count
        guard total > 0 else { return 0 }
        let mastered = flashcards.filter { $0.repetitions > 5 && $0.easeFactor > 2.0 }.count
        return Int((Double(mastered) / Double(total)) * 100)
    }
    
    private func calculateDueToday() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return flashcards.filter { $0.nextReviewDate <= today }.count
    }
    
    private func calculateRetentionScore() -> Double {
        // Mocked or calculated based on SRS history if we had it. 
        // For now, based on ease factors.
        let efSum = flashcards.reduce(0) { $0 + $1.easeFactor }
        guard !flashcards.isEmpty else { return 85.0 }
        return (efSum / Double(flashcards.count)) / 3.0 * 100
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(Theme.Fonts.outfit(size: 24, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .tracking(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard()
    }
}

struct DeckProgressView: View {
    let flashcards: [PersistedFlashcard]
    
    var body: some View {
        let newCards = flashcards.filter { $0.repetitions == 0 && ($0.isLearning ?? true) }.count
        let learningCards = flashcards.filter { $0.repetitions > 0 && ($0.isLearning ?? true) }.count
        let graduatedCards = flashcards.filter { !($0.isLearning ?? true) }.count
        
        HStack {
            ProgressStat(title: "New", count: newCards, color: .blue)
            Divider()
            ProgressStat(title: "Learning", count: learningCards, color: .orange)
            Divider()
            ProgressStat(title: "Graduated", count: graduatedCards, color: .green)
        }
    }
}

struct ProgressStat: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(Theme.Fonts.outfit(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 10, weight: .black))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatsHeatmap: View {
    let sessions: [PersistedStudySession]
    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<28) { day in
                    let date = Calendar.current.date(byAdding: .day, value: -day, to: Date())!
                    let intensity = getIntensity(for: date)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(intensity == 0 ? Theme.Colors.textSecondary.opacity(0.1) : Theme.Colors.accent.opacity(intensity))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            
            HStack {
                Text("Less")
                RoundedRectangle(cornerRadius: 2).fill(Theme.Colors.accent.opacity(0.2)).frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 2).fill(Theme.Colors.accent.opacity(0.5)).frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 2).fill(Theme.Colors.accent.opacity(0.8)).frame(width: 10, height: 10)
                Text("More focus")
            }
            .font(.system(size: 10))
            .foregroundColor(Theme.Colors.textSecondary)
        }
    }
    
    private func getIntensity(for date: Date) -> Double {
        let dayStart = Calendar.current.startOfDay(for: date)
        let totalMins = sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: dayStart) }
            .reduce(0) { $0 + $1.durationMinutes }
        
        if totalMins == 0 { return 0 }
        if totalMins < 10 { return 0.3 }
        if totalMins < 30 { return 0.6 }
        return 0.9
    }
}

struct ForecastChart: View {
    let flashcards: [PersistedFlashcard]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(0..<30) { day in
                let date = Calendar.current.date(byAdding: .day, value: day, to: Date())!
                let count = getCount(for: date)
                let height = CGFloat(min(count, 50)) * 2
                
                VStack(spacing: 8) {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .opacity(count == 0 ? 0 : 1)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(day == 0 ? Theme.Colors.accent : Theme.Colors.accent.opacity(0.3))
                        .frame(width: 20, height: max(height, 4))
                    
                    Text(dayName(for: date))
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .frame(height: 120)
    }
    
    private func getCount(for date: Date) -> Int {
        let dayStart = Calendar.current.startOfDay(for: date)
        return flashcards.filter { Calendar.current.isDate($0.nextReviewDate, inSameDayAs: dayStart) }.count
    }
    
    private func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EE"
        return formatter.string(from: date).uppercased()
    }
}

struct RetentionMeter: View {
    let score: Double
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Theme.Colors.textSecondary.opacity(0.1), lineWidth: 12)
                
                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: -4) {
                    Text("\(Int(score))%")
                        .font(Theme.Fonts.outfit(size: 32, weight: .bold))
                    Text("RETENTION")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .tracking(1)
                }
            }
            .frame(width: 140, height: 140)
            
            Text("Based on your Ease Factor stability across all sets.")
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}
