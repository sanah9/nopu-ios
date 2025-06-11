//
//  NotificationItem.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import Foundation

struct NotificationItem: Identifiable, Codable {
    let id = UUID()
    var message: String
    var receivedAt: Date
    var isRead: Bool
    var type: NotificationType
    var eventJSON: String?
    var relayURL: String?
    var authorPubkey: String?
    var eventId: String?
    var eventKind: Int?
    var eventCreatedAt: Date?
    
    // CodingKeys to exclude 'id' from encoding/decoding since it has a default value
    private enum CodingKeys: String, CodingKey {
        case message, receivedAt, isRead, type, eventJSON, relayURL, authorPubkey, eventId, eventKind, eventCreatedAt
    }
    
    init(message: String, type: NotificationType = .general) {
        self.message = message
        self.receivedAt = Date()
        self.isRead = false
        self.type = type
    }
}

enum NotificationType: String, Codable, CaseIterable {
    case like = "like"
    case repost = "repost"
    case reply = "reply"
    case zap = "zap"
    case directMessage = "dm"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .like:
            return "Like"
        case .repost:
            return "Repost"
        case .reply:
            return "Reply"
        case .zap:
            return "Zap"
        case .directMessage:
            return "DM"
        case .general:
            return "Notification"
        }
    }
    
    var iconName: String {
        switch self {
        case .like:
            return "heart.fill"
        case .repost:
            return "arrow.2.squarepath"
        case .reply:
            return "arrowshape.turn.up.left.fill"
        case .zap:
            return "bolt.fill"
        case .directMessage:
            return "message.fill"
        case .general:
            return "bell.fill"
        }
    }
    
    var color: String {
        switch self {
        case .like:
            return "red"
        case .repost:
            return "green"
        case .reply:
            return "blue"
        case .zap:
            return "yellow"
        case .directMessage:
            return "purple"
        case .general:
            return "gray"
        }
    }
} 