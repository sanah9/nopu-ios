//
//  Subscription.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import Foundation

struct Subscription: Identifiable, Codable {
    let id = UUID()
    var topicName: String
    var groupId: String? // NIP-29 group ID
    var createdAt: Date
    var lastNotificationAt: Date?
    var unreadCount: Int
    var latestMessage: String?
    var isActive: Bool
    var serverURL: String?
    var notifications: [NotificationItem] = []
    
    // CodingKeys to exclude 'id' from encoding/decoding since it has a default value
    private enum CodingKeys: String, CodingKey {
        case topicName, groupId, createdAt, lastNotificationAt, unreadCount, latestMessage, isActive, serverURL, notifications
    }
    
    // Nostr filter information for display
    var filterSummary: String {
        // This will be used to show what kind of notifications this subscription monitors
        var parts: [String] = []
        
        if topicName.lowercased().contains("like") {
            parts.append("Likes")
        }
        if topicName.lowercased().contains("repost") {
            parts.append("Reposts")
        }
        if topicName.lowercased().contains("reply") {
            parts.append("Replies")
        }
        if topicName.lowercased().contains("zap") {
            parts.append("Zaps")
        }
        if topicName.lowercased().contains("dm") || topicName.lowercased().contains("message") {
            parts.append("Messages")
        }
        
        if parts.isEmpty {
            return "Custom notifications"
        }
        
        return parts.joined(separator: ", ")
    }
    
    init(topicName: String, serverURL: String? = nil, groupId: String? = nil) {
        self.topicName = topicName
        self.groupId = groupId
        self.createdAt = Date()
        self.lastNotificationAt = nil
        self.unreadCount = 0
        self.latestMessage = nil
        self.isActive = true
        self.serverURL = serverURL
    }
    
    mutating func addNotification(message: String, type: NotificationType = .general) {
        let newNotification = NotificationItem(message: message, type: type)
        self.notifications.insert(newNotification, at: 0) // Insert at the beginning, newest first
        self.unreadCount += 1
        self.latestMessage = message
        self.lastNotificationAt = Date()
        
        // Limit notification history count to avoid excessive data
        if self.notifications.count > 100 {
            self.notifications = Array(self.notifications.prefix(100))
        }
    }
    
    mutating func markAsRead() {
        self.unreadCount = 0
        // Mark all notifications as read
        for i in notifications.indices {
            notifications[i].isRead = true
        }
    }
} 