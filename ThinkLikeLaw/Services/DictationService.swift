import Foundation
import Speech
import AVFoundation
import Combine

class DictationService: NSObject, ObservableObject {
    static let shared = DictationService()
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var audioEngine = AVAudioEngine()
    private var eqNode = AVAudioUnitEQ(numberOfBands: 3)
    
    @Published var transcript: String = ""
    @Published var segments: [TranscriptSegment] = []
    @Published var isRecording: Bool = false
    @Published var audioPower: Float = 0.0
    
    private var audioRecorder: AVAudioRecorder?
    private var audioURL: URL?
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: .defaultToSpeaker)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("DictationService: Audio session setup failed -> \(error)")
        }
        #endif
    }
    
    func startRecording() throws {
        // Reset state
        transcript = ""
        segments = []
        isRecording = true
        
        // 1. Setup Audio File for "Re-listening"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        audioURL = documentsPath.appendingPathComponent("lecture_\(Date().timeIntervalSince1970).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: audioURL!, settings: settings)
        audioRecorder?.prepareToRecord()
        audioRecorder?.record()
        
        // 2. Setup Speech Recognition
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        // Optimize for Legal Terminology (iOS 16+, macOS 13+)
        #if os(iOS)
        if #available(iOS 16.0, *) {
            recognitionRequest.addsPunctuation = true
        }
        #elseif os(macOS)
        if #available(macOS 13.0, *) {
            recognitionRequest.addsPunctuation = true
        }
        #endif
        
        // 3. Setup Audio Engine with Enhancement (DSP)
        let inputNode = audioEngine.inputNode
        
        // Voice Enhancement EQ (Boost clarity)
        eqNode.bands[0].filterType = .lowPass
        eqNode.bands[0].frequency = 3000
        eqNode.bands[0].gain = 2
        
        eqNode.bands[1].filterType = .highPass
        eqNode.bands[1].frequency = 300
        eqNode.bands[1].gain = 2
        
        // Mid-range clarity boost
        eqNode.bands[2].filterType = .parametric
        eqNode.bands[2].frequency = 1500
        eqNode.bands[2].bandwidth = 1.0
        eqNode.bands[2].gain = 3
        
        if !audioEngine.attachedNodes.contains(eqNode) {
            audioEngine.attach(eqNode)
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Disconnect first to ensure clean state on subsequent runs
        audioEngine.disconnectNodeInput(eqNode)
        audioEngine.disconnectNodeInput(audioEngine.mainMixerNode)
        
        audioEngine.connect(inputNode, to: eqNode, format: recordingFormat)
        audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: recordingFormat)
        
        // Prevent feedback loop while recording
        audioEngine.mainMixerNode.outputVolume = 0.0
        
        eqNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
            self?.recognitionRequest?.append(buffer)
            
            // Calculate Audio Power for Waveform UI
            let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData?[0], count: Int(buffer.frameLength)))
            let power = samples.reduce(0) { $0 + abs($1) } / Float(buffer.frameLength)
            
            DispatchQueue.main.async {
                self?.audioPower = power
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self?.transcript = result.bestTranscription.formattedString
                    
                    // Group segments into sentences for "Spotify Lyrics" style
                    let rawSegments = result.bestTranscription.segments
                    var grouped: [TranscriptSegment] = []
                    var currentSentence = ""
                    var startTime: TimeInterval = 0
                    
                    for (index, segment) in rawSegments.enumerated() {
                        if currentSentence.isEmpty { startTime = segment.timestamp }
                        currentSentence += (currentSentence.isEmpty ? "" : " ") + segment.substring
                        
                        // Break at punctuation or long-ish duration if needed
                        if segment.substring.contains(".") || segment.substring.contains("?") || segment.substring.contains("!") || index == rawSegments.count - 1 {
                            grouped.append(TranscriptSegment(
                                text: currentSentence.trimmingCharacters(in: .whitespaces),
                                timestamp: startTime,
                                duration: segment.timestamp + segment.duration - startTime
                            ))
                            currentSentence = ""
                        }
                    }
                    self?.segments = grouped
                }
            }
            if error != nil {
                self?.stopRecording()
            }
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        audioEngine.stop()
        eqNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        isRecording = false
        audioPower = 0.0
    }
    
    func getAudioURL() -> URL? {
        return audioURL
    }
}

struct TranscriptSegment: Codable, Identifiable {
    var id = UUID()
    let text: String
    let timestamp: TimeInterval
    let duration: TimeInterval
}
