//
//  SubscriptionManager.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import Foundation
import SwiftUI

class SubscriptionManager: ObservableObject {
    @Published var subscriptions: [Subscription] = []
    
    private let userDefaultsKey = "SavedSubscriptions"
    
    init() {
        loadSubscriptions()
        // Add some sample data for demonstration
        addSampleDataIfEmpty()
    }
    
    private func loadSubscriptions() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decodedSubscriptions = try? JSONDecoder().decode([Subscription].self, from: data) {
            self.subscriptions = decodedSubscriptions
        }
    }
    
    private func saveSubscriptions() {
        if let encodedData = try? JSONEncoder().encode(subscriptions) {
            UserDefaults.standard.set(encodedData, forKey: userDefaultsKey)
        }
    }
    
    func addSubscription(_ subscription: Subscription) {
        subscriptions.append(subscription)
        saveSubscriptions()
    }
    
    func removeSubscription(id: UUID) {
        subscriptions.removeAll { $0.id == id }
        saveSubscriptions()
    }
    
    func updateSubscription(_ subscription: Subscription) {
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            subscriptions[index] = subscription
            saveSubscriptions()
        }
    }
    
    func markAsRead(id: UUID) {
        if let index = subscriptions.firstIndex(where: { $0.id == id }) {
            subscriptions[index].markAsRead()
            saveSubscriptions()
        }
    }
    
    func addNotificationToTopic(topicName: String, message: String, type: NotificationType = .general) {
        if let index = subscriptions.firstIndex(where: { $0.topicName == topicName }) {
            subscriptions[index].addNotification(message: message, type: type)
            saveSubscriptions()
        }
    }
    
    var totalUnreadCount: Int {
        subscriptions.reduce(0) { $0 + $1.unreadCount }
    }
    
    // Add sample data for demonstration
    private func addSampleDataIfEmpty() {
        if subscriptions.isEmpty {
            var sampleSubscription1 = Subscription(topicName: "My Like Notifications")
            // Add some sample notifications
            sampleSubscription1.notifications = [
                NotificationItem(message: "Alice liked your post", type: .like),
                NotificationItem(message: "Bob liked your post", type: .like),
                NotificationItem(message: "Charlie liked your post", type: .like)
            ]
            // Set first two as unread
            sampleSubscription1.notifications[0].isRead = false
            sampleSubscription1.notifications[1].isRead = false
            sampleSubscription1.notifications[2].isRead = true
            sampleSubscription1.unreadCount = 2
            sampleSubscription1.latestMessage = "Alice liked your post"
            sampleSubscription1.lastNotificationAt = Date().addingTimeInterval(-3600) // 1 hour ago
            
            var sampleSubscription2 = Subscription(topicName: "Important Reply Alerts")
            sampleSubscription2.notifications = [
                NotificationItem(message: "David replied to your post: \"Very interesting point!\"", type: .reply),
                NotificationItem(message: "Eva replied to your post: \"I agree with your view\"", type: .reply)
            ]
            sampleSubscription2.notifications[0].isRead = false
            sampleSubscription2.notifications[1].isRead = true
            sampleSubscription2.unreadCount = 1
            sampleSubscription2.latestMessage = "David replied to your post: \"Very interesting point!\""
            sampleSubscription2.lastNotificationAt = Date().addingTimeInterval(-1800) // 30 minutes ago
            
            var sampleSubscription3 = Subscription(topicName: "Zap Notifications")
            sampleSubscription3.notifications = [
                NotificationItem(message: "Frank sent you 1000 sats", type: .zap),
                NotificationItem(message: "Grace sent you 500 sats", type: .zap)
            ]
            sampleSubscription3.notifications[0].isRead = true
            sampleSubscription3.notifications[1].isRead = true
            sampleSubscription3.unreadCount = 0
            sampleSubscription3.latestMessage = "Frank sent you 1000 sats"
            sampleSubscription3.lastNotificationAt = Date().addingTimeInterval(-7200) // 2 hours ago
            
            subscriptions = [sampleSubscription1, sampleSubscription2, sampleSubscription3]
            saveSubscriptions()
        }
    }
} 