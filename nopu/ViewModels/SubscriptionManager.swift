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
            var notification1 = NotificationItem(message: "Alice liked your post", type: .like)
            notification1.eventJSON = """
            {
              "id": "4376c65d2f232afbe9b882a35baa4f6fe8667c4e684749af565f981833ed6a65",
              "pubkey": "6e468422dfb74a5738702a8823b9b28168abab8655faacb6853cd0ee15deee93",
              "created_at": 1673347337,
              "kind": 7,
              "tags": [
                ["e", "2f230e18e4e42d017515d9b346c4262a75c8a3bc4eaceacfa9ed9f7644a8aa3d"],
                ["p", "97c70a44366a6535c145b333f973ea86dfdc2d7a99da618c40c64705ad98e322"]
              ],
              "content": "+",
              "sig": "b4a3c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2"
            }
            """
            notification1.relayURL = "wss://relay.damus.io"
            notification1.authorPubkey = "6e468422dfb74a5738702a8823b9b28168abab8655faacb6853cd0ee15deee93"
            notification1.eventId = "4376c65d2f232afbe9b882a35baa4f6fe8667c4e684749af565f981833ed6a65"
            notification1.eventKind = 7
            notification1.eventCreatedAt = Date().addingTimeInterval(-3600)
            
            var notification2 = NotificationItem(message: "Bob liked your post", type: .like)
            notification2.eventJSON = """
            {
              "id": "5487d76e3f343bfcfac93a46cbb5f7gf97778d5f795859bg676g092944fe7b76",
              "pubkey": "7f579533egc85b6849813b934c9c39279bcdcb766gbdcdcb964de0f26755ef04",
              "created_at": 1673347387,
              "kind": 7,
              "tags": [
                ["e", "2f230e18e4e42d017515d9b346c4262a75c8a3bc4eaceacfa9ed9f7644a8aa3d"],
                ["p", "97c70a44366a6535c145b333f973ea86dfdc2d7a99da618c40c64705ad98e322"]
              ],
              "content": "💜",
              "sig": "c5b4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t1u2v3w4x5y6z7a8b9c0d1e2f3g4"
            }
            """
            notification2.relayURL = "wss://nos.lol"
            notification2.authorPubkey = "7f579533egc85b6849813b934c9c39279bcdcb766gbdcdcb964de0f26755ef04"
            notification2.eventId = "5487d76e3f343bfcfac93a46cbb5f7gf97778d5f795859bg676g092944fe7b76"
            notification2.eventKind = 7
            notification2.eventCreatedAt = Date().addingTimeInterval(-3500)
            
            var notification3 = NotificationItem(message: "Charlie liked your post", type: .like)
            notification3.eventJSON = """
            {
              "id": "6598e87f4g454cgdgbd04b57dcc6g8hg08889e6g806960ch787h103055gf8c87",
              "pubkey": "8g680644fhd96c7950924c045d0d40380cdedd877hcedd075ef1g37866fg15",
              "created_at": 1673347437,
              "kind": 7,
              "tags": [
                ["e", "2f230e18e4e42d017515d9b346c4262a75c8a3bc4eaceacfa9ed9f7644a8aa3d"],
                ["p", "97c70a44366a6535c145b333f973ea86dfdc2d7a99da618c40c64705ad98e322"]
              ],
              "content": "🔥",
              "sig": "d6c5e6f7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2g3h4i5"
            }
            """
            notification3.relayURL = "wss://relay.snort.social"
            notification3.authorPubkey = "8g680644fhd96c7950924c045d0d40380cdedd877hcedd075ef1g37866fg15"
            notification3.eventId = "6598e87f4g454cgdgbd04b57dcc6g8hg08889e6g806960ch787h103055gf8c87"
            notification3.eventKind = 7
            notification3.eventCreatedAt = Date().addingTimeInterval(-3400)
            
            sampleSubscription1.notifications = [notification1, notification2, notification3]
            // Set first two as unread
            sampleSubscription1.notifications[0].isRead = false
            sampleSubscription1.notifications[1].isRead = false
            sampleSubscription1.notifications[2].isRead = true
            sampleSubscription1.unreadCount = 2
            sampleSubscription1.latestMessage = "Alice liked your post"
            sampleSubscription1.lastNotificationAt = Date().addingTimeInterval(-3600) // 1 hour ago
            
            var sampleSubscription2 = Subscription(topicName: "Important Reply Alerts")
            var replyNotification1 = NotificationItem(message: "David replied to your post: \"Very interesting point!\"", type: .reply)
            replyNotification1.eventJSON = """
            {
              "id": "7709f98g5h565dhehed15c68edd7h9ih19990f7h917071di898i214166hg9d98",
              "pubkey": "9h791755gieu07d061035d156e1e51491deedd988ieedd186fg2h48977gh26",
              "created_at": 1673349000,
              "kind": 1,
              "tags": [
                ["e", "2f230e18e4e42d017515d9b346c4262a75c8a3bc4eaceacfa9ed9f7644a8aa3d", "", "root"],
                ["e", "abc123def456ghi789jkl012mno345pqr678stu901vwx234yzb567cde890fgh123", "", "reply"],
                ["p", "97c70a44366a6535c145b333f973ea86dfdc2d7a99da618c40c64705ad98e322"]
              ],
              "content": "Very interesting point! I hadn't considered that perspective before. Thanks for sharing your thoughts on this topic.",
              "sig": "e7d6f7g8j9k0l1m2n3o4p5q6r7s8t9u0v1w2x3y4z5a6b7c8d9e0f1g2h3i4j5k6"
            }
            """
            replyNotification1.relayURL = "wss://relay.damus.io"
            replyNotification1.authorPubkey = "9h791755gieu07d061035d156e1e51491deedd988ieedd186fg2h48977gh26"
            replyNotification1.eventId = "7709f98g5h565dhehed15c68edd7h9ih19990f7h917071di898i214166hg9d98"
            replyNotification1.eventKind = 1
            replyNotification1.eventCreatedAt = Date().addingTimeInterval(-1800)
            
            var replyNotification2 = NotificationItem(message: "Eva replied to your post: \"I agree with your view\"", type: .reply)
            replyNotification2.eventJSON = """
            {
              "id": "881ag09h6i676eifife26d79fee8i0ji20aa1g8i028182ej909j325277ih0ea9",
              "pubkey": "ai802866hjfv18e172146e267f2f62502effee099jffee297gh3i59088hi37",
              "created_at": 1673349200,
              "kind": 1,
              "tags": [
                ["e", "2f230e18e4e42d017515d9b346c4262a75c8a3bc4eaceacfa9ed9f7644a8aa3d", "", "root"],
                ["p", "97c70a44366a6535c145b333f973ea86dfdc2d7a99da618c40c64705ad98e322"]
              ],
              "content": "I agree with your view completely. This is exactly what I was thinking about earlier today.",
              "sig": "f8e7g8h9k0l1m2n3o4p5q6r7s8t9u0v1w2x3y4z5a6b7c8d9e0f1g2h3i4j5k6l7"
            }
            """
            replyNotification2.relayURL = "wss://nostr.wine"
            replyNotification2.authorPubkey = "ai802866hjfv18e172146e267f2f62502effee099jffee297gh3i59088hi37"
            replyNotification2.eventId = "881ag09h6i676eifife26d79fee8i0ji20aa1g8i028182ej909j325277ih0ea9"
            replyNotification2.eventKind = 1
            replyNotification2.eventCreatedAt = Date().addingTimeInterval(-2000)
            
            sampleSubscription2.notifications = [replyNotification1, replyNotification2]
            sampleSubscription2.notifications[0].isRead = false
            sampleSubscription2.notifications[1].isRead = true
            sampleSubscription2.unreadCount = 1
            sampleSubscription2.latestMessage = "David replied to your post: \"Very interesting point!\""
            sampleSubscription2.lastNotificationAt = Date().addingTimeInterval(-1800) // 30 minutes ago
            
            var sampleSubscription3 = Subscription(topicName: "Zap Notifications")
            var zapNotification1 = NotificationItem(message: "Frank sent you 1000 sats", type: .zap)
            zapNotification1.eventJSON = """
            {
              "id": "992bh10i7j787fjgjgf37e80gff9j1kj31bb2h9j139293fk010k436388ji1fb0",
              "pubkey": "bj913977ikgw29f283257f378g3g73613fggff100kggff308hi4j601099ij48",
              "created_at": 1673351000,
              "kind": 9735,
              "tags": [
                ["e", "2f230e18e4e42d017515d9b346c4262a75c8a3bc4eaceacfa9ed9f7644a8aa3d"],
                ["p", "97c70a44366a6535c145b333f973ea86dfdc2d7a99da618c40c64705ad98e322"],
                ["amount", "1000000"],
                ["lnurl", "LNURL1DP68GURN8GHJ7UM9WFMXJCM99E3K7MF0V9CXJ0M385EKVCENXC6R2C35XVUKXEF..."]
              ],
              "content": "Great post! Keep up the good work 🚀",
              "sig": "g9f8h9i0l1m2n3o4p5q6r7s8t9u0v1w2x3y4z5a6b7c8d9e0f1g2h3i4j5k6l7m8"
            }
            """
            zapNotification1.relayURL = "wss://relay.damus.io"
            zapNotification1.authorPubkey = "bj913977ikgw29f283257f378g3g73613fggff100kggff308hi4j601099ij48"
            zapNotification1.eventId = "992bh10i7j787fjgjgf37e80gff9j1kj31bb2h9j139293fk010k436388ji1fb0"
            zapNotification1.eventKind = 9735
            zapNotification1.eventCreatedAt = Date().addingTimeInterval(-7200)
            
            var zapNotification2 = NotificationItem(message: "Grace sent you 500 sats", type: .zap)
            zapNotification2.eventJSON = """
            {
              "id": "aa3ci21j8k898gkgkgh48f91hgg0k2lk42cc3i0k240404gl121l547499kj2gc1",
              "pubkey": "ck024088jlhx30g394368g489h4h84724ghhhg211lhhhg419ij5k712100jk59",
              "created_at": 1673351200,
              "kind": 9735,
              "tags": [
                ["e", "2f230e18e4e42d017515d9b346c4262a75c8a3bc4eaceacfa9ed9f7644a8aa3d"],
                ["p", "97c70a44366a6535c145b333f973ea86dfdc2d7a99da618c40c64705ad98e322"],
                ["amount", "500000"],
                ["lnurl", "LNURL1DP68GURN8GHJ7UM9WFMXJCM99E3K7MF0V9CXJ0M385EKVCENXC6R2C35XVUKXEF..."]
              ],
              "content": "Thanks for sharing! 💜⚡",
              "sig": "h0g9i0j1m2n3o4p5q6r7s8t9u0v1w2x3y4z5a6b7c8d9e0f1g2h3i4j5k6l7m8n9"
            }
            """
            zapNotification2.relayURL = "wss://nos.lol"
            zapNotification2.authorPubkey = "ck024088jlhx30g394368g489h4h84724ghhhg211lhhhg419ij5k712100jk59"
            zapNotification2.eventId = "aa3ci21j8k898gkgkgh48f91hgg0k2lk42cc3i0k240404gl121l547499kj2gc1"
            zapNotification2.eventKind = 9735
            zapNotification2.eventCreatedAt = Date().addingTimeInterval(-7400)
            
            sampleSubscription3.notifications = [zapNotification1, zapNotification2]
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