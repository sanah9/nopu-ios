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
    var createdAt: Date
    var lastNotificationAt: Date?
    var unreadCount: Int
    var latestMessage: String?
    var isActive: Bool
    var serverURL: String?
    
    // CodingKeys to exclude 'id' from encoding/decoding since it has a default value
    private enum CodingKeys: String, CodingKey {
        case topicName, createdAt, lastNotificationAt, unreadCount, latestMessage, isActive, serverURL
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
    
    init(topicName: String, serverURL: String? = nil) {
        self.topicName = topicName
        self.createdAt = Date()
        self.lastNotificationAt = nil
        self.unreadCount = 0
        self.latestMessage = nil
        self.isActive = true
        self.serverURL = serverURL
    }
    
    mutating func addNotification(message: String) {
        self.unreadCount += 1
        self.latestMessage = message
        self.lastNotificationAt = Date()
    }
    
    mutating func markAsRead() {
        self.unreadCount = 0
    }
} 