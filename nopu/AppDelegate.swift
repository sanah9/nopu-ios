import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let databaseManager = DatabaseManager.shared

    // MARK: - UIApplicationDelegate
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 1️⃣ Request push authorization
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else if let error = error {
                print("Push auth error: \(error)")
            }
        }

        // Handle launch from push notification
        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            handlePushPayload(userInfo)
        }

        // Load previously saved device token (if any) into memory
        _ = PushTokenManager.shared // initialize
        
        // Initialize UserProfileManager to cleanup expired cache
        _ = UserProfileManager.shared // initialize
        
        // set badge number to 0
        UIApplication.shared.applicationIconBadgeNumber = 0

        return true
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        handlePushPayload(userInfo)
        completionHandler(.newData)
    }

    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handlePushPayload(notification.request.content.userInfo)
        // Show system notification while app is in foreground
        completionHandler([.badge, .sound, .banner])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        handlePushPayload(response.notification.request.content.userInfo)
        completionHandler()
    }

    // MARK: - Private helpers
    private func handlePushPayload(_ userInfo: [AnyHashable: Any]) {
        // Event payload missing or invalid; ignore

        // Accept event as Dictionary or JSON String
        var eventDict: [String: Any]?
        if let dict = userInfo["event"] as? [String: Any] {
            eventDict = dict
        } else if let jsonString = userInfo["event"] as? String,
                  let jsonData = jsonString.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            eventDict = parsed
        }

        guard let eventDict = eventDict else {
            return
        }
        let eventId = eventDict["kind"] as? Int ?? 0
        switch eventId {
        case 20284:
            processEvent20284(dict: eventDict)
        default:
            print("Unhandled event id (dict): \(eventId)")
        }
    }

    private func processEvent20284(dict eventDict: [String: Any]) {
        // Parse groupId from "h" tag
        guard let tags = eventDict["tags"] as? [[String]] else { return }
        var groupId: String?
        for tag in tags {
            if tag.count >= 2 && tag[0] == "h" {
                groupId = tag[1]
                break
            }
        }
        guard let groupId = groupId else { return }

        // Inner event content
        guard let eventContent = eventDict["content"] as? String else { return }
        guard let contentData = eventContent.data(using: .utf8),
              let innerEventDict = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] else { return }
        let kind = innerEventDict["kind"] as? Int ?? 1
        let message = NotificationMessageBuilder.message(for: kind, eventData: innerEventDict)

        let item = NotificationItem(
            message: message,
            type: .general,
            eventJSON: eventContent,
            relayURL: nil,
            authorPubkey: innerEventDict["pubkey"] as? String,
            eventId: innerEventDict["id"] as? String,
            eventKind: kind,
            eventCreatedAt: Date()
        )

        // Append to existing subscriptions matching the groupId
        let subscriptions = databaseManager.fetchSubscriptions().filter { $0.groupId == groupId }
        for sub in subscriptions {
            if let subId = sub.id {
                databaseManager.appendNotification(subscriptionId: subId, notification: item)
            }
        }
    }

    // Save device token when successfully registered
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()

        // Update only if the token has changed to avoid redundant UserDefaults writes
        if PushTokenManager.shared.token != tokenString {
            PushTokenManager.shared.token = tokenString
            print("[Push] Saved new APNs device token: \(tokenString)")
        } else {
            print("[Push] APNs device token unchanged")
        }
    }
} 
