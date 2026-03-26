import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

class AudioManager {
    static let shared = AudioManager()
    
    private var musicPlayer: AVAudioPlayer?
    #if os(iOS)
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    #endif
    
    private init() {
        #if os(iOS)
        hapticGenerator.prepare()
        #endif
    }
    
    // --- Master Control Helpers ---
    private var isMasterEnabled: Bool { UserDefaults.standard.bool(forKey: "audioMasterEnabled") }
    
    @MainActor
    func playTypingHaptic() {
        guard isMasterEnabled, UserDefaults.standard.bool(forKey: "audioTypingEnabled") else { return }
        #if os(iOS)
        hapticGenerator.impactOccurred()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }
    
    @MainActor
    func playSuccessHaptic() {
        guard isMasterEnabled else { return }
        #if os(iOS)
        let successGen = UINotificationFeedbackGenerator()
        successGen.notificationOccurred(.success)
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }
    
    func playMascotSound(named: String) {
        guard isMasterEnabled, UserDefaults.standard.bool(forKey: "audioMascotEnabled") else { return }
        // For now: print for debugging until assets are provided
        print("AudioManager: Playing Mascot Sound -> \(named)")
    }
    
    func updateMusicState() {
        let isMusicEnabled = UserDefaults.standard.bool(forKey: "audioMusicEnabled")
        
        if isMasterEnabled && isMusicEnabled {
            startChambersMusic()
        } else {
            stopChambersMusic()
        }
    }
    
    private func startChambersMusic() {
        if musicPlayer?.isPlaying == true { return }
        print("AudioManager: Starting Chambers Ambient Music")
    }
    
    private func stopChambersMusic() {
        print("AudioManager: Stopping Chambers Music")
        musicPlayer?.stop()
    }
}
