import Foundation
import UserNotifications
import Intents

/// Handles local notifications to simulate SMS messages on the simulator
/// Uses Communication Notifications for CarPlay compatibility
class LocalNotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    
    static let shared = LocalNotificationHandler()
    
    private override init() {
        super.init()
    }
    
    /// Request notification permissions
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        // Request authorization including announcement option for Siri to read aloud
        center.requestAuthorization(options: [.alert, .sound, .badge, .announcement]) { granted, error in
            if let error = error {
                print("[LocalNotification] Permission error: \(error)")
            }
            print("[LocalNotification] Permission granted: \(granted)")
            completion(granted)
        }
    }
    
    /// Schedule a Communication Notification to simulate an SMS (CarPlay compatible)
    func simulateSmsNotification(from sender: String, message: String, completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        
        // Create the notification content
        let content = UNMutableNotificationContent()
        content.title = sender
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "SMS_NOTIFICATION"
        
        // Create a Communication Notification using INSendMessageIntent
        // This is required for CarPlay to recognize and announce the notification
        let senderPerson = INPerson(
            personHandle: INPersonHandle(value: "+13135727768", type: .phoneNumber),
            nameComponents: nil,
            displayName: sender,
            image: nil,
            contactIdentifier: nil,
            customIdentifier: "roadrelay-sender"
        )
        
        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: message,
            speakableGroupName: INSpeakableString(spokenPhrase: sender),
            conversationIdentifier: "roadrelay-conversation",
            serviceName: nil,
            sender: senderPerson,
            attachments: nil
        )
        
        // Set the intent as the sender for incoming message simulation
        intent.setImage(nil, forParameterNamed: \.sender)
        
        // Create interaction for the intent
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming
        
        interaction.donate { error in
            if let error = error {
                print("[LocalNotification] Intent donation error: \(error)")
            } else {
                print("[LocalNotification] Intent donated successfully")
            }
        }
        
        // Update the notification content with the intent
        do {
            let updatedContent = try content.updating(from: intent)
            
            // Schedule for immediate delivery (1 second delay)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            
            let identifier = "sms-\(UUID().uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: updatedContent, trigger: trigger)
            
            center.add(request) { error in
                if let error = error {
                    print("[LocalNotification] Failed to schedule: \(error)")
                    completion(false)
                } else {
                    print("[LocalNotification] Scheduled Communication Notification: \(identifier)")
                    completion(true)
                }
            }
        } catch {
            print("[LocalNotification] Failed to update content with intent: \(error)")
            // Fallback to regular notification
            self.scheduleFallbackNotification(content: content, completion: completion)
        }
    }
    
    /// Fallback to regular notification if Communication Notification fails
    private func scheduleFallbackNotification(content: UNMutableNotificationContent, completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let identifier = "sms-fallback-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("[LocalNotification] Fallback also failed: \(error)")
                completion(false)
            } else {
                print("[LocalNotification] Fallback notification scheduled: \(identifier)")
                completion(true)
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("[LocalNotification] Will present notification in foreground")
        completionHandler([.banner, .sound, .badge, .list])
    }
    
    // Handle notification taps
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("[LocalNotification] Notification tapped: \(userInfo)")
        completionHandler()
    }
}
