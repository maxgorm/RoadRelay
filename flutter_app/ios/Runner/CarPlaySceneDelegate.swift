import CarPlay
import Flutter

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    var interfaceController: CPInterfaceController?
    private var listTemplate: CPListTemplate?
    private var lastRunTime: Date?
    private var isProcessing = false
    
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
        
        let section = CPListSection(items: [sendItem])
        
        let template = CPListTemplate(title: "DriveBrief", sections: [section])
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
    
    private func handleSendSummaryTap(item: CPListItem, completion: @escaping () -> Void) {
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
    
    private func handleWorkflowResult(item: CPListItem, result: [String: Any]) {
        isProcessing = false
        lastRunTime = Date()
        
        let success = result["success"] as? Bool ?? false
        let message = result["message"] as? String ?? (success ? "Sent ✓" : "Failed ✗")
        
        print("[CarPlay] Workflow result: success=\(success), message=\(message)")
        
        if success {
            updateItemStatus(item: item, status: "Sent ✓")
        } else {
            updateItemStatus(item: item, status: "Failed ✗")
        }
        
        // Reset status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.updateItemStatus(item: item, status: self?.getSubtitleText() ?? "Ready")
        }
    }
    
    private func updateItemStatus(item: CPListItem, status: String) {
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
        
        let section = CPListSection(items: [sendItem])
        let template = CPListTemplate(title: "DriveBrief", sections: [section])
        
        self.listTemplate = template
        
        // Update the root template
        interfaceController.setRootTemplate(template, animated: false, completion: nil)
    }
    
    // MARK: - Fallback Mechanism
    
    private func writeFallbackTrigger() {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        UserDefaults.standard.set(timestamp, forKey: "carplay_trigger_timestamp")
        UserDefaults.standard.synchronize()
        print("[CarPlay] Wrote fallback trigger: \(timestamp)")
    }
}
