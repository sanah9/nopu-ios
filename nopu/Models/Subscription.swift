//
//  Subscription.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import Foundation

struct Subscription: Identifiable, Codable {
    let id: UUID
    let topicName: String
    let groupId: String
    let createdAt: Date
    var lastNotificationAt: Date?
    var unreadCount: Int
    var latestMessage: String?
    var isActive: Bool
    let serverURL: String
    var notifications: [NotificationItem]
    
    // Add CodingKeys to handle id field
    enum CodingKeys: String, CodingKey {
        case id, topicName, groupId, createdAt, lastNotificationAt, unreadCount, latestMessage, isActive, serverURL, notifications
    }
    
    // Custom init(from decoder:) to handle legacy data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode id, generate new UUID if failed
        if let decodedId = try? container.decode(UUID.self, forKey: .id) {
            self.id = decodedId
        } else {
            self.id = UUID()
        }
        
        self.topicName = try container.decode(String.self, forKey: .topicName)
        self.groupId = try container.decode(String.self, forKey: .groupId)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.lastNotificationAt = try container.decodeIfPresent(Date.self, forKey: .lastNotificationAt)
        self.unreadCount = try container.decode(Int.self, forKey: .unreadCount)
        self.latestMessage = try container.decodeIfPresent(String.self, forKey: .latestMessage)
        self.isActive = try container.decode(Bool.self, forKey: .isActive)
        self.serverURL = try container.decode(String.self, forKey: .serverURL)
        self.notifications = try container.decode([NotificationItem].self, forKey: .notifications)
    }
    
    // Initializer for database restoration
    init(id: UUID, topicName: String, groupId: String, createdAt: Date, lastNotificationAt: Date? = nil, unreadCount: Int = 0, latestMessage: String? = nil, isActive: Bool = true, serverURL: String, notifications: [NotificationItem] = []) {
        self.id = id
        self.topicName = topicName
        self.groupId = groupId
        self.createdAt = createdAt
        self.lastNotificationAt = lastNotificationAt
        self.unreadCount = unreadCount
        self.latestMessage = latestMessage
        self.isActive = isActive
        self.serverURL = serverURL
        self.notifications = notifications
    }
    
    // Convenience initializer (maintain backward compatibility)
    init(topicName: String, groupId: String, serverURL: String) {
        self.id = UUID()
        self.topicName = topicName
        self.groupId = groupId
        self.createdAt = Date()
        self.lastNotificationAt = nil
        self.unreadCount = 0
        self.latestMessage = nil
        self.isActive = true
        self.serverURL = serverURL
        self.notifications = []
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