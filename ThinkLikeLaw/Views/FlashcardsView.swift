import SwiftUI
import SwiftData

struct FlashcardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersistedFlashcardSet.createdAt, order: .reverse) var flashcardSets: [PersistedFlashcardSet]
    
    struct StudySession: Identifiable {
        let id = UUID()
        let deck: PersistedFlashcardSet
        let isCram: Bool
    }
    
    struct MatchSession: Identifiable {
        let id = UUID()
        let deck: PersistedFlashcardSet
    }
    
    @State private var studySession: StudySession?
    @State private var matchSession: MatchSession?
    @State private var showCreateModal = false
    @State private var showStats = false
    @State private var setToDelete: PersistedFlashcardSet?
    @State private var showDeleteConfirmation = false
    
    var totalDue: Int {
        flashcardSets.reduce(0) { $0 + $1.cards.filter { $0.nextReviewDate <= Date().addingTimeInterval(60) }.count }
    }
    
    var totalCards: Int {
        flashcardSets.reduce(0) { $0 + $1.cards.count }
    }
    
    var body: some View {
        ZStack {
            Theme.Colors.bgLight.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    // Hero Header
                    headerSection
                    
                    // Quick Stats Ribbon
                    if !flashcardSets.isEmpty {
                        statsRibbon
                    }
                    
                    // Deck List
                    if flashcardSets.isEmpty {
                        emptyState
                    } else {
                        deckList
                    }
                }
                .padding(24)
            }
        }
        #if os(iOS)
        .fullScreenCover(item: $studySession) { session in
            FlashcardStudyView(set: session.deck, isCramMode: session.isCram)
        }
        .fullScreenCover(item: $matchSession) { session in
            FlashcardMatchView(set: session.deck)
        }
        #else
        .sheet(item: $studySession) { session in
            FlashcardStudyView(set: session.deck, isCramMode: session.isCram)
        }
        .sheet(item: $matchSession) { session in
            FlashcardMatchView(set: session.deck)
        }
        #endif
        .sheet(isPresented: $showCreateModal) {
            CreateFlashcardSetView()
        }
        .sheet(isPresented: $showStats) {
            StudyStatsView()
        }
        .alert("Delete Deck?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let deck = setToDelete {
                    modelContext.delete(deck)
                    try? modelContext.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove this deck and all its cards.")
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Revision Cards")
                    .font(Theme.Fonts.outfit(size: 28, weight: .bold))
                
                Text("Spaced repetition for long-term mastery.")
                    .font(Theme.Fonts.inter(size: 15))
                    .foregroundColor(Theme.Colors.textSecondaryLight)
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                Button(action: { showStats = true }) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(10)
                        .background(Theme.Colors.surface)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
                }
                
                Button(action: { showCreateModal = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("New")
                            .font(Theme.Fonts.outfit(size: 14, weight: .bold))
                    }
                    .foregroundColor(Theme.Colors.onAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.Colors.accent)
                    .cornerRadius(12)
                    .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 8, y: 4)
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Stats Ribbon
    
    private var statsRibbon: some View {
        HStack(spacing: 0) {
            StatPill(value: "\(flashcardSets.count)", label: "DECKS", color: .blue)
            StatPill(value: "\(totalCards)", label: "CARDS", color: .purple)
            StatPill(value: "\(totalDue)", label: "DUE", color: totalDue > 0 ? .orange : .green)
        }
        .padding(4)
        .background(Theme.Colors.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder, lineWidth: 1))
    }
    
    // MARK: - Deck List
    
    private var deckList: some View {
        LazyVStack(spacing: 12) {
            ForEach(flashcardSets) { deck in
                DeckCard(
                    deck: deck,
                    onStudy: {
                        studySession = StudySession(deck: deck, isCram: false)
                    },
                    onCram: {
                        studySession = StudySession(deck: deck, isCram: true)
                    },
                    onMatch: {
                        matchSession = MatchSession(deck: deck)
                    },
                    onDelete: {
                        setToDelete = deck
                        showDeleteConfirmation = true
                    }
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)
            
            ZStack {
                Circle()
                    .fill(Theme.Colors.accent.opacity(0.08))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(Theme.Colors.accent.opacity(0.5))
            }
            
            VStack(spacing: 8) {
                Text("No decks yet")
                    .font(Theme.Fonts.outfit(size: 22, weight: .bold))
                Text("Create your first flashcard deck to start\nmastering legal concepts with spaced repetition.")
                    .font(Theme.Fonts.inter(size: 15))
                    .foregroundColor(Theme.Colors.textSecondaryLight)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showCreateModal = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Create First Deck")
                }
                .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                .foregroundColor(Theme.Colors.onAccent)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Theme.Colors.accent)
                .cornerRadius(14)
                .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 10, y: 5)
            }
            
            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.surface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.glassBorder, lineWidth: 1))
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .black))
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// MARK: - Deck Card

private struct DeckCard: View {
    let deck: PersistedFlashcardSet
    let onStudy: () -> Void
    let onCram: () -> Void
    let onMatch: () -> Void
    let onDelete: () -> Void
    
    var dueCount: Int {
        deck.cards.filter { $0.nextReviewDate <= Date().addingTimeInterval(60) }.count
    }
    
    var newCount: Int {
        deck.cards.filter { ($0.isLearning ?? true) && $0.repetitions == 0 }.count
    }
    
    var graduatedCount: Int {
        deck.cards.filter { !($0.isLearning ?? true) }.count
    }
    
    var masteryPercent: Double {
        guard !deck.cards.isEmpty else { return 0 }
        return Double(graduatedCount) / Double(deck.cards.count)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Row
            HStack(spacing: 16) {
                // Mastery Ring
                ZStack {
                    Circle()
                        .stroke(Theme.Colors.textSecondary.opacity(0.08), lineWidth: 4)
                        .frame(width: 48, height: 48)
                    
                    Circle()
                        .trim(from: 0, to: masteryPercent)
                        .stroke(
                            masteryPercent == 1.0 ? Color.green : Theme.Colors.accent,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(masteryPercent * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(masteryPercent == 1.0 ? .green : Theme.Colors.accent)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(deck.topic)
                        .font(Theme.Fonts.outfit(size: 17, weight: .semibold))
                        .lineLimit(1)
                    
                    // Mastery Distribution Bar
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geo in
                            HStack(spacing: 2) {
                                // Graduated (Green)
                                if graduatedCount > 0 {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.green.opacity(0.8))
                                        .frame(width: geo.size.width * (Double(graduatedCount) / Double(deck.cards.count)))
                                }
                                // Learning/Due (Orange)
                                if dueCount > 0 {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.orange.opacity(0.8))
                                        .frame(width: geo.size.width * (Double(dueCount) / Double(deck.cards.count)))
                                }
                                // New (Blue)
                                if newCount > 0 {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.blue.opacity(0.8))
                                        .frame(width: geo.size.width * (Double(newCount) / Double(deck.cards.count)))
                                }
                            }
                        }
                        .frame(height: 4)
                        .background(Theme.Colors.textSecondary.opacity(0.05))
                        .cornerRadius(2)
                        
                        HStack(spacing: 8) {
                            Text("\(graduatedCount) Mastery")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.green)
                            Text("\(dueCount) Due")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.orange)
                            Text("\(newCount) New")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 8) {
                    // Cram
                    Button(action: onCram) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(10)
                            .background(.orange.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Cram Mode")
                    
                    // Match
                    Button(action: onMatch) {
                        Image(systemName: "puzzlepiece.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.purple)
                            .padding(10)
                            .background(.purple.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Match Game")
                    
                    // Study
                    Button(action: onStudy) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(dueCount > 0 ? Theme.Colors.onAccent : Theme.Colors.textSecondary)
                            .padding(10)
                            .background(dueCount > 0 ? Theme.Colors.accent : Theme.Colors.textSecondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(dueCount == 0)
                    .help("Study Due Cards")
                }
            }
            .padding(16)
            
            // Mastery Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.Colors.textSecondary.opacity(0.05))
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.Colors.accent, Theme.Colors.accent.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * masteryPercent)
                }
            }
            .frame(height: 3)
            .clipShape(RoundedRectangle(cornerRadius: 0))
        }
        .background(Theme.Colors.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(dueCount > 0 ? Theme.Colors.accent.opacity(0.2) : Theme.Colors.glassBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
        .contextMenu {
            Button(action: onCram) {
                Label("Cram All Cards", systemImage: "bolt.fill")
            }
            Button(action: onStudy) {
                Label("Study Due Cards", systemImage: "play.fill")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete Deck", systemImage: "trash")
            }
        }
    }
}

private struct MiniCardBadge: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 3) {
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color.opacity(0.7))
        }
    }
}
