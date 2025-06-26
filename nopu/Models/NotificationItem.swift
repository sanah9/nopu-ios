//
//  NotificationItem.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import Foundation

struct NotificationItem: Identifiable, Codable {
    let id: UUID
    var message: String
    let receivedAt: Date
    var isRead: Bool
    let type: NotificationType
    let eventJSON: String?
    let relayURL: String?
    let authorPubkey: String?
    let eventId: String?
    let eventKind: Int?
    let eventCreatedAt: Date?
    
    // Add CodingKeys to handle id field
    enum CodingKeys: String, CodingKey {
        case id, message, receivedAt, isRead, type, eventJSON, relayURL, authorPubkey, eventId, eventKind, eventCreatedAt
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
        
        self.message = try container.decode(String.self, forKey: .message)
        self.receivedAt = try container.decode(Date.self, forKey: .receivedAt)
        self.isRead = try container.decode(Bool.self, forKey: .isRead)
        self.type = try container.decode(NotificationType.self, forKey: .type)
        self.eventJSON = try container.decodeIfPresent(String.self, forKey: .eventJSON)
        self.relayURL = try container.decodeIfPresent(String.self, forKey: .relayURL)
        self.authorPubkey = try container.decodeIfPresent(String.self, forKey: .authorPubkey)
        self.eventId = try container.decodeIfPresent(String.self, forKey: .eventId)
        self.eventKind = try container.decodeIfPresent(Int.self, forKey: .eventKind)
        self.eventCreatedAt = try container.decodeIfPresent(Date.self, forKey: .eventCreatedAt)
    }
    
    // Initializer for database restoration
    init(id: UUID, message: String, receivedAt: Date, isRead: Bool, type: NotificationType, eventJSON: String? = nil, relayURL: String? = nil, authorPubkey: String? = nil, eventId: String? = nil, eventKind: Int? = nil, eventCreatedAt: Date? = nil) {
        self.id = id
        self.message = message
        self.receivedAt = receivedAt
        self.isRead = isRead
        self.type = type
        self.eventJSON = eventJSON
        self.relayURL = relayURL
        self.authorPubkey = authorPubkey
        self.eventId = eventId
        self.eventKind = eventKind
        self.eventCreatedAt = eventCreatedAt
    }
    
    // Convenience initializer (maintain backward compatibility)
    init(message: String, type: NotificationType = .general, eventJSON: String? = nil, relayURL: String? = nil, authorPubkey: String? = nil, eventId: String? = nil, eventKind: Int? = nil, eventCreatedAt: Date? = nil) {
        self.id = UUID()
        self.message = message
        self.receivedAt = Date()
        self.isRead = false
        self.type = type
        self.eventJSON = eventJSON
        self.relayURL = relayURL
        self.authorPubkey = authorPubkey
        self.eventId = eventId
        self.eventKind = eventKind
        self.eventCreatedAt = eventCreatedAt
    }
}

enum NotificationType: String, Codable, CaseIterable {
    case general = "general"
    case repost = "repost"
    case mention = "mention"
    case dm = "dm"
    case reaction = "reaction"
    case zap = "zap"
    case follow = "follow"
    case text = "text"
    
    var displayName: String {
        switch self {
        case .general:
            return "Notification"
        case .repost:
            return "Repost"
        case .mention:
            return "Mention"
        case .dm:
            return "DM"
        case .reaction:
            return "Reaction"
        case .zap:
            return "Zap"
        case .follow:
            return "Follow"
        case .text:
            return "Text"
        }
    }
    
    var iconName: String {
        switch self {
        case .general:
            return "bell.fill"
        case .repost:
            return "arrow.2.squarepath"
        case .mention:
            return "at.fill"
        case .dm:
            return "message.fill"
        case .reaction:
            return "hand.thumbsup.fill"
        case .zap:
            return "bolt.fill"
        case .follow:
            return "person.fill.badge.plus"
        case .text:
            return "text.fill"
        }
    }
    
    var color: String {
        switch self {
        case .general:
            return "gray"
        case .repost:
            return "green"
        case .mention:
            return "pink"
        case .dm:
            return "purple"
        case .reaction:
            return "orange"
        case .zap:
            return "yellow"
        case .follow:
            return "teal"
        case .text:
            return "brown"
        }
    }
} 