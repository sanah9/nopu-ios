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
    
    func addNotificationToTopic(topicName: String, message: String) {
        if let index = subscriptions.firstIndex(where: { $0.topicName == topicName }) {
            subscriptions[index].addNotification(message: message)
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
            sampleSubscription1.unreadCount = 3
            sampleSubscription1.latestMessage = "Someone liked your post"
            sampleSubscription1.lastNotificationAt = Date().addingTimeInterval(-3600) // 1 hour ago
            
            var sampleSubscription2 = Subscription(topicName: "Important Reply Alerts")
            sampleSubscription2.unreadCount = 1
            sampleSubscription2.latestMessage = "Received a new reply"
            sampleSubscription2.lastNotificationAt = Date().addingTimeInterval(-1800) // 30 minutes ago
            
            var sampleSubscription3 = Subscription(topicName: "Zap Notifications")
            sampleSubscription3.unreadCount = 0
            sampleSubscription3.latestMessage = "Received a new Zap"
            sampleSubscription3.lastNotificationAt = Date().addingTimeInterval(-7200) // 2 hours ago
            
            subscriptions = [sampleSubscription1, sampleSubscription2, sampleSubscription3]
            saveSubscriptions()
        }
    }
} 