import SwiftUI
import SwiftData

struct FlashcardMatchView: View {
    @Environment(\.dismiss) var dismiss
    let set: PersistedFlashcardSet
    
    @State private var tiles: [MatchTile] = []
    @State private var selectedTileId: UUID?
    @State private var matchedIds: Set<UUID> = []
    @State private var startTime = Date()
    @State private var gameTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isGameOver = false
    @State private var lives = 3
    @State private var wrongTileId: UUID?
    @State private var correctTileIds: Set<UUID> = []
    @State private var comboCount = 0
    @State private var lastMatchTime: Date?
    @State private var isDefeated = false
    
    struct MatchTile: Identifiable, Equatable {
        let id = UUID()
        let cardId: PersistentIdentifier
        let text: String
        let isQuestion: Bool
    }
    
    var body: some View {
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()
            
            // Dynamic Background Circle
            Circle()
                .fill(Theme.Colors.accent.opacity(0.1))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: 100, y: -200)
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    
                    Spacer()
                    
                    // Hearts / Lives
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in
                            Image(systemName: i < lives ? "heart.fill" : "heart")
                                .foregroundColor(i < lives ? .red : .gray.opacity(0.3))
                                .font(.system(size: 18))
                                .symbolEffect(.bounce, value: lives == i + 1)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.surface.opacity(0.4))
                    .cornerRadius(20)
                    
                    Spacer()
                    
                    Text(formatTime(gameTime))
                        .font(Theme.Fonts.outfit(size: 20, weight: .bold))
                        .monospacedDigit()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                if isGameOver || isDefeated {
                    gameOverView
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(tiles) { tile in
                                if !matchedIds.contains(tile.id) {
                                    tileView(tile: tile)
                                        .transition(.scale.combined(with: .opacity))
                                } else {
                                    Spacer().frame(height: 100)
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .onAppear {
            setupGame()
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private var gameOverView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: isGameOver ? "trophy.fill" : "heart.slash.fill")
                .font(.system(size: 80))
                .foregroundColor(isGameOver ? .yellow : .red)
            
            VStack(spacing: 8) {
                Text(isGameOver ? "Case Closed!" : "Out of Appeals!")
                    .font(Theme.Fonts.outfit(size: 32, weight: .bold))
                Text(isGameOver ? "You matched all terms in \(formatTime(gameTime))" : "Try again to master these concepts.")
                    .font(Theme.Fonts.inter(size: 18))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: { setupGame() }) {
                Text(isGameOver ? "Play Again" : "Retry Arena")
                    .font(Theme.Fonts.outfit(size: 18, weight: .bold))
                    .foregroundColor(Theme.Colors.onAccent)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(isGameOver ? Theme.Colors.accent : .red)
                    .cornerRadius(16)
            }
            
            Button(action: { dismiss() }) {
                Text("Back to Chambers")
                    .font(Theme.Fonts.inter(size: 16, weight: .bold))
                    .foregroundColor(Theme.Colors.accent)
            }
            
            Spacer()
        }
    }
    
    private func tileView(tile: MatchTile) -> some View {
        let isCorrect = correctTileIds.contains(tile.id)
        let isWrong = wrongTileId == tile.id
        let isSelected = selectedTileId == tile.id
        
        return Button {
            handleTileTap(tile)
        } label: {
            Text(tile.text)
                .font(Theme.Fonts.inter(size: 14, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(12)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 100)
                .background(
                    isCorrect ? Color.green.opacity(0.2) :
                    isWrong ? Color.red.opacity(0.2) :
                    isSelected ? Theme.Colors.accent.opacity(0.15) :
                    Theme.Colors.surface.opacity(0.6)
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isCorrect ? Color.green :
                            isWrong ? Color.red :
                            isSelected ? Theme.Colors.accent : Theme.Colors.glassBorder,
                            lineWidth: (isSelected || isCorrect || isWrong) ? 2 : 1
                        )
                )
                .scaleEffect((isCorrect || isWrong) ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isCorrect || isWrong)
        }
        .buttonStyle(.plain)
    }
    
    private func setupGame() {
        let cards = Array(set.cards.shuffled().prefix(8))
        var newTiles: [MatchTile] = []
        
        for card in cards {
            newTiles.append(MatchTile(cardId: card.id, text: card.question, isQuestion: true))
            newTiles.append(MatchTile(cardId: card.id, text: card.answer, isQuestion: false))
        }
        
        tiles = newTiles.shuffled()
        matchedIds = []
        isGameOver = false
        startTime = Date()
        gameTime = 0
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            gameTime = Date().timeIntervalSince(startTime)
        }
    }
    
    private func handleTileTap(_ tile: MatchTile) {
        if let firstId = selectedTileId {
            if firstId == tile.id {
                selectedTileId = nil
                return
            }
            
            let firstTile = tiles.first { $0.id == firstId }!
            
                if firstTile.cardId == tile.cardId && firstTile.isQuestion != tile.isQuestion {
                    // Match!
                    correctTileIds = [firstId, tile.id]
                    comboCount += 1
                    
                    #if os(iOS)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    #endif
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.spring()) {
                            matchedIds.insert(firstId)
                            matchedIds.insert(tile.id)
                            correctTileIds.removeAll()
                        }
                    }
                    selectedTileId = nil
                    
                    if matchedIds.count + 2 == tiles.count {
                        timer?.invalidate()
                        isGameOver = true
                        MascotManager.shared.celebrateSuccess()
                    }
                } else {
                    // Mismatch
                    wrongTileId = tile.id
                    lives -= 1
                    comboCount = 0
                    
                    #if os(iOS)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    #endif
                    
                    if lives <= 0 {
                        timer?.invalidate()
                        isDefeated = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        wrongTileId = nil
                        selectedTileId = nil
                    }
                }
        } else {
            selectedTileId = tile.id
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let m = Int(time) / 60
        let s = Int(time) % 60
        let ms = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", m, s, ms)
    }
}
