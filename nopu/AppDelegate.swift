import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let eventProcessor = EventProcessor.shared
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
        guard let eventString = userInfo["event"] as? String else { return }
        // Example event string: "20284|{...json...}"
        guard let pipeIndex = eventString.firstIndex(of: "|") else { return }
        let idPart = String(eventString[..<pipeIndex])
        guard let eventId = Int(idPart) else { return }

        switch eventId {
        case 20284:
            processEvent20284(fullEventString: eventString)
        default:
            print("Unhandled event id: \(eventId)")
        }
    }

    private func processEvent20284(fullEventString: String) {
        guard let (groupId, eventContent) = eventProcessor.processEvent20284(fullEventString) else { return }
        guard let contentData = eventContent.data(using: .utf8),
              let eventDict = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] else { return }
        let kind = eventDict["kind"] as? Int ?? 1
        let message = NotificationMessageBuilder.message(for: kind, eventData: eventDict)

        let item = NotificationItem(
            message: message,
            type: .general,
            eventJSON: eventContent,
            relayURL: nil,
            authorPubkey: eventDict["pubkey"] as? String,
            eventId: eventDict["id"] as? String,
            eventKind: kind,
            eventCreatedAt: Date()
        )

        // Append notification to subscriptions matching the groupId
        let subscriptions = databaseManager.fetchSubscriptions().filter { $0.groupId == groupId }
        for sub in subscriptions {
            if let subId = sub.id {
                databaseManager.appendNotification(subscriptionId: subId, notification: item)
            }
        }
    }
} 