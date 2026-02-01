import Flutter
import Foundation

/// Bridge between CarPlay (native) and Flutter
class CarPlayBridge {
    
    static let shared = CarPlayBridge()
    
    private let channelName = "carplay_bridge"
    private var methodChannel: FlutterMethodChannel?
    private var pendingCallbacks: [(([String: Any]) -> Void)] = []
    
    private init() {}
    
    // MARK: - Setup
    
    func setup(with controller: FlutterViewController) {
        methodChannel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger
        )
        
        methodChannel?.setMethodCallHandler { [weak self] call, result in
            self?.handleFlutterCall(call: call, result: result)
        }
        
        print("[CarPlayBridge] Initialized with channel: \(channelName)")
    }
    
    // MARK: - Flutter -> Native calls
    
    private func handleFlutterCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "workflowComplete":
            // Flutter is reporting workflow completion
            if let args = call.arguments as? [String: Any] {
                handleWorkflowComplete(result: args)
            }
            result(nil)
            
        case "ping":
            result(["status": "ok", "timestamp": ISO8601DateFormatter().string(from: Date())])
            
        case "simulateSmsNotification":
            // Simulate receiving an SMS via local notification
            if let args = call.arguments as? [String: Any],
               let sender = args["sender"] as? String,
               let message = args["message"] as? String {
                LocalNotificationHandler.shared.simulateSmsNotification(
                    from: sender,
                    message: message
                ) { success in
                    result(["success": success])
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "sender and message required", details: nil))
            }
            
        case "requestNotificationPermissions":
            LocalNotificationHandler.shared.requestPermissions { granted in
                result(["granted": granted])
            }
            
        case "requestSpeechPermission":
            SpeechRecognitionBridge.shared.requestAuthorization { granted in
                result(["granted": granted])
            }
            
        case "startListening":
            SpeechRecognitionBridge.shared.startListening(
                onResult: { [weak self] transcription in
                    self?.methodChannel?.invokeMethod("onSpeechResult", arguments: ["text": transcription])
                },
                onError: { [weak self] error in
                    self?.methodChannel?.invokeMethod("onSpeechError", arguments: ["error": error])
                }
            )
            result(["listening": true])
            
        case "stopListening":
            SpeechRecognitionBridge.shared.stopListening()
            result(["stopped": true])
            
        case "isSpeechAvailable":
            result(["available": SpeechRecognitionBridge.shared.isAvailable()])
            
        case "speakText":
            if let args = call.arguments as? [String: Any],
               let text = args["text"] as? String {
                // Use CarPlaySceneDelegate's TTS if available
                NotificationCenter.default.post(
                    name: NSNotification.Name("SpeakText"),
                    object: nil,
                    userInfo: ["text": text]
                )
                result(["speaking": true])
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "text required", details: nil))
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Native -> Flutter calls
    
    /// Trigger the summary workflow from CarPlay
    func triggerSummaryWorkflow(completion: @escaping ([String: Any]) -> Void) {
        guard let channel = methodChannel else {
            print("[CarPlayBridge] Channel not initialized, using fallback")
            completion(["success": false, "message": "Channel not ready"])
            return
        }
        
        // Store callback for when Flutter responds
        pendingCallbacks.append(completion)
        
        channel.invokeMethod("sendSummaryFromCarPlay", arguments: nil) { result in
            print("[CarPlayBridge] invokeMethod result: \(String(describing: result))")
            
            if let resultDict = result as? [String: Any] {
                // Direct result from Flutter
                self.handleWorkflowComplete(result: resultDict)
            } else if let error = result as? FlutterError {
                print("[CarPlayBridge] Flutter error: \(error.message ?? "unknown")")
                self.handleWorkflowComplete(result: [
                    "success": false,
                    "message": error.message ?? "Unknown error"
                ])
            }
        }
        
        // Timeout fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            if !(self?.pendingCallbacks.isEmpty ?? true) {
                print("[CarPlayBridge] Timeout waiting for Flutter response")
                self?.handleWorkflowComplete(result: [
                    "success": false,
                    "message": "Timeout - check phone for status"
                ])
            }
        }
    }
    
    /// Trigger voice query from CarPlay
    func triggerVoiceQuery(completion: @escaping ([String: Any]) -> Void) {
        guard let channel = methodChannel else {
            print("[CarPlayBridge] Channel not initialized for voice query")
            completion(["error": "Channel not ready"])
            return
        }
        
        // Store callback for when Flutter responds
        pendingCallbacks.append(completion)
        
        // Call Flutter method to start voice query (same pattern as triggerSummaryWorkflow)
        channel.invokeMethod("askAboutNotificationsFromCarPlay", arguments: nil) { result in
            print("[CarPlayBridge] askAboutNotificationsFromCarPlay result: \(String(describing: result))")
            
            if let resultDict = result as? [String: Any] {
                // Direct result from Flutter
                self.handleWorkflowComplete(result: resultDict)
            } else if let error = result as? FlutterError {
                print("[CarPlayBridge] Flutter error: \(error.message ?? "unknown")")
                self.handleWorkflowComplete(result: [
                    "success": false,
                    "message": error.message ?? "Unknown error"
                ])
            }
        }
        
        // Timeout fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            if !(self?.pendingCallbacks.isEmpty ?? true) {
                print("[CarPlayBridge] Timeout waiting for voice query response")
                self?.handleWorkflowComplete(result: [
                    "success": false,
                    "message": "Timeout - check phone for status"
                ])
            }
        }
    }
    
    /// Handle workflow completion from Flutter
    private func handleWorkflowComplete(result: [String: Any]) {
        print("[CarPlayBridge] Workflow complete: \(result)")
        
        // Call all pending callbacks
        let callbacks = pendingCallbacks
        pendingCallbacks.removeAll()
        
        for callback in callbacks {
            callback(result)
        }
    }
    
    // MARK: - Status
    
    func getStatus() -> [String: Any] {
        return [
            "channelReady": methodChannel != nil,
            "pendingCallbacks": pendingCallbacks.count
        ]
    }
}
