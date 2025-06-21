import Foundation
import Combine
import NostrSDK

/**
 * NostrManager - A convenient utility class for Nostr using nostr-sdk-ios
 * Replaces the previous Rust FFI implementation
 */
public class NostrManager: ObservableObject, RelayDelegate {
    
    // MARK: - Singleton
    public static let shared = NostrManager()
    
    // MARK: - Properties
    @Published public private(set) var isConnected = false
    @Published public private(set) var connectionStatus = "Not connected"
    @Published public private(set) var activeRelays: [RelayInfo] = []
    @Published public private(set) var lastError: String?
    
    private var relayPool: RelayPool?
    private var keypair: Keypair?
    private var cancellables = Set<AnyCancellable>()
    private var eventSubjects: [String: PassthroughSubject<NostrEvent, Never>] = [:]
    private var eventTimeouts: [String: Timer] = [:]
    
    // MARK: - Constants
    private static let privateKeyKey = "NostrManager.privateKey"
    
    // MARK: - Initialization
    private init() {
        // NostrManager initialized
    }
    
    // MARK: - RelayDelegate
    
    public func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        print("Relay state changed - URL: \(relay.url), State: \(state)")
        
        // When the relay enters the `.error` state, cache the error description in `lastError` so the UI can surface it
        if case .error(let error) = state {
            self.lastError = error.localizedDescription
        }
        
        updateConnectionStatus(with: relayPool?.relays ?? [])
    }
    
    public func relay(_ relay: Relay, didReceive response: RelayResponse) {
        switch response {
        case .event:
            break // Events will be handled in didReceive event
        case .eose(let subscriptionId):
            if let subject = eventSubjects[subscriptionId] {
                subject.send(completion: .finished)
                cleanupSubscription(subscriptionId)
            }
        case .auth(let challenge):
            print("Authentication required - challenge: \(challenge)")
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
        // Handle unknown event types
        if case .unknown(let kind) = event.event.kind {
            if let contentData = event.event.content.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
                print("Received unknown event - kind: \(kind), Content: \(json)")
            }
        }
        
        if let subject = eventSubjects[event.subscriptionId] {
            subject.send(event.event)
        }
    }
    
    // MARK: - Key Management
    
    /**
     * Generate new keys
     * @return Returns true on success, false on failure
     */
    public func generateNewKeys() -> Bool {
        guard let keypair = Keypair() else {
            self.lastError = "Failed to generate new keypair"
            return false
        }
        self.keypair = keypair
        self.lastError = nil
        return true
    }
    
    /**
     * Import keys from private key
     * @param privateKey Private key in hex format
     * @return Returns true on success, false on failure
     */
    public func importKeys(privateKey: String) -> Bool {
        guard let keypair = Keypair(hex: privateKey) else {
            self.lastError = "Failed to import keys from private key"
            return false
        }
        self.keypair = keypair
        self.lastError = nil
        return true
    }
    
    /**
     * Get public key
     * @return Public key in hex format, or nil if no keys available
     */
    public func getPublicKey() -> String? {
        return keypair?.publicKey.hex
    }
    
    /**
     * Get private key
     * @return Private key in hex format, or nil if no keys available
     */
    public func getPrivateKey() -> String? {
        return keypair?.privateKey.hex
    }
    
    /**
     * Auto-initialize keys (load from storage or generate new)
     * @return Returns true on success, false on failure
     */
    public func autoInitializeKeys() -> Bool {
        // Try to load existing keys from UserDefaults
        if let savedPrivateKey = UserDefaults.standard.string(forKey: Self.privateKeyKey) {
            if importKeys(privateKey: savedPrivateKey) {
                return true
            }
        }
        
        // Generate new keys if no saved keys or loading failed
        if generateNewKeys() {
            // Save the new private key
            if let privateKey = getPrivateKey() {
                UserDefaults.standard.set(privateKey, forKey: Self.privateKeyKey)
                return true
            }
        }
        
        self.lastError = "Failed to initialize keys"
        return false
    }
    
    /**
     * Clear stored keys
     */
    public func clearKeys() {
        UserDefaults.standard.removeObject(forKey: Self.privateKeyKey)
        self.keypair = nil
    }
    
    // MARK: - Client Management
    
    /**
     * Initialize client
     * @return Returns true on success, false on failure
     */
    public func initializeClient() -> Bool {
        guard self.keypair != nil else {
            self.lastError = "No keypair available, please generate or import keys first"
            return false
        }
        
        self.relayPool = RelayPool(relays: [], delegate: self)
        self.lastError = nil
        return true
    }
    
    // MARK: - Setup Methods
    
    /**
     * Quick setup: auto-initialize keys + initialize client
     * @return Returns true on success, false on failure
     */
    public func quickSetup() -> Bool {
        // 1. Auto-initialize keys (load existing or generate new)
        guard autoInitializeKeys() else {
            return false
        }
        
        // 2. Initialize client
        guard initializeClient() else {
            return false
        }
        
        return true
    }
    
    /**
     * Quick setup and connect (now connects only when relays are available)
     * @return Returns true on success, false on failure
     */
    public func quickSetupAndConnect() -> Bool {
        guard quickSetup() else {
            return false
        }
        
        // Monitor connection status
        relayPool?.$relays
            .sink { [weak self] relays in
                DispatchQueue.main.async {
                    self?.updateConnectionStatus(with: relays)
                }
            }
            .store(in: &cancellables)
        
        return true
    }
    
    /**
     * Connect to relays (only if relays are added)
     */
    public func connectIfRelaysAvailable() {
        guard let relayPool = relayPool else { return }
        
        // Only connect if there are relays
        if !relayPool.relays.isEmpty {
            relayPool.connect()
        }
    }
    
    /**
     * Update connection status based on relay states
     */
    private func updateConnectionStatus(with relays: Set<Relay>) {
        let connectedRelays = relays.filter { $0.state == .connected }
        let relayInfos = relays.map { relay in
            RelayInfo(
                url: relay.url.absoluteString,
                status: relay.state == .connected ? "connected" : "disconnected"
            )
        }
        
        self.isConnected = !connectedRelays.isEmpty
        self.connectionStatus = connectedRelays.isEmpty ? 
            "Disconnected" : 
            "Connected to \(connectedRelays.count)/\(relays.count) relay(s)"
        self.activeRelays = relayInfos
        
        // Connection status updated
    }
    
    // MARK: - Relay Management
    
    /**
     * Add relay
     * @param url Relay WebSocket URL
     */
    public func addRelay(url: String) {
        guard let relayPool = relayPool,
              let relayURL = URL(string: url) else {
            self.lastError = "Invalid relay URL or relay pool not initialized"
            return
        }
        
        if relayPool.relays.contains(where: { $0.url == relayURL }) {
            return
        }
        
        do {
            let relay = try Relay(url: relayURL)
            relayPool.add(relay: relay)
        } catch {
            self.lastError = "Failed to add relay: \(error.localizedDescription)"
        }
    }
    
    /**
     * Check if URL is a valid WebSocket URL
     * @param urlString URL string to validate
     * @return true if valid WebSocket URL
     */
    public func isValidWebSocketURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "ws" || url.scheme == "wss"
    }
    
    // MARK: - Event Publishing
    
    /**
     * Publish an event
     * @param kind Event kind
     * @param content Event content
     * @param tags Event tags
     * @return Event ID if successful, nil if failed
     */
    public func publishEvent(kind: UInt16, content: String, tags: [[String]]) -> String? {
        guard let relayPool = relayPool, let keypair = keypair else {
            self.lastError = "Relay pool or keypair not initialized"
            return nil
        }
        
        do {
            // Create event kind
            let eventKind = EventKind(rawValue: Int(kind))
            
            // Convert string tag arrays to Tag objects
            var eventTags: [Tag] = []
            for tagArray in tags {
                if tagArray.count >= 2 {
                    let name = tagArray[0]
                    let value = tagArray[1]
                    let otherParameters = Array(tagArray.dropFirst(2))
                    let tag = Tag(name: name, value: value, otherParameters: otherParameters);
                    eventTags.append(tag);
                }
            }
            
            // Create and sign the event
            let event = try NostrEvent(kind: eventKind, content: content, tags: eventTags, signedBy: keypair)
            
            // Send to relay pool
            relayPool.publishEvent(event)
            
            return event.id
        } catch {
            self.lastError = "Failed to create or send event: \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - Event Fetching
    
    /**
     * Fetch events with filter
     * @param filter Nostr filter
     * @param timeoutSeconds Timeout in seconds
     * @return Publisher that emits NostrEvents
     */
    public func fetchEvents(filter: NostrFilter, timeoutSeconds: UInt64) -> AnyPublisher<NostrEvent, Never> {
        let subject = PassthroughSubject<NostrEvent, Never>()
        
        guard let relayPool = relayPool else {
            self.lastError = "Relay pool not initialized"
            subject.send(completion: .finished)
            return subject.eraseToAnyPublisher()
        }
        
        // Build the filter - convert UInt16 kinds to Int
        let filterKinds = filter.kinds?.map { Int($0) }
        let filterSince = filter.since.map { Int($0) }
        let filterUntil = filter.until.map { Int($0) }
        let filterLimit = filter.limit.map { Int($0) }
        
        // Convert tags to proper format for Filter: [Character: [String]]
        var filterTags: [Character: [String]]? = nil
        if let tags = filter.tags, !tags.isEmpty {
            var tagDict: [Character: [String]] = [:]
            for tagArray in tags {
                if tagArray.count >= 2 {
                    if let tagChar = tagArray[0].first, tagArray[0].count == 1 {
                        let tagValues = Array(tagArray.dropFirst())
                        tagDict[tagChar] = tagValues
                    }
                }
            }
            filterTags = tagDict.isEmpty ? nil : tagDict
        }
        
        // Create Filter with proper tags support
        guard let nostrFilter = Filter(
            ids: filter.ids,
            authors: filter.authors,
            kinds: filterKinds,
            tags: filterTags,
            since: filterSince,
            until: filterUntil,
            limit: filterLimit
        ) else {
            self.lastError = "Invalid filter parameters - Filter creation failed"
            subject.send(completion: .finished)
            return subject.eraseToAnyPublisher()
        }
        
        // Subscribe to get events
        let subscriptionId = relayPool.subscribe(with: nostrFilter)
        eventSubjects[subscriptionId] = subject
        
        // Set up timeout
        let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(timeoutSeconds), repeats: false) { [weak self] _ in
            subject.send(completion: .finished)
            self?.cleanupSubscription(subscriptionId)
        }
        
        eventTimeouts[subscriptionId] = timer
        
        return subject.eraseToAnyPublisher()
    }
    
    /**
     * Clean up subscription resources
     */
    private func cleanupSubscription(_ subscriptionId: String) {
        eventSubjects.removeValue(forKey: subscriptionId)
        eventTimeouts[subscriptionId]?.invalidate()
        eventTimeouts.removeValue(forKey: subscriptionId)
        relayPool?.closeSubscription(with: subscriptionId)
    }
}

// MARK: - Supporting Types

public struct NostrFilter {
    public let ids: [String]?
    public let authors: [String]?
    public let kinds: [UInt16]?
    public let since: UInt64?
    public let until: UInt64?
    public let limit: UInt64?
    public let search: String?
    public let tags: [[String]]?
    
    public init(ids: [String]? = nil, authors: [String]? = nil, kinds: [UInt16]? = nil, since: UInt64? = nil, until: UInt64? = nil, limit: UInt64? = nil, search: String? = nil, tags: [[String]]? = nil) {
        self.ids = ids
        self.authors = authors
        self.kinds = kinds
        self.since = since
        self.until = until
        self.limit = limit
        self.search = search
        self.tags = tags
    }
}

public struct RelayInfo {
    public let url: String
    public let status: String
    
    public init(url: String, status: String) {
        self.url = url
        self.status = status
    }
} 
