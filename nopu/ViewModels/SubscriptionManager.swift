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
            "kinds": [20284], // NIP-29 group events
            "#h": groupIds,    // h tag contains any of the groupIds
            "since": Int(Date().timeIntervalSince1970 - 3600) // Events from the last hour
        ]
        
        return ["REQ", subscriptionId, filter]
    }
    
    // Generate filter dictionary
    func generateFilterDict() -> [String: Any] {
        return [
            "kinds": [20284], // NIP-29 group events
            "#h": groupIds,    // h tag contains any of the groupIds
            "since": Int(Date().timeIntervalSince1970 - 3600) // Events from the last hour
        ]
    }
}

class SubscriptionManager: ObservableObject {
    @Published var subscriptions: [Subscription] = []
    @Published var serverGroups: [ServerGroup] = []
    @Published var isAutoConnectEnabled = true
    
    private let databaseManager = DatabaseManager.shared
    private let multiRelayManager = MultiRelayPoolManager.shared
    private let eventProcessor = EventProcessor.shared
    
    init() {
        loadSubscriptions()
        updateServerGroups()
        configureNostrManagerWithSubscriptionRelays()
        setupAutoConnections()
        
        // Set up 20284 event handler
        multiRelayManager.setEvent20284Handler { [weak self] eventString in
            DispatchQueue.main.async {
                self?.handleEvent20284(eventString)
            }
        }
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
        
        // If no relay URLs found, use default
        if allRelayURLs.isEmpty {
            allRelayURLs.insert("ws://127.0.0.1:8080")
        }
        
        // Add collected relay URLs to NostrManager
        for relayURL in allRelayURLs {
            NostrManager.shared.addRelay(url: relayURL)
        }
        
        // Connect if relays are available
        NostrManager.shared.connectIfRelaysAvailable()
        
        print("Configured \(allRelayURLs.count) relays from subscriptions: \(Array(allRelayURLs))")
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
        
        for group in serverGroups {
            // Get relay URLs from subscriptions
            let relayURLs = group.subscriptions.flatMap { $0.filters.relays }
            let uniqueRelayURLs = Array(Set(relayURLs))
            
            // Create or get server connection
            let serverConnection = multiRelayManager.getOrCreateServerConnection(
                serverURL: group.serverURL,
                relayURLs: uniqueRelayURLs.isEmpty ? ["ws://127.0.0.1:8080"] : uniqueRelayURLs
            )
            
            if serverConnection.connectionState == .disconnected {
                serverConnection.connect()
            }
            
            // Create subscription for each group
            let subscriptionId = "sub_\(group.serverURL)_\(UUID().uuidString.prefix(8))"
            let filter = group.generateFilterDict()
            
            // Execute subscription
            let _ = multiRelayManager.subscribe(
                serverURL: group.serverURL,
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
        databaseManager.deleteSubscription(id: id)
        loadSubscriptions() // Reload to update UI
        updateServerGroups() // Update groups
        
        // Reconfigure NostrManager relays (remove potentially unneeded relays)
        reconfigureNostrManagerRelays()
        
        // Reset connections (may need to remove some subscriptions)
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
        let serverConnection = multiRelayManager.getOrCreateServerConnection(
            serverURL: serverURL,
            relayURLs: relayURLs.isEmpty ? ["ws://127.0.0.1:8080"] : relayURLs
        )
        
        if serverConnection.connectionState == .disconnected {
            serverConnection.connect()
        }
        
        // Create subscription for single subscription
        let subscriptionId = "sub_\(subscription.groupId)"
        let filter: [String: Any] = [
            "kinds": [20284],
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
    private func getNotificationMessage(for eventKind: Int) -> String {
        switch eventKind {
        case 1:
            return "Received a new note"
        case 7:
            return "Received a like message"
        case 1059:
            return "Received a direct message"
        case 6:
            return "Received a repost message"
        case 9735:
            return "Received a zap message"
        default:
            return "Received a new notification"
        }
    }
    
    // Handle 20284 event
    func handleEvent20284(_ eventString: String) {
        guard let (groupId, eventContent) = eventProcessor.processEvent20284(eventString) else {
            print("Failed to process 20284 event")
            return
        }
        
        // Find corresponding subscription
        guard let subscription = subscriptions.first(where: { $0.groupId == groupId }) else {
            print("Subscription not found - groupId: \(groupId)")
            return
        }
        
        // Create notification
        let notification = NotificationItem(
            message: getNotificationMessage(for: 20284),
            type: .general,
            eventJSON: eventContent,
            authorPubkey: nil,
            eventId: nil,
            eventKind: 20284,
            eventCreatedAt: Date()
        )
        
        // Update subscription
        var updatedSubscription = subscription
        updatedSubscription.notifications.insert(notification, at: 0)
        updatedSubscription.unreadCount += 1
        updatedSubscription.lastNotificationAt = Date()
        updatedSubscription.latestMessage = notification.message
        
        // Update database and UI on main thread
        DispatchQueue.main.async {
            self.databaseManager.updateSubscription(updatedSubscription)
            self.loadSubscriptions() // Reload to update UI
        }
    }
} 
