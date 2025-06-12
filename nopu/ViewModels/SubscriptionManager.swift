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
    
    private let databaseManager = DatabaseManager.shared
    
    init() {
        loadSubscriptions()
    }
    
    private func loadSubscriptions() {
        let entities = databaseManager.fetchSubscriptions()
        self.subscriptions = entities.map { databaseManager.convertToSubscription($0) }
    }
    

    
    func addSubscription(_ subscription: Subscription) {
        databaseManager.addSubscription(subscription)
        loadSubscriptions() // Reload to update UI
    }
    
    func removeSubscription(id: UUID) {
        databaseManager.deleteSubscription(id: id)
        loadSubscriptions() // Reload to update UI
    }
    
    func updateSubscription(_ subscription: Subscription) {
        databaseManager.updateSubscription(subscription)
        loadSubscriptions() // Reload to update UI
    }
    
    func markAsRead(id: UUID) {
        databaseManager.markSubscriptionAsRead(id: id)
        loadSubscriptions() // Reload to update UI
    }
    
    func addNotificationToTopic(topicName: String, message: String, type: NotificationType = .general) {
        databaseManager.addNotificationToSubscription(topicName: topicName, message: message, type: type)
        loadSubscriptions() // Reload to update UI
    }
    
    var totalUnreadCount: Int {
        subscriptions.reduce(0) { $0 + $1.unreadCount }
    }
} 