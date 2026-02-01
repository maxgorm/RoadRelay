import CarPlay
import Flutter
import AVFoundation

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    var interfaceController: CPInterfaceController?
    private var listTemplate: CPListTemplate?
    private var lastRunTime: Date?
    private var isProcessing = false
    private var lastSummaryText: String?
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    override init() {
        super.init()
        // Register for SpeakText notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSpeakText(_:)),
            name: NSNotification.Name("SpeakText"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleSpeakText(_ notification: Notification) {
        guard let text = notification.userInfo?["text"] as? String else { return }
        speakText(text)
    }
    
    // MARK: - Text-to-Speech
    
    private func speakText(_ text: String) {
        print("[CarPlay] Speaking text: \(text)")
        
        // Stop any current speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        // Create and configure utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Use premium Samantha voice
        let preferredVoices = [
            "com.apple.voice.premium.en-US.Samantha",
            "com.apple.voice.enhanced.en-US.Samantha",
            "com.apple.ttsbundle.Samantha-premium",
            "com.apple.ttsbundle.Samantha-compact"
        ]
        
        var selectedVoice: AVSpeechSynthesisVoice?
        for voiceId in preferredVoices {
            if let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
                selectedVoice = voice
                print("[CarPlay] Using premium voice: \(voiceId)")
                break
            }
        }
        
        // Fallback to best available en-US voice
        if selectedVoice == nil {
            let allVoices = AVSpeechSynthesisVoice.speechVoices()
            if #available(iOS 16.0, *) {
                selectedVoice = allVoices.first { voice in
                    voice.language == "en-US" && voice.quality == .enhanced
                } ?? allVoices.first { voice in
                    voice.language == "en-US" && voice.quality == .premium
                }
            }
            
            if selectedVoice == nil {
                selectedVoice = allVoices.first { voice in
                    voice.language == "en-US"
                } ?? AVSpeechSynthesisVoice(language: "en-US")
            }
            
            if let voice = selectedVoice {
                print("[CarPlay] Using voice: \(voice.name)")
            }
        }
        
        utterance.voice = selectedVoice
        
        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[CarPlay] Audio session error: \(error)")
        }
        
        speechSynthesizer.speak(utterance)
    }
    
    // MARK: - CPTemplateApplicationSceneDelegate
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        
        print("[CarPlay] Connected to CarPlay interface")
        
        // Create and display the main template
        let template = createMainTemplate()
        self.listTemplate = template
        interfaceController.setRootTemplate(template, animated: true, completion: nil)
    }
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        self.listTemplate = nil
        print("[CarPlay] Disconnected from CarPlay interface")
    }
    
    // MARK: - Template Creation
    
    private func createMainTemplate() -> CPListTemplate {
        let subtitleText = getSubtitleText()
        
        let sendItem = CPListItem(
            text: "Send Summary Text",
            detailText: subtitleText,
            image: UIImage(systemName: "envelope.fill")
        )
        
        sendItem.handler = { [weak self] item, completion in
            self?.handleSendSummaryTap(item: item, completion: completion)
        }
        
        // Voice query button - always visible
        let askItem = CPListItem(
            text: "🎤 Ask About Notifications",
            detailText: "Tap to ask a question",
            image: UIImage(systemName: "mic.fill")
        )
        askItem.handler = { [weak self] _, completion in
            self?.handleVoiceQuery()
            completion()
        }
        
        var items: [CPListItem] = [sendItem, askItem]
        
        // Add "Read Last Summary" button if we have a summary
        if lastSummaryText != nil {
            let readItem = CPListItem(
                text: "🔊 Read Last Summary",
                detailText: "Tap to hear the summary",
                image: UIImage(systemName: "speaker.wave.3.fill")
            )
            readItem.handler = { [weak self] _, completion in
                self?.readSummaryAloud()
                completion()
            }
            items.append(readItem)
        }
        
        let section = CPListSection(items: items)
        
        let template = CPListTemplate(title: "RoadRelay", sections: [section])
        template.emptyViewSubtitleVariants = ["No actions available"]
        
        return template
    }
    
    private func getSubtitleText() -> String {
        if isProcessing {
            return "Sending..."
        }
        
        if let lastRun = lastRunTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Last run: \(formatter.string(from: lastRun))"
        }
        
        return "Ready"
    }
    
    // MARK: - Action Handling
    
    private func handleVoiceQuery() {
        print("[CarPlay] Voice query tapped")
        
        // Check if speech recognition is available (won't work on simulator)
        guard SpeechRecognitionBridge.shared.isAvailable() else {
            speakText("Voice queries require a physical device with a microphone. This feature is not available in the simulator.")
            return
        }
        
        // Show listening prompt
        speakText("What would you like to know about your notification?")
        
        // Small delay to let the prompt finish before listening
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            // Trigger voice recognition via Flutter
            CarPlayBridge.shared.triggerVoiceQuery { result in
                // Response will be spoken automatically by VoiceQueryService
                print("[CarPlay] Voice query triggered: \(result)")
            }
        }
    }
    
    private func handleSendSummaryTap(item: any CPSelectableListItem, completion: @escaping () -> Void) {
        guard !isProcessing else {
            completion()
            return
        }
        
        print("[CarPlay] Send Summary tapped")
        
        isProcessing = true
        updateItemStatus(item: item, status: "Sending...")
        
        // Try to invoke Flutter via MethodChannel
        CarPlayBridge.shared.triggerSummaryWorkflow { [weak self] result in
            DispatchQueue.main.async {
                self?.handleWorkflowResult(item: item, result: result)
                completion()
            }
        }
        
        // Also write fallback trigger to UserDefaults
        writeFallbackTrigger()
    }
    
    private func handleWorkflowResult(item: any CPSelectableListItem, result: [String: Any]) {
        isProcessing = false
        lastRunTime = Date()
        
        let success = result["success"] as? Bool ?? false
        let message = result["message"] as? String ?? (success ? "Sent ✓" : "Failed ✗")
        
        // Extract summary text if available
        if let summaryText = result["summary_text"] as? String {
            lastSummaryText = summaryText
        }
        
        print("[CarPlay] Workflow result: success=\(success), message=\(message)")
        
        if success {
            updateItemStatus(item: item, status: "Sent ✓")
            
            // Show alert with the summary and option to read aloud
            showSummaryAlert()
        } else {
            updateItemStatus(item: item, status: "Failed ✗")
        }
        
        // Reset status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.refreshFullTemplate()
        }
    }
    
    private func showSummaryAlert() {
        guard let interfaceController = interfaceController,
              let summary = lastSummaryText else { return }
        
        // Truncate for display
        let displayText = summary.count > 200 ? String(summary.prefix(200)) + "..." : summary
        
        let alert = CPAlertTemplate(
            titleVariants: ["📬 Summary Ready"],
            actions: [
                CPAlertAction(title: "🔊 Read Aloud", style: .default) { [weak self] _ in
                    interfaceController.dismissTemplate(animated: true, completion: nil)
                    self?.readSummaryAloud()
                },
                CPAlertAction(title: "OK", style: .cancel) { _ in
                    interfaceController.dismissTemplate(animated: true, completion: nil)
                }
            ]
        )
        
        interfaceController.presentTemplate(alert, animated: true, completion: nil)
    }
    
    private func readSummaryAloud() {
        guard let summary = lastSummaryText else {
            print("[CarPlay] No summary to read")
            return
        }
        
        speakText(summary)
    }
    
    private func updateItemStatus(item: any CPSelectableListItem, status: String) {
        // CPListItem doesn't allow direct modification after creation in iOS 14+
        // We need to recreate the template
        refreshTemplate(with: status)
    }
    
    private func refreshTemplate(with status: String) {
        guard let interfaceController = interfaceController else { return }
        
        let sendItem = CPListItem(
            text: "Send Summary Text",
            detailText: status,
            image: UIImage(systemName: "envelope.fill")
        )
        
        sendItem.handler = { [weak self] item, completion in
            self?.handleSendSummaryTap(item: item, completion: completion)
        }
        
        // Voice query button - always visible
        let askItem = CPListItem(
            text: "🎤 Ask About Notifications",
            detailText: "Tap to ask a question",
            image: UIImage(systemName: "mic.fill")
        )
        askItem.handler = { [weak self] _, completion in
            self?.handleVoiceQuery()
            completion()
        }
        
        var items: [CPListItem] = [sendItem, askItem]
        
        // Add "Read Last Summary" button if we have a summary
        if lastSummaryText != nil {
            let readItem = CPListItem(
                text: "🔊 Read Last Summary",
                detailText: "Tap to hear the summary",
                image: UIImage(systemName: "speaker.wave.3.fill")
            )
            readItem.handler = { [weak self] _, completion in
                self?.readSummaryAloud()
                completion()
            }
            items.append(readItem)
        }
        
        let section = CPListSection(items: items)
        let template = CPListTemplate(title: "RoadRelay", sections: [section])
        
        self.listTemplate = template
        
        // Update the root template
        interfaceController.setRootTemplate(template, animated: false, completion: nil)
    }
    
    private func refreshFullTemplate() {
        refreshTemplate(with: getSubtitleText())
    }
    
    // MARK: - Fallback Mechanism
    
    private func writeFallbackTrigger() {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        UserDefaults.standard.set(timestamp, forKey: "carplay_trigger_timestamp")
        UserDefaults.standard.synchronize()
        print("[CarPlay] Wrote fallback trigger: \(timestamp)")
    }
}
