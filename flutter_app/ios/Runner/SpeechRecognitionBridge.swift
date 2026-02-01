import Foundation
import Speech
import AVFoundation

class SpeechRecognitionBridge: NSObject {
    
    static let shared = SpeechRecognitionBridge()
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var isListening = false
    
    private var onResult: ((String) -> Void)?
    private var onError: ((String) -> Void)?
    
    // Silence detection
    private var lastTranscription: String = ""
    private var silenceTimer: Timer?
    private let silenceTimeout: TimeInterval = 2.0 // Stop after 2 seconds of no new speech
    
    private override init() {
        super.init()
    }
    
    /// Request authorization for speech recognition
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }
    
    /// Start listening for speech
    func startListening(onResult: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        print("[SpeechRecognition] Starting to listen...")
        
        // Prevent double-start
        guard !isListening else {
            print("[SpeechRecognition] Already listening, ignoring")
            return
        }
        
        self.onResult = onResult
        self.onError = onError
        
        // Stop any previous session first
        stopListening()
        
        // Check if speech recognition is available (won't work on simulator)
        guard speechRecognizer?.isAvailable == true else {
            print("[SpeechRecognition] Speech recognizer not available (simulator?)")
            onError("Speech recognition not available on this device")
            return
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            onError("Failed to set up audio session: \(error.localizedDescription)")
            return
        }
        
        // Create a fresh audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            onError("Failed to create audio engine")
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            onError("Unable to create recognition request")
            return
        }
        
        let inputNode = audioEngine.inputNode
        recognitionRequest.shouldReportPartialResults = true
        
        isListening = true
        lastTranscription = ""
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                print("[SpeechRecognition] Transcription: \(transcription)")
                
                // If final result, immediately stop timer and return result
                if result.isFinal {
                    print("[SpeechRecognition] Got final result")
                    self.silenceTimer?.invalidate()
                    self.silenceTimer = nil
                    self.onResult?(transcription)
                    self.stopListening()
                    return
                }
                
                // For partial results, check if transcription changed and reset timer
                if transcription != self.lastTranscription && !transcription.isEmpty {
                    self.lastTranscription = transcription
                    self.resetSilenceTimer()
                }
            }
            
            if error != nil {
                print("[SpeechRecognition] Recognition error: \(error?.localizedDescription ?? "Unknown")")
                self.silenceTimer?.invalidate()
                self.silenceTimer = nil
                // Only report error if we haven't already sent a result
                if !self.lastTranscription.isEmpty {
                    print("[SpeechRecognition] Error after getting transcription, ignoring")
                } else {
                    self.onError?("Recognition error: \(error?.localizedDescription ?? "Unknown")")
                }
                self.stopListening()
            }
        }
        
        // Configure microphone input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("[SpeechRecognition] Audio engine started")
            // Start initial silence timer (in case user doesn't say anything)
            resetSilenceTimer()
        } catch {
            isListening = false
            onError("Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    /// Reset the silence timer - called when new speech is detected
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            guard let self = self, self.isListening else { return }
            print("[SpeechRecognition] Silence timeout - finalizing")
            
            // Return what we have so far
            if !self.lastTranscription.isEmpty {
                self.onResult?(self.lastTranscription)
            } else {
                self.onError?("No speech detected")
            }
            self.stopListening()
        }
    }
    
    /// Stop listening
    func stopListening() {
        print("[SpeechRecognition] Stopping...")
        
        silenceTimer?.invalidate()
        silenceTimer = nil
        isListening = false
        
        if let engine = audioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[SpeechRecognition] Failed to deactivate audio session: \(error)")
        }
    }
    
    /// Check if speech recognition is available
    func isAvailable() -> Bool {
        return speechRecognizer?.isAvailable ?? false
    }
}
