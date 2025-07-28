//
//  SubscriptionManager.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import Foundation
import SwiftUI

// Server group structure
struct ServerGroup {
    let serverURL: String
    let groupIds: [String]
    var subscriptions: [Subscription] = []
    
    // Generate request format: ["REQ", subscriptionId, filter]
    func generateNostrRequest(subscriptionId: String = UUID().uuidString) -> [Any] {
        // Build h tag filter: filter events containing any of the groupIds
        let filter: [String: Any] = [
            "kinds": [20284, 20285], // NIP-29 group events
            "#h": groupIds,    // h tag contains any of the groupIds
            "since": Int(Date().timeIntervalSince1970 - 3600) // Events from the last hour
        ]
        
        return ["REQ", subscriptionId, filter]
    }
    
    // Generate filter dictionary
    func generateFilterDict() -> [String: Any] {
        return [
            "kinds": [20284, 20285], // NIP-29 group events
            "#h": groupIds,    // h tag contains any of the groupIds
            "since": Int(Date().timeIntervalSince1970 - 3600) // Events from the last hour
        ]
    }
}

class SubscriptionManager: ObservableObject {
    @Published var subscriptions: [Subscription] = []
    @Published var serverGroups: [ServerGroup] = []
    @Published var isAutoConnectEnabled = true
    
    // Error message to display when subscription deletion fails
    @Published var deletionErrorMessage: String? = nil
    
    private let databaseManager = DatabaseManager.shared
    private let multiRelayManager = MultiRelayPoolManager.shared
    private let eventProcessor = EventProcessor.shared
    
    init() {
        loadSubscriptions()
        updateServerGroups()
        configureNostrManagerWithSubscriptionRelays()
        setupAutoConnections()
        
        // Set up NIP-29 event handler
        multiRelayManager.setNIP29EventHandler { [weak self] eventString in
            DispatchQueue.main.async {
                self?.handleNIP29Event(eventString)
            }
        }
        
        // Listen for user profile updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProfileUpdate(_:)),
            name: UserProfileManager.profileUpdatedNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func loadSubscriptions() {
        let entities = databaseManager.fetchSubscriptions()
        self.subscriptions = entities.map { databaseManager.convertToSubscription($0) }
    }
    
    // Extract relay URLs from subscriptions and configure NostrManager
    private func configureNostrManagerWithSubscriptionRelays() {
        // Collect all relay URLs from subscriptions
        var allRelayURLs = Set<String>()
        
        for subscription in subscriptions {
            for relayURL in subscription.filters.relays {
                if !relayURL.isEmpty && NostrManager.shared.isValidWebSocketURL(relayURL) {
                    allRelayURLs.insert(relayURL)
                }
            }
        }
        
        // If no relay URLs found, fallback to the built-in default relay
        if allRelayURLs.isEmpty {
            let defaultRelay = UserDefaults.standard.string(forKey: "defaultServerURL") ?? AppConfig.defaultServerURL
            allRelayURLs.insert(defaultRelay)
        }
        
        // Add collected relay URLs to NostrManager
        for relayURL in allRelayURLs {
            NostrManager.shared.addRelay(url: relayURL)
        }
        
        // Connect if relays are available
        NostrManager.shared.connectIfRelaysAvailable()
        

    }
    
    // Group subscriptions by serverURL
    private func updateServerGroups() {
        var groupsDict: [String: [String]] = [:]
        var subscriptionsDict: [String: [Subscription]] = [:]
        
        for subscription in subscriptions {
            let serverURL = subscription.serverURL.isEmpty ? "default" : subscription.serverURL
            
            // Collect groupId
            if groupsDict[serverURL] == nil {
                groupsDict[serverURL] = []
                subscriptionsDict[serverURL] = []
            }
            groupsDict[serverURL]?.append(subscription.groupId)
            subscriptionsDict[serverURL]?.append(subscription)
        }
        
        // Create ServerGroup objects
        self.serverGroups = groupsDict.map { serverURL, groupIds in
            var group = ServerGroup(
                serverURL: serverURL,
                groupIds: groupIds
            )
            group.subscriptions = subscriptionsDict[serverURL] ?? []
            return group
        }
    }
    
    // Setup auto connections and subscriptions
    private func setupAutoConnections() {
        guard isAutoConnectEnabled else { return }

        // ⚠️ Iterate through each subscription individually, instead of by ServerGroup
        for subscription in subscriptions {
            let serverURL = subscription.serverURL.isEmpty ? "default" : subscription.serverURL
            let relayURLs = subscription.filters.relays

            // Create or reuse ServerConnection
            let defaultRelay = UserDefaults.standard.string(forKey: "defaultServerURL") ?? AppConfig.defaultServerURL
            let serverConnection = multiRelayManager.getOrCreateServerConnection(
                serverURL: serverURL,
                relayURLs: relayURLs.isEmpty ? [defaultRelay] : relayURLs
            )

            if serverConnection.connectionState == .disconnected {
                serverConnection.connect()
            }

            // Use stable and predictable subscriptionId for easier unsubscribe later
            let subscriptionId = "sub_\(subscription.groupId)"

            // Build filter to only subscribe to the current subscription's groupId
            let filter: [String: Any] = [
                "kinds": [20284, 20285],
                "#h": [subscription.groupId],
                "since": Int(Date().timeIntervalSince1970 - 3600)
            ]

            _ = multiRelayManager.subscribe(
                serverURL: serverURL,
                subscriptionId: subscriptionId,
                filter: filter
            )
        }
    }
    
    // Reconnect all servers
    func reconnectAllServers() {
        multiRelayManager.connectAllServers()
        setupAutoConnections()
    }
    
    // Disconnect all servers
    func disconnectAllServers() {
        multiRelayManager.disconnectAllServers()
    }
    
    func addSubscription(_ subscription: Subscription) {
        databaseManager.addSubscription(subscription)
        loadSubscriptions() // Reload to update UI
        updateServerGroups() // Update groups
        
        // If new subscription contains new relay URLs, add to NostrManager
        updateNostrManagerRelays(with: subscription)
        
        // If auto connect is enabled, setup connection for new subscription
        if isAutoConnectEnabled {
            setupConnectionsForNewSubscription(subscription)
        }
    }
    
    func removeSubscription(id: UUID) {
        // Locate the subscription to delete so we can properly unsubscribe and disconnect
        guard let subscription = subscriptions.first(where: { $0.id == id }) else {
            databaseManager.deleteSubscription(id: id)
            loadSubscriptions() // Reload UI even if not found (keep state consistent)
            updateServerGroups()
            return
        }

        // Check if push server is connected before attempting deletion
        if !NostrManager.shared.isConnected {
            self.deletionErrorMessage = "Cannot delete group: Push server not connected. Please check your network connection and try again."
            return
        }

        // 🚀 Send a kind 9008 event with h tag = groupId before cancelling the subscription
        sendDeleteGroupEvent(groupId: subscription.groupId) { [weak self] success in
            guard let self = self else { return }
            if success {
                // Introduce a slight delay to ensure the relay processes the deletion event
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.performRemoval(subscription: subscription)
                }
            } else {
                self.deletionErrorMessage = "Deletion failed: Unable to send deletion event to the server. Please check your network connection and try again."
            }
        }
    }
    
    private func performRemoval(subscription: Subscription) {
        let id = subscription.id
        // 1️⃣ Unsubscribe from MultiRelayPoolManager first
        let serverURL = subscription.serverURL.isEmpty ? "default" : subscription.serverURL
        let subscriptionId = "sub_\(subscription.groupId)"
        multiRelayManager.unsubscribe(serverURL: serverURL, subscriptionId: subscriptionId)

        // 2️⃣ Remove from the database
        databaseManager.deleteSubscription(id: id)

        // 3️⃣ Update in-memory list and UI
        loadSubscriptions()
        updateServerGroups()

        // 4️⃣ Reconfigure relays (may remove ones no longer needed)
        reconfigureNostrManagerRelays()

        // 5️⃣ If auto-connect is enabled, rebuild/cleanup connections
        if isAutoConnectEnabled {
            setupAutoConnections()
        }
    }
    
    func updateSubscription(_ subscription: Subscription) {
        // Cancel all old connections for this subscription
        let serverURL = subscription.serverURL.isEmpty ? "default" : subscription.serverURL
        let oldSubscriptionId = "sub_\(subscription.groupId)"
        multiRelayManager.unsubscribe(serverURL: serverURL, subscriptionId: oldSubscriptionId)
        
        // Update subscription in database and memory
        databaseManager.updateSubscription(subscription)
        loadSubscriptions() // Reload to update UI
        updateServerGroups() // Update groups
        
        // Update NostrManager relays
        reconfigureNostrManagerRelays()
        
        // Reset connections and create new subscription
        if isAutoConnectEnabled {
            setupAutoConnections()
        }
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
    
    // Get request arrays for specified server
    func getNostrRequestsForServer(_ serverURL: String) -> [[Any]] {
        let targetServer = serverURL.isEmpty ? "default" : serverURL
        return serverGroups
            .filter { $0.serverURL == targetServer }
            .map { $0.generateNostrRequest() }
    }
    
    // Get all server request mappings
    func getAllNostrRequests() -> [String: [[Any]]] {
        var requestsMap: [String: [[Any]]] = [:]
        
        for group in serverGroups {
            let serverURL = group.serverURL
            if requestsMap[serverURL] == nil {
                requestsMap[serverURL] = []
            }
            requestsMap[serverURL]?.append(group.generateNostrRequest())
        }
        
        return requestsMap
    }
    
    // Setup connections for new subscription
    private func setupConnectionsForNewSubscription(_ subscription: Subscription) {
        let serverURL = subscription.serverURL.isEmpty ? "default" : subscription.serverURL
        let relayURLs = subscription.filters.relays
        
        // Create or get server connection
        let defaultRelay = UserDefaults.standard.string(forKey: "defaultServerURL") ?? AppConfig.defaultServerURL
        let serverConnection = multiRelayManager.getOrCreateServerConnection(
            serverURL: serverURL,
            relayURLs: relayURLs.isEmpty ? [defaultRelay] : relayURLs
        )
        
        if serverConnection.connectionState == .disconnected {
            serverConnection.connect()
        }
        
        // Create subscription for single subscription
        let subscriptionId = "sub_\(subscription.groupId)"
        let filter: [String: Any] = [
            "kinds": [20284, 20285],
            "#h": [subscription.groupId],
            "since": Int(Date().timeIntervalSince1970 - 3600)
        ]
        
        let _ = multiRelayManager.subscribe(
            serverURL: serverURL,
            subscriptionId: subscriptionId,
            filter: filter
        )
        

    }
    
    // Update NostrManager relays for new subscription
    private func updateNostrManagerRelays(with subscription: Subscription) {
        for relayURL in subscription.filters.relays {
            if !relayURL.isEmpty && NostrManager.shared.isValidWebSocketURL(relayURL) {
                NostrManager.shared.addRelay(url: relayURL)
            }
        }
        
        // Connect newly added relays
        NostrManager.shared.connectIfRelaysAvailable()
    }
    
    // Reconfigure all NostrManager relays (cleanup and re-add)
    private func reconfigureNostrManagerRelays() {
        // Note: We cannot directly clean NostrManager relays here,
        // because nostr-sdk-ios RelayPool doesn't provide relay removal method
        // So we can only reinitialize NostrManager or accept potentially extra relays
        
        // Collect relay URLs from all current subscriptions
        var currentRelayURLs = Set<String>()
        for subscription in subscriptions {
            for relayURL in subscription.filters.relays {
                if !relayURL.isEmpty && NostrManager.shared.isValidWebSocketURL(relayURL) {
                    currentRelayURLs.insert(relayURL)
                }
            }
        }
        
        // Add potentially missing relays
        for relayURL in currentRelayURLs {
            NostrManager.shared.addRelay(url: relayURL)
        }
        

    }
    
    // Get connection status info
    var connectionStatusSummary: String {
        let total = multiRelayManager.totalConnectionCount
        let connected = multiRelayManager.connectedServersCount
        return "Connected \(connected)/\(total) servers"
    }
    
    // Get all server connection statuses
    var allServerConnections: [String: ServerConnection] {
        return multiRelayManager.serverConnections
    }
    
    // Get notification message based on event kind
    private func getNotificationMessage(for eventKind: Int, eventData: [String: Any]) -> String {
        return NotificationMessageBuilder.message(for: eventKind, eventData: eventData)
    }
    
    // Handle NIP-29 event (20284 and 20285)
    func handleNIP29Event(_ eventString: String) {
        // Parse the incoming event only once to avoid repeated JSON parsing
        guard let (groupId, eventContent) = eventProcessor.processNIP29Event(eventString) else {
            return
        }

        // Convert JSON string into dictionary for reuse
        guard let contentData = eventContent.data(using: .utf8),
              let eventDict = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            return
        }

        let eventKind = eventDict["kind"] as? Int ?? 1

        // Find corresponding subscription
        guard let subscription = subscriptions.first(where: { $0.groupId == groupId }) else {
            return
        }

        // Create notification with initial message (may use pubkey prefix)
        let initialMessage = getNotificationMessage(for: eventKind, eventData: eventDict)
        
        let notification = NotificationItem(
            message: initialMessage,
            type: .general,
            eventJSON: eventContent,
            authorPubkey: eventDict["pubkey"] as? String,
            eventId: eventDict["id"] as? String,
            eventKind: eventKind,
            eventCreatedAt: Date()
        )
        
        // Update subscription immediately with initial message
        var updatedSubscription = subscription
        updatedSubscription.notifications.insert(notification, at: 0)
        updatedSubscription.unreadCount += 1
        updatedSubscription.lastNotificationAt = Date()
        updatedSubscription.latestMessage = notification.message
        
        // Perform database write on the main thread to avoid Core Data concurrency issues
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Append notification in Core Data (cheaper than full update)
            self.databaseManager.appendNotification(subscriptionId: updatedSubscription.id, notification: notification)

            if let idx = self.subscriptions.firstIndex(where: { $0.id == updatedSubscription.id }) {
                self.subscriptions[idx] = updatedSubscription
                self.updateServerGroups()
            }
        }
        
        // Try to get updated message with real username async
        NotificationMessageBuilder.messageAsync(for: eventKind, eventData: eventDict) { [weak self] updatedMessage in
            guard let self = self else { return }
            
            // Only update if the message actually changed (got real username)
            if updatedMessage != initialMessage {
                DispatchQueue.main.async {
                    // Find the subscription and notification to update
                    if let subIdx = self.subscriptions.firstIndex(where: { $0.groupId == groupId }),
                       let notificationIdx = self.subscriptions[subIdx].notifications.firstIndex(where: { $0.id == notification.id }) {
                        
                        // Update the notification message
                        var updatedNotification = self.subscriptions[subIdx].notifications[notificationIdx]
                        updatedNotification.message = updatedMessage
                        self.subscriptions[subIdx].notifications[notificationIdx] = updatedNotification
                        
                        // Update latest message if this is the most recent notification
                        if notificationIdx == 0 {
                            self.subscriptions[subIdx].latestMessage = updatedMessage
                        }
                        
                        // Update database
                        self.databaseManager.updateNotificationMessage(
                            notificationId: notification.id,
                            newMessage: updatedMessage
                        )
                        
                        self.updateServerGroups()
                    }
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    private func sendDeleteGroupEvent(groupId: String, completion: @escaping (Bool) -> Void) {
        let deletionTags = [["h", groupId]]
        
        // Double-check connection status before sending event
        guard NostrManager.shared.isConnected else {
            completion(false)
            return
        }
        
        // Ensure there is at least one relay; if none, add the default relay
        if NostrManager.shared.activeRelays.isEmpty {
            let defaultRelay = UserDefaults.standard.string(forKey: "defaultServerURL") ?? AppConfig.defaultServerURL
            if NostrManager.shared.isValidWebSocketURL(defaultRelay) {
                NostrManager.shared.addRelay(url: defaultRelay)
            }
        }
        
        // Send the deletion event
        let eventId = NostrManager.shared.publishEvent(kind: 9008, content: "", tags: deletionTags)
        completion(eventId != nil)
    }
    
    @objc private func handleProfileUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let updatedPubkey = userInfo["pubkey"] as? String,
              let profile = userInfo["profile"] as? UserProfile else {
            return
        }
        
        // Find notifications that need to be updated
        var hasUpdates = false
        
        for (subIdx, subscription) in subscriptions.enumerated() {
            for (notifIdx, notificationItem) in subscription.notifications.enumerated() {
                // Check if this notification involves the updated user
                var shouldUpdate = false
                var relevantPubkey: String? = nil
                
                // For different event kinds, check different pubkey sources
                switch notificationItem.eventKind ?? 1 {
                case 9735: // Zap - check P tag for sender
                    if let eventJSON = notificationItem.eventJSON,
                       let eventData = eventJSON.data(using: .utf8),
                       let eventDict = try? JSONSerialization.jsonObject(with: eventData) as? [String: Any],
                       let tags = eventDict["tags"] as? [[String]] {
                        
                        // Look for P tag (zap sender)
                        for tag in tags where tag.count >= 2 && tag[0] == "P" {
                            if tag[1] == updatedPubkey {
                                shouldUpdate = true
                                relevantPubkey = updatedPubkey
                                break
                            }
                        }
                    }
                    
                case 1, 6, 7: // Notes, reposts, reactions - check event pubkey
                    if notificationItem.authorPubkey == updatedPubkey {
                        shouldUpdate = true
                        relevantPubkey = updatedPubkey
                    }
                    
                default:
                    break
                }
                
                if shouldUpdate, let pubkey = relevantPubkey {
                    // Regenerate the message with updated profile
                    if let eventJSON = notificationItem.eventJSON,
                       let eventData = eventJSON.data(using: .utf8),
                       let eventDict = try? JSONSerialization.jsonObject(with: eventData) as? [String: Any] {
                        
                        let displayName = profile.displayName
                        let newMessage = NotificationMessageBuilder.buildMessage(
                            for: notificationItem.eventKind ?? 1,
                            eventData: eventDict,
                            displayName: displayName
                        )
                        
                        // Only update if message actually changed
                        if newMessage != notificationItem.message {
                            subscriptions[subIdx].notifications[notifIdx].message = newMessage
                            
                            // Update latest message if this is the most recent notification
                            if notifIdx == 0 {
                                subscriptions[subIdx].latestMessage = newMessage
                            }
                            
                            // Update database
                            databaseManager.updateNotificationMessage(
                                notificationId: notificationItem.id,
                                newMessage: newMessage
                            )
                            
                            hasUpdates = true
                        }
                    }
                }
            }
        }
        
        // Trigger UI update if any notifications were updated
        if hasUpdates {
            updateServerGroups()
        }
    }
} 
