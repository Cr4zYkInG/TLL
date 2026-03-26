import Foundation
import CoreHaptics
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

class PencilSensoryEngine {
    static let shared = PencilSensoryEngine()
    
    private var hapticEngine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    
    private var audioEngine: AVAudioEngine = AVAudioEngine()
    private var noisePlayer: AVAudioPlayerNode = AVAudioPlayerNode()
    private var lowPassFilter: AVAudioUnitEQ = AVAudioUnitEQ(numberOfBands: 1)
    
    private var isPlaying = false
    
    private init() {
        #if os(iOS)
        setupHaptics()
        #endif
        setupAudio()
    }
    
    // MARK: - Haptics Setup
    private func setupHaptics() {
        #if os(iOS)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            
            // Define a subtle, continuous friction-like haptic
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
            
            let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: 100)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            
            continuousPlayer = try hapticEngine?.makeAdvancedPlayer(with: pattern)
            continuousPlayer?.loopEnabled = true
        } catch {
            print("PencilSensoryEngine: Haptic setup failed -> \(error)")
        }
        #endif
    }
    
    // MARK: - Audio Setup
    private func setupAudio() {
        audioEngine.attach(noisePlayer)
        audioEngine.attach(lowPassFilter)
        
        let format = audioEngine.outputNode.inputFormat(forBus: 0)
        audioEngine.connect(noisePlayer, to: lowPassFilter, format: format)
        audioEngine.connect(lowPassFilter, to: audioEngine.mainMixerNode, format: format)
        
        // Setup Low Pass on Band 0
        lowPassFilter.bands[0].filterType = .lowPass
        lowPassFilter.bands[0].frequency = 2000
        lowPassFilter.bands[0].bypass = false
        
        // Generate high-frequency white noise for 'pencil scratch'
        let frameCount = AVAudioFrameCount(format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        
        for i in 0..<Int(frameCount) {
            let noise = (Float(arc4random()) / Float(UInt32.max) * 2 - 1) * 0.1
            buffer.floatChannelData?[0][i] = noise
            if format.channelCount > 1 {
                buffer.floatChannelData?[1][i] = noise
            }
        }
        
        do {
            try audioEngine.start()
            noisePlayer.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        } catch {
            print("PencilSensoryEngine: AudioEngine start failed -> \(error)")
        }
    }
    
    // MARK: - Master Control Helpers
    private var isMasterEnabled: Bool { UserDefaults.standard.bool(forKey: "audioMasterEnabled") }
    
    // MARK: - Modulation
    
    func startSensorySession() {
        guard isMasterEnabled, !isPlaying else { return }
        isPlaying = true
        
        #if os(iOS)
        try? continuousPlayer?.start(atTime: 0)
        #endif
        noisePlayer.play()
    }
    
    func stopSensorySession() {
        guard isPlaying else { return }
        isPlaying = false
        
        #if os(iOS)
        try? continuousPlayer?.stop(atTime: 0)
        #endif
        noisePlayer.stop()
        
        print("PencilSensoryEngine: Session Stopped")
    }
    
    /**
     * Modulate feedback based on real-time pencil data
     * - pressure: 0.0 to 1.0+
     * - velocity: speed of movement
     */
    func update(pressure: CGFloat, velocity: CGFloat, tilt: CGFloat = 0.0) {
        guard isPlaying else { return }
        
        // 1. Modulate Haptic Intensity (Directly linked to pressure)
        #if os(iOS)
        let intensity = Float(min(max(pressure, 0.1), 1.0))
        let sharpness = Float(min(max(velocity / 1200.0, 0.1), 0.8))
        
        let intensityParam = CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: intensity, relativeTime: 0)
        let sharpnessParam = CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: sharpness, relativeTime: 0)
        
        try? continuousPlayer?.sendParameters([intensityParam, sharpnessParam], atTime: 0)
        #endif
        
        // 2. Modulate Audio (Velocity controls pitch/filter, Pressure controls volume)
        let targetVolume = Float(min(max(pressure * 0.8, 0.05), 0.7))
        let targetCutoff = Float(min(max(velocity * 2.5 + (500 * tilt), 800.0), 14000.0))
        
        noisePlayer.volume = targetVolume
        lowPassFilter.bands[0].frequency = targetCutoff
        
        // Add a micro-transient click if there's a sudden pressure spike
        #if os(iOS)
        if pressure > 0.8 {
            playTransientClick()
        }
        #endif
    }
    
    #if os(iOS)
    private func playTransientClick() {
        // Defined a tiny, sharp haptic transient
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        
        if let pattern = try? CHHapticPattern(events: [event], parameters: []) {
            let player = try? hapticEngine?.makePlayer(with: pattern)
            try? player?.start(atTime: 0)
        }
    }
    #endif
}
