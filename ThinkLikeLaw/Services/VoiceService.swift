import AVFoundation

/**
 * VoiceService — Centralized engine for high-fidelity Text-to-Speech.
 * Prioritizes 'Enhanced' and 'Premium' quality voices for a more 'human' feel.
 */
class VoiceService {
    static let shared = VoiceService()
    
    private init() {}
    
    /**
     * Finds the best possible voice for the given language.
     * Prefers .enhanced or .premium quality if available.
     */
    func getBestVoice(language: String = "en-GB") -> AVSpeechSynthesisVoice? {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // 1. Try to find a 'Premium' voice (iOS 16+)
        if let premiumVoice = allVoices.first(where: { 
            $0.language.contains(language) && $0.quality == .premium 
        }) {
            return premiumVoice
        }
        
        // 2. Try to find an 'Enhanced' voice
        if let enhancedVoice = allVoices.first(where: { 
            $0.language.contains(language) && $0.quality == .enhanced 
        }) {
            return enhancedVoice
        }
        
        // 3. Fallback to any voice for that language
        return AVSpeechSynthesisVoice(language: language)
    }
    
    /**
     * Convenience method to create an utterance with the best voice.
     */
    func createUtterance(text: String, language: String = "en-GB", rate: Float = 0.52) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = getBestVoice(language: language)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        return utterance
    }
}
