import SwiftUI
import AVFoundation
import Combine

struct LecturePlayerView: View {
    @Environment(\.dismiss) var dismiss
    let note: PersistedNote
    
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var segments: [TranscriptSegment] = []
    @State private var activeSegmentId: UUID?
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    
    var body: some View {
        ZStack {
            // Premium Mesh Gradient Background
            LinearGradient(
                colors: [
                    Theme.Colors.accent.opacity(0.15),
                    Theme.Colors.bg,
                    Theme.Colors.bg,
                    Theme.Colors.bg
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(Theme.Colors.textPrimary.opacity(0.3))
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text(note.title)
                            .font(Theme.Fonts.outfit(size: 14, weight: .bold))
                        Text(note.module?.name ?? "Uncategorized")
                            .font(Theme.Fonts.inter(size: 10, weight: .medium))
                            .foregroundColor(Theme.Colors.accent.opacity(0.7))
                    }
                    Spacer()
                    Button(action: {}) { 
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.Colors.textPrimary.opacity(0.3))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                // Lyrics View (The Core Sync Feature)
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 32) {
                            // Top padding to allow centering first items
                            Color.clear.frame(height: 100)
                            
                            if segments.isEmpty {
                                Text("No detailed transcript available for this lecture.")
                                    .font(Theme.Fonts.playfair(size: 24))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .padding(.horizontal, 24)
                            } else {
                                ForEach(segments) { segment in
                                    let isActive = activeSegmentId == segment.id
                                    Text(segment.text)
                                        .font(Theme.Fonts.inter(size: isActive ? 32 : 24, weight: isActive ? .bold : .semibold))
                                        .foregroundColor(isActive ? Theme.Colors.textPrimary : Theme.Colors.textSecondary.opacity(0.2))
                                        .scaleEffect(isActive ? 1.05 : 1.0)
                                        .blur(radius: isActive ? 0 : 0.5)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            seek(to: segment.timestamp)
                                        }
                                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isActive)
                                        .id(segment.id)
                                }
                            }
                            
                            // Bottom padding for scrollability
                            Color.clear.frame(height: 200)
                        }
                        .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity)
                    .onChange(of: activeSegmentId) { _, newValue in
                        if let id = newValue {
                            #if os(iOS)
                            Theme.HapticFeedback.light()
                            #endif
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
                
                // Compact Player Bar
                VStack(spacing: 24) {
                    // Progress Slider
                    VStack(spacing: 8) {
                        CustomSlider(value: $currentTime, range: 0...max(duration, 1)) { _ in
                            seek(to: currentTime)
                        }
                        
                        HStack {
                            Text(formatTime(currentTime))
                            Spacer()
                            Text(formatTime(duration))
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                    }
                    .padding(.horizontal, 32)
                    
                    HStack(spacing: 48) {
                        Button(action: { seek(by: -15) }) {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 24, weight: .medium))
                        }
                        
                        Button(action: togglePlayback) {
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.textPrimary)
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(Theme.Colors.bg)
                                    .offset(x: isPlaying ? 0 : 2)
                            }
                        }
                        .shadow(color: Theme.Colors.textPrimary.opacity(0.15), radius: 20, y: 10)
                        
                        Button(action: { seek(by: 15) }) {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 24, weight: .medium))
                        }
                    }
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.bottom, 40)
                }
                .background(
                    Theme.Colors.bg
                        .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 300).offset(y: -50))
                )
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onReceive(timer) { _ in
            if isPlaying {
                updateProgress()
            }
        }
    }
    
    private func setupPlayer() {
        // Load segments
        if let data = note.transcriptSegments {
            segments = (try? JSONDecoder().decode([TranscriptSegment].self, from: data)) ?? []
        }
        
        // Load Audio
        guard let audioUrlString = note.audioUrl, let url = URL(string: audioUrlString) else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
        } catch {
            print("LecturePlayer: Failed to load audio -> \(error)")
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
        } else {
            audioPlayer?.play()
        }
        isPlaying.toggle()
    }
    
    private func updateProgress() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
        
        // Update active segment
        if let segment = segments.last(where: { $0.timestamp <= currentTime }) {
            activeSegmentId = segment.id
        }
    }
    
    private func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
        updateProgress()
    }
    
    private func seek(by seconds: TimeInterval) {
        let newTime = max(0, min(duration, currentTime + seconds))
        seek(to: newTime)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Components

struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var onEditingChanged: (Bool) -> Void
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.Colors.textPrimary.opacity(0.1))
                    .frame(height: 4)
                
                Capsule()
                    .fill(Theme.Colors.textPrimary)
                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)))), height: 4)
                
                Circle()
                    .fill(Theme.Colors.textPrimary)
                    .frame(width: 12, height: 12)
                    .offset(x: max(0, min(geo.size.width - 12, geo.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)))) )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let percent = Double(gesture.location.x / geo.size.width)
                                value = range.lowerBound + percent * (range.upperBound - range.lowerBound)
                                onEditingChanged(true)
                            }
                            .onEnded { _ in
                                onEditingChanged(false)
                            }
                    )
            }
        }
        .frame(height: 12)
    }
}

