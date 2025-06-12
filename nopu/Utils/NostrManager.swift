import Foundation
import Combine
import NostrSDK

/**
 * NostrManager - A convenient utility class for Nostr using nostr-sdk-ios
 * Replaces the previous Rust FFI implementation
 */
public class NostrManager: ObservableObject {
    
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
    
    // MARK: - Constants
    private static let popularRelays = [
        "ws://127.0.0.1:8080"
    ]
    
    private static let privateKeyKey = "NostrManager.privateKey"
    
    // MARK: - Initialization
    private init() {
        print("🔧 NostrManager initialized")
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
            print("🔑 Loading existing keys from storage")
            if importKeys(privateKey: savedPrivateKey) {
                return true
            } else {
                print("⚠️ Failed to load saved keys, generating new ones")
            }
        }
        
        // Generate new keys if no saved keys or loading failed
        print("🔑 Generating new keys")
        if generateNewKeys() {
            // Save the new private key
            if let privateKey = getPrivateKey() {
                UserDefaults.standard.set(privateKey, forKey: Self.privateKeyKey)
                print("✅ New keys generated and saved")
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
        print("🗑️ Keys cleared")
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
        
        self.relayPool = RelayPool(relays: [])
        self.lastError = nil
        return true
    }
    
    // MARK: - Setup Methods
    
    /**
     * Quick setup: auto-initialize keys + initialize client + add popular relays
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
        
        // 3. Add popular relays
        for relayUrl in Self.popularRelays {
            addRelay(url: relayUrl)
        }
        
        return true
    }
    
    /**
     * Quick setup and connect
     * @return Returns true on success, false on failure
     */
    public func quickSetupAndConnect() -> Bool {
        guard quickSetup() else {
            return false
        }
        
        // Connect to relays
        relayPool?.connect()
        
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
        
        print("📊 Connection status: \(connectedRelays.count)/\(relays.count) relays connected")
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
        
        do {
            let relay = try Relay(url: relayURL)
            relayPool.add(relay: relay)
            print("✅ Relay added: \(url)")
        } catch {
            self.lastError = "Failed to add relay: \(error.localizedDescription)"
            print("❌ Failed to add relay: \(url), error: \(error)")
        }
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
            
            print("📤 Publishing event - ID: \(event.id), Kind: \(event.kind), Content: \(event.content), Tags: \(event.tags), CreatedAt: \(event.createdAt)")
            
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
     * @return Array of events
     */
    public func fetchEvents(filter: NostrFilter, timeoutSeconds: UInt64) -> [NostrEvent] {
        guard let relayPool = relayPool else {
            self.lastError = "Relay pool not initialized"
            return []
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
                        print("🏷️ Added tag filter: '\(tagChar)' = \(tagValues)")
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
            return []
        }
        
        // Log the original requested tags for debugging
        if let tags = filter.tags, !tags.isEmpty {
            print("🏷️ Original requested tags: \(tags)")
        }
        
        // Subscribe to get events
        print("🔍 NostrFilter: \(nostrFilter)")
        let subscriptionId = relayPool.subscribe(with: nostrFilter)
        
        return []
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
