//
//  MultiRelayPoolManager.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import Foundation
import Combine
import NostrSDK

/**
 * MultiRelayPoolManager - Manages multiple Relay Pools and automatic reconnection
 * Creates independent RelayPool for each server for better connection management
 */
public class MultiRelayPoolManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = MultiRelayPoolManager()
    
    // MARK: - Published Properties
    @Published public private(set) var serverConnections: [String: ServerConnection] = [:]
    @Published public private(set) var totalConnectionCount = 0
    @Published public private(set) var connectedServersCount = 0
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let reconnectInterval: TimeInterval = 5.0 // Reconnect interval 5 seconds
    private var nip29EventHandler: ((String) -> Void)?
    
    // MARK: - Initialization
    private init() {
        // Multi relay pool manager initialized
    }
    
    // MARK: - Server Connection Management
    
    /**
     * Create or get Relay Pool for specified server
     * @param serverURL Server URL, empty string means default server
     * @param relayURLs Relay URLs corresponding to this server
     * @return ServerConnection object
     */
    public func getOrCreateServerConnection(serverURL: String, relayURLs: [String] = []) -> ServerConnection {
        let key = serverURL.isEmpty ? "default" : serverURL
        
        if let existingConnection = serverConnections[key] {
            return existingConnection
        }
        
        // Create new server connection
        let connection = ServerConnection(
            serverURL: key,
            relayURLs: relayURLs
        )
        
        // Set connection state change callback
        connection.onConnectionStateChanged = { [weak self] in
            self?.updateConnectionCounts()
        }
        
        // Listen to connection state changes
        connection.$isConnected
            .sink { [weak self] _ in
                self?.updateConnectionCounts()
            }
            .store(in: &cancellables)
        
        serverConnections[key] = connection
        return connection
    }
    
    /**
     * Connect specified server
     * @param serverURL Server URL
     */
    public func connectServer(_ serverURL: String) {
        let key = serverURL.isEmpty ? "default" : serverURL
        serverConnections[key]?.connect()
    }
    
    /**
     * Disconnect specified server
     * @param serverURL Server URL
     */
    public func disconnectServer(_ serverURL: String) {
        let key = serverURL.isEmpty ? "default" : serverURL
        serverConnections[key]?.disconnect()
    }
    
    /**
     * Connect all servers
     */
    public func connectAllServers() {
        for connection in serverConnections.values {
            connection.connect()
        }
    }
    
    /**
     * Disconnect all servers
     */
    public func disconnectAllServers() {
        for connection in serverConnections.values {
            connection.disconnect()
        }
    }
    
    // MARK: - Subscription Management
    
    /**
     * Subscribe to events for specified server
     * @param serverURL Server URL
     * @param subscriptionId Subscription ID
     * @param filter Nostr filter
     * @return Subscription ID
     */
    public func subscribe(serverURL: String, subscriptionId: String, filter: [String: Any]) -> String? {
        let key = serverURL.isEmpty ? "default" : serverURL
        return serverConnections[key]?.subscribe(subscriptionId: subscriptionId, filter: filter)
    }
    
    /**
     * Cancel subscription for specified server
     * @param serverURL Server URL
     * @param subscriptionId Subscription ID
     */
    public func unsubscribe(serverURL: String, subscriptionId: String) {
        let key = serverURL.isEmpty ? "default" : serverURL
        serverConnections[key]?.unsubscribe(subscriptionId: subscriptionId)
    }
    
    // MARK: - Private Methods
    
    /**
     * Setup automatic reconnection mechanism
     * @param connection Server connection object
     */
    private func setupAutoReconnect(for connection: ServerConnection) {
        connection.$connectionState
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main) // Debounce
            .sink { [weak self, weak connection] state in
                guard let self = self, let connection = connection else { return }
                
                if state == .disconnected && connection.shouldAutoReconnect {
                    // Delayed reconnection
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.reconnectInterval) {
                        if connection.connectionState == .disconnected && connection.shouldAutoReconnect {
                            print("Attempting to reconnect server: \(connection.serverURL)")
                            connection.connect()
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /**
     * Update connection counts
     */
    private func updateConnectionCounts() {
        DispatchQueue.main.async {
            self.totalConnectionCount = self.serverConnections.count
            self.connectedServersCount = self.serverConnections.values.filter { $0.isConnected }.count
        }
    }
    
    func setNIP29EventHandler(_ handler: @escaping (String) -> Void) {
        nip29EventHandler = handler
    }
    
    // Handle event
    private func handleEvent(_ event: String) {
        // Check if it's a NIP-29 event (20284 or 20285)
        if event.contains("\"kind\":20284") || event.contains("\"kind\":20285") {
            nip29EventHandler?(event)
        }
    }
    
    // Add event handler method
    func onEventReceived(_ event: String) {
        handleEvent(event)
    }
}

// MARK: - Server Connection Class

/**
 * ServerConnection - Single server connection management
 */
public class ServerConnection: ObservableObject, RelayDelegate {
    
    // MARK: - Public Properties
    public let serverURL: String
    public let relayURLs: [String]
    
    @Published public private(set) var isConnected = false
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    @Published public private(set) var activeRelays: [RelayInfo] = []
    @Published public private(set) var lastError: String?
    
    public var shouldAutoReconnect = true
    
    // MARK: - Private Properties
    private var relayPool: RelayPool?
    private var cancellables = Set<AnyCancellable>()
    private var activeSubscriptions: [String: String] = [:] // subscriptionId -> filter
    private var pendingSubscriptions: [(String, [String: Any])] = [] // Pending subscriptions queue
    private var activeSubscriptionFilters: [String: [String: Any]] = [:] // Store all active subscription information, subscriptionId -> filter
    
    // Connection state change callback
    var onConnectionStateChanged: (() -> Void)?
    
    // MARK: - RelayDelegate
    
    public func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        print("Relay state changed - URL: \(relay.url), State: \(state)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch state {
            case .connected:
                self.connectionState = .connected
                self.isConnected = true
                // Process any pending subscriptions after successful connection
                self.processPendingSubscriptions()
            case .connecting:
                self.connectionState = .connecting
            case .notConnected:
                self.connectionState = .disconnected
                self.isConnected = false
            case .error:
                self.connectionState = .disconnected
                self.isConnected = false
            }
            
            self.updateConnectionStatus(with: self.relayPool?.relays ?? [])
        }
    }
    
    public func relay(_ relay: Relay, didReceive response: RelayResponse) {
        switch response {
        case .event:
            break // Events will be handled in didReceive event
        case .eose(let subscriptionId):
            print("Subscription completed - ID: \(subscriptionId)")
        case .auth(let challenge):
            print("Authentication required - challenge: \(challenge)")
            respondToAuthChallenge(relay: relay, challenge: challenge)
        case .ok(let eventId, let success, let message):
            if !success {
                print("Event publish failed - ID: \(eventId), Reason: \(message)")
            }
        case .closed(let subscriptionId, let message):
            print("Subscription closed - ID: \(subscriptionId), Reason: \(message)")
        case .notice(let message):
            print("Relay notice: \(message)")
        case .count(let subscriptionId, let count):
            print("Subscription count - ID: \(subscriptionId), Count: \(count)")
        }
    }
    
    public func relay(_ relay: Relay, didReceive event: RelayEvent) {
        print("Received event - ID: \(event.event.id), Kind: \(event.event.kind), Author: \(event.event.pubkey)")
        
        // Print original tags data
        print("Original tags data:")
        for tag in event.event.tags {
            print("Tag name: \(tag.name), value: \(tag.value), otherParams: \(tag.otherParameters)")
        }
        
        // Convert tags to serializable format
        let serializedTags = event.event.tags.map { tag -> [String] in
            var tagArray = [tag.name, tag.value]
            tagArray.append(contentsOf: tag.otherParameters)
            return tagArray
        }
        
        print("Serialized tags: \(serializedTags)")
        
        // Manually build event dictionary
        let eventDict: [String: Any] = [
            "id": event.event.id,
            "pubkey": event.event.pubkey,
            "created_at": Int(event.event.createdAt),
            "kind": Int(event.event.kind.rawValue),
            "tags": serializedTags,
            "content": event.event.content
        ]
        
        print("Event dictionary: \(eventDict)")
        
        // Convert event to string
        if let eventString = try? JSONSerialization.data(withJSONObject: ["EVENT", event.subscriptionId, eventDict], options: []),
           let eventString = String(data: eventString, encoding: .utf8) {
            print("Serialized event string: \(eventString)")
            // Notify MultiRelayPoolManager to handle event
            MultiRelayPoolManager.shared.onEventReceived(eventString)
        } else {
            print("Event serialization failed")
        }
    }
    
    // MARK: - Initialization
    init(serverURL: String, relayURLs: [String]) {
        self.serverURL = serverURL
        self.relayURLs = relayURLs
        setupRelayPool()
    }
    
    // MARK: - Connection Management
    
    /**
     * Connect to relays
     */
    public func connect() {
        // Ensure the auto-reconnect flag is reset for a new connection attempt
        shouldAutoReconnect = true
        
        guard let relayPool = relayPool else {
            lastError = "Relay pool not initialized"
            return
        }
        
        connectionState = .connecting
        relayPool.connect()
    }
    
    /**
     * Disconnect
     */
    public func disconnect() {
        shouldAutoReconnect = false
        connectionState = .disconnected
        
        // Close all active subscriptions
        if let relayPool = relayPool {
            for (subscriptionId, actualSubscriptionId) in activeSubscriptions {
                relayPool.closeSubscription(with: actualSubscriptionId)
                print("Closed subscription \(subscriptionId) during disconnect")
            }
        }
        
        // Clear active subscription records but keep subscription info for reconnection
        activeSubscriptions.removeAll()
        // Clear pending subscriptions
        pendingSubscriptions.removeAll()
        relayPool?.disconnect()
    }
    
    // MARK: - Subscription Management
    
    /**
     * Subscribe to events
     * @param subscriptionId Subscription ID
     * @param filter Filter
     * @return Actual subscription ID
     */
    public func subscribe(subscriptionId: String, filter: [String: Any]) -> String? {
        activeSubscriptionFilters[subscriptionId] = filter
        
        // If already connected, subscribe immediately
        if connectionState == .connected {
            return executeSubscription(subscriptionId: subscriptionId, filter: filter)
        } else {
            // If not connected yet, add to pending queue
            pendingSubscriptions.append((subscriptionId, filter))
            print("Subscription \(subscriptionId) queued, waiting for connection to \(serverURL)")
            
            // If not connecting yet, initiate connection
            if connectionState == .disconnected {
                connect()
            }
            
            return subscriptionId
        }
    }
    
    /**
     * Execute the actual subscription operation
     */
    private func executeSubscription(subscriptionId: String, filter: [String: Any]) -> String? {
        guard let relayPool = relayPool else {
            lastError = "Relay pool not initialized"
            return nil
        }
        
        // Convert filter format
        guard let nostrFilter = convertToNostrFilter(filter) else {
            lastError = "Invalid filter format"
            return nil
        }
        
        // Execute subscription
        let actualSubscriptionId = relayPool.subscribe(with: nostrFilter, subscriptionId: subscriptionId)
        activeSubscriptions[subscriptionId] = actualSubscriptionId
        print("Successfully subscribed \(subscriptionId) to \(serverURL)")
        return actualSubscriptionId
    }
    
    /**
     * Process the pending subscriptions queue
     */
    private func processPendingSubscriptions() {
        guard connectionState == .connected else { return }
        
        let subscriptionsToProcess = pendingSubscriptions
        pendingSubscriptions.removeAll()
        
        for (subscriptionId, filter) in subscriptionsToProcess {
            let _ = executeSubscription(subscriptionId: subscriptionId, filter: filter)
        }
    }
    
    /**
     * Cancel subscription
     * @param subscriptionId Subscription ID
     */
    public func unsubscribe(subscriptionId: String) {
        guard let relayPool = relayPool else { return }
        
        if let actualSubscriptionId = activeSubscriptions[subscriptionId] {
            relayPool.closeSubscription(with: actualSubscriptionId)
            activeSubscriptions.removeValue(forKey: subscriptionId)
            activeSubscriptionFilters.removeValue(forKey: subscriptionId)
        }
        
        // 🚦 If no active or pending subscriptions remain, disconnect and release the RelayPool to free resources
        if activeSubscriptions.isEmpty && pendingSubscriptions.isEmpty {
            print("No active subscriptions remain for \(serverURL). Disconnecting relay pool.")
            disconnect()
        }
    }

    // MARK: - Private Methods
    
    /**
     * Setup Relay Pool
     */
    private func setupRelayPool() {
        // Create RelayPool
        var relays: [Relay] = []
        for relayURL in relayURLs {
            // Ensure URL starts with ws:// or wss://
            var urlString = relayURL
            if !urlString.hasPrefix("ws://") && !urlString.hasPrefix("wss://") {
                urlString = "ws://" + urlString.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "")
            }
            
            print("Setting up relay with URL: \(urlString)")
            if let url = URL(string: urlString) {
                do {
                    let relay = try Relay(url: url)
                    relays.append(relay)
                } catch {
                    print("Failed to create relay for \(urlString): \(error)")
                }
            }
        }
        
        if relays.isEmpty {
            print("Warning: No valid relays created")
            return
        }
        
        relayPool = RelayPool(relays: Set(relays), delegate: self)
        
        // Listen to connection state
        relayPool?.$relays
            .sink { [weak self] relays in
                DispatchQueue.main.async {
                    self?.updateConnectionStatus(with: relays)
                }
            }
            .store(in: &cancellables)
    }
    
    /**
     * Update connection status
     * @param relays Relay set
     */
    private func updateConnectionStatus(with relays: Set<Relay>) {
        let connectedRelays = relays.filter { $0.state == .connected }
        let disconnectedOrErrorRelays = relays.filter { 
            if case .error = $0.state { return true }
            return $0.state == .notConnected
        }
        
        let relayInfos = relays.map { relay in
            RelayInfo(
                url: relay.url.absoluteString,
                status: relay.state == .connected ? "connected" : "disconnected"
            )
        }
        
        let wasConnected = self.isConnected
        let previousState = self.connectionState
        
        DispatchQueue.main.async {
            self.isConnected = !connectedRelays.isEmpty
            self.activeRelays = relayInfos
            
            let newConnectionState: ConnectionState
            let hasErrorState = relays.contains { relay in
                if case .error = relay.state { return true }
                return false
            }
            
            if connectedRelays.count > 0 {
                newConnectionState = .connected
            } else if disconnectedOrErrorRelays.count == relays.count {
                newConnectionState = .disconnected
            } else {
                newConnectionState = .connecting
            }
            
            self.connectionState = newConnectionState
            self.onConnectionStateChanged?()
            
            if !wasConnected && self.isConnected && previousState != .connected && newConnectionState == .connected {
                self.processPendingSubscriptions()
            }
            
            if (newConnectionState == .disconnected && hasErrorState) || 
               (newConnectionState == .disconnected && previousState == .connecting) {
                self.handleReconnection()
            }
        }
    }
    
    /**
     * Convert filter format
     * @param filter Dictionary format filter
     * @return Filter object
     */
    private func convertToNostrFilter(_ filter: [String: Any]) -> Filter? {
        let ids = filter["ids"] as? [String]
        let authors = filter["authors"] as? [String]
        let kinds = (filter["kinds"] as? [Int])
        let since = filter["since"] as? Int
        let until = filter["until"] as? Int
        let limit = filter["limit"] as? Int
        
        // Convert tags
        var tags: [Character: [String]] = [:]
        for (key, value) in filter {
            if key.hasPrefix("#") && key.count == 2,
               let tagChar = key.dropFirst().first,
               let tagValues = value as? [String] {
                tags[tagChar] = tagValues
            }
        }
        
        return Filter(
            ids: ids,
            authors: authors,
            kinds: kinds,
            tags: tags.isEmpty ? nil : tags,
            since: since,
            until: until,
            limit: limit
        )
    }
    
    // Add new method for handling reconnection
    private func handleReconnection() {
        guard shouldAutoReconnect else { return }
        
        // Save current subscription information
        let subscriptionsToRestore = activeSubscriptionFilters
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            
            if self.connectionState == .disconnected && self.shouldAutoReconnect {
                self.activeSubscriptions.removeAll()
                
                self.relayPool?.disconnect()
                self.relayPool = nil
                self.setupRelayPool()
                
                if self.relayPool != nil {
                    // Add all subscriptions to pending queue before connecting
                    for (subscriptionId, filter) in subscriptionsToRestore {
                        self.pendingSubscriptions.append((subscriptionId, filter))
                    }
                    
                    self.connect()
                }
            }
        }
    }
    
    // MARK: - NIP-42 Authentication Handling
    
    /// Responds to NIP-42 auth challenge by publishing a kind 22242 event signed with the current user's keypair.
    /// - Parameters:
    ///   - relay: The relay requesting authentication.
    ///   - challenge: The challenge string provided by the relay.
    private func respondToAuthChallenge(relay: Relay, challenge: String) {
        guard let relayPool = relayPool else {
            print("[Auth] Relay pool not initialized – cannot respond to challenge")
            return
        }

        // Obtain user's private key from NostrManager
        guard let privateKeyHex = NostrManager.shared.getPrivateKey(),
              let keypair = Keypair(hex: privateKeyHex) else {
            print("[Auth] No keypair available – cannot sign auth event")
            return
        }

        do {
            let relayURLString = relay.url.absoluteString == "ws://nopu.sh" ? "wss://nopu.sh" : relay.url.absoluteString
            let relayTag = Tag(name: "relay", value: relayURLString, otherParameters: [])
            let challengeTag = Tag(name: "challenge", value: challenge, otherParameters: [])

            let authEvent = try NostrEvent(
                kind: EventKind(rawValue: 22242),
                content: "",
                tags: [relayTag, challengeTag],
                signedBy: keypair
            )

            let serializedTags = authEvent.tags.map { tag -> [String] in
                var arr = [tag.name, tag.value]
                arr.append(contentsOf: tag.otherParameters)
                return arr
            }

            let authEventDict: [String: Any] = [
                "id": authEvent.id,
                "pubkey": authEvent.pubkey,
                "created_at": Int(authEvent.createdAt),
                "kind": Int(authEvent.kind.rawValue),
                "tags": serializedTags,
                "content": authEvent.content,
                "sig": authEvent.signature!
            ]

            let authMessage: [Any] = ["AUTH", authEventDict]
            let jsonData = try JSONSerialization.data(withJSONObject: authMessage, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                relayPool.send(request: jsonString)
            }

            print("[Auth] Sent AUTH event (22242) to relay \(relay.url), auth string: \(authMessage)")
        } catch {
            print("[Auth] Failed to create/send AUTH event: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

/**
 * Connection state enum
 */
public enum ConnectionState {
    case disconnected
    case connecting
    case connected
} 
