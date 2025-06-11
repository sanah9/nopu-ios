import Foundation
import Combine

/**
 * NostrUtils - A convenient utility class for Nostr
 * Based on rust-nostr/nostr-sdk FFI bindings, providing simplified API
 */
public class NostrUtils: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = NostrUtils()
    
    // MARK: - Properties
    @Published public private(set) var isConnected = false
    @Published public private(set) var connectionStatus = "Not connected"
    @Published public private(set) var activeRelays: [RelayInfo] = []
    @Published public private(set) var lastError: String?
    
    private var client: NostrClient?
    private var keys: NostrKeys?
    private var subscriptions: [String: SubscriptionResult] = [:]
    
    // UserDefaults key for private key storage
    private static let privateKeyUserDefaultsKey = "NostrPrivateKey"
    
    // Popular relay list
    public static let popularRelays = [
        "wss://relay.damus.io",
        "wss://nos.lol",
        "wss://relay.snort.social",
        "wss://nostr-pub.wellorder.net",
        "wss://relay.nostr.band"
    ]
    
    private init() {}
    
    // MARK: - Key Persistence
    
    /**
     * Save private key to UserDefaults
     * @param privateKey Private key to save
     * @return Returns true on success, false on failure
     */
    private func savePrivateKeyToUserDefaults(_ privateKey: String) -> Bool {
        UserDefaults.standard.set(privateKey, forKey: Self.privateKeyUserDefaultsKey)
        self.lastError = nil
        return true
    }
    
    /**
     * Load private key from UserDefaults
     * @return Private key string, returns nil if not found
     */
    private func loadPrivateKeyFromUserDefaults() -> String? {
        return UserDefaults.standard.string(forKey: Self.privateKeyUserDefaultsKey)
    }
    
    /**
     * Delete stored private key from UserDefaults
     * @return Returns true on success, false on failure
     */
    public func deleteStoredPrivateKey() -> Bool {
        UserDefaults.standard.removeObject(forKey: Self.privateKeyUserDefaultsKey)
        return true
    }
    
    /**
     * Check if there is a stored private key
     * @return Returns true if stored private key exists, false otherwise
     */
    public func hasStoredPrivateKey() -> Bool {
        return loadPrivateKeyFromUserDefaults() != nil
    }
    
    /**
     * Auto-initialize keys: import existing key if available, otherwise generate new one and save
     * @return Returns true on success, false on failure
     */
    public func autoInitializeKeys() -> Bool {
        if let storedPrivateKey = loadPrivateKeyFromUserDefaults() {
            // Found stored private key, import it
            print("📱 Found stored private key, importing...")
            return importKeys(privateKey: storedPrivateKey)
        } else {
            // No stored private key found, generate new one and save
            print("🔑 No stored private key found, generating new keys...")
            if generateNewKeys() {
                if let privateKey = getPrivateKey() {
                    if savePrivateKeyToUserDefaults(privateKey) {
                        print("✅ New keys generated and saved successfully")
                        return true
                    } else {
                        print("⚠️ Keys generated but failed to save")
                        return true // Keys generated successfully, just saving failed
                    }
                } else {
                    self.lastError = "Failed to get generated private key"
                    return false
                }
            } else {
                return false
            }
        }
    }
    
    // MARK: - Key Management
    
    /**
     * Generate new key pair
     * @return Returns true on success, false on failure
     */
    public func generateNewKeys() -> Bool {
        self.keys = generateKeys()
        self.lastError = nil
        return true
    }
    
    /**
     * Import key pair from private key
     * @param privateKey Private key (hex format)
     * @return Returns true on success, false on failure
     */
    public func importKeys(privateKey: String) -> Bool {
        do {
            self.keys = try keysFromSecretKey(secretKeyHex: privateKey)
            self.lastError = nil
            return true
        } catch {
            self.lastError = "Failed to import keys: \(error.localizedDescription)"
            return false
        }
    }
    
    /**
     * Import keys and save to UserDefaults
     * @param privateKey Private key (hex format)
     * @return Returns true on success, false on failure
     */
    public func importAndSaveKeys(privateKey: String) -> Bool {
        if importKeys(privateKey: privateKey) {
            _ = savePrivateKeyToUserDefaults(privateKey)
            return true
        }
        return false
    }
    
    /**
     * Generate new keys and save to UserDefaults
     * @return Returns true on success, false on failure
     */
    public func generateAndSaveNewKeys() -> Bool {
        if generateNewKeys() {
            if let privateKey = getPrivateKey() {
                _ = savePrivateKeyToUserDefaults(privateKey)
                return true
            }
        }
        return false
    }
    
    /**
     * Get public key
     * @return Public key string, returns nil if no keys are available
     */
    public func getPublicKey() -> String? {
        return keys?.publicKey
    }
    
    /**
     * Get private key
     * @return Private key string, returns nil if no keys are available
     */
    public func getPrivateKey() -> String? {
        return keys?.privateKey
    }
    
    // MARK: - Client Management
    
    /**
     * Initialize Nostr client
     * @return Returns true on success, false on failure
     */
    public func initializeClient() -> Bool {
        guard let keys = self.keys else {
            self.lastError = "No keys available, please generate or import keys first"
            return false
        }
        
        do {
            self.client = try NostrClient(keys: keys)
            self.lastError = nil
            return true
        } catch {
            self.lastError = "Failed to initialize client: \(error.localizedDescription)"
            return false
        }
    }
    
    /**
     * Quick setup: auto-initialize keys + initialize client + add popular relays
     * @return Returns true on success, false on failure
     */
    public func quickSetup() -> Bool {
        // 1. Auto-initialize keys (load existing or generate new)
        guard autoInitializeKeys() else { return false }
        
        // 2. Initialize client
        guard initializeClient() else { return false }
        
        // 3. Add popular relays
        for relay in Self.popularRelays {
            _ = addRelay(relay)
        }
        
        return true
    }
    
    // MARK: - Relay Management
    
    /**
     * Add relay server
     * @param url Relay server URL
     * @return Returns true on success, false on failure
     */
    public func addRelay(_ url: String) -> Bool {
        guard let client = self.client else {
            self.lastError = "Client not initialized"
            return false
        }
        
        do {
            try client.addRelay(url: url)
            self.lastError = nil
            updateRelayStatus()
            return true
        } catch {
            self.lastError = "Failed to add relay: \(error.localizedDescription)"
            return false
        }
    }
    
    /**
     * Remove relay server
     * @param url Relay server URL
     * @return Returns true on success, false on failure
     */
    public func removeRelay(_ url: String) -> Bool {
        guard let client = self.client else {
            self.lastError = "Client not initialized"
            return false
        }
        
        do {
            try client.removeRelay(url: url)
            self.lastError = nil
            updateRelayStatus()
            return true
        } catch {
            self.lastError = "Failed to remove relay: \(error.localizedDescription)"
            return false
        }
    }
    
    /**
     * Connect to relay servers
     * @return Returns true on success, false on failure
     */
    public func connect() -> Bool {
        guard let client = self.client else {
            self.lastError = "Client not initialized"
            return false
        }
        
        do {
            try client.connect()
            self.isConnected = true
            self.connectionStatus = "Connected"
            self.lastError = nil
            updateRelayStatus()
            return true
        } catch {
            self.isConnected = false
            self.connectionStatus = "Connection failed"
            self.lastError = "Failed to connect: \(error.localizedDescription)"
            return false
        }
    }
    
    /**
     * Disconnect from relay servers
     * @return Returns true on success, false on failure
     */
    public func disconnect() -> Bool {
        guard let client = self.client else {
            self.lastError = "Client not initialized"
            return false
        }
        
        do {
            try client.disconnect()
            self.isConnected = false
            self.connectionStatus = "Disconnected"
            self.lastError = nil
            updateRelayStatus()
            return true
        } catch {
            self.lastError = "Failed to disconnect: \(error.localizedDescription)"
            return false
        }
    }
    
    /**
     * Update relay status
     */
    private func updateRelayStatus() {
        guard let client = self.client else { return }
        
        DispatchQueue.main.async {
            self.activeRelays = client.getRelayStatus()
        }
    }
    
    // MARK: - User Metadata
    
    /**
     * Set user profile
     * @param name Username
     * @param about Bio/description
     * @param picture Avatar URL
     * @param website Website URL
     * @return Returns event ID on success, nil on failure
     */
    public func setProfile(name: String? = nil, about: String? = nil, picture: String? = nil, website: String? = nil) -> String? {
        guard let client = self.client else {
            self.lastError = "Client not initialized"
            return nil
        }
        
        guard isConnected else {
            self.lastError = "Not connected to relay servers"
            return nil
        }
        
        let metadata = NostrMetadata(
            name: name,
            about: about,
            picture: picture,
            banner: nil,
            displayName: name,
            nip05: nil,
            lud16: nil,
            website: website
        )
        
        do {
            let eventId = try client.setMetadata(metadata: metadata)
            self.lastError = nil
            return eventId
        } catch {
            self.lastError = "Failed to set user profile: \(error.localizedDescription)"
            return nil
        }
    }
    
    /**
     * Get user metadata
     * @param pubkey User public key
     * @return Returns metadata on success, nil on failure
     */
    public func getUserMetadata(_ pubkey: String) -> NostrMetadata? {
        guard let client = self.client else {
            self.lastError = "Client not initialized"
            return nil
        }
        
        do {
            let metadata = try client.getMetadata(pubkey: pubkey)
            self.lastError = nil
            return metadata
        } catch {
            self.lastError = "Failed to get user metadata: \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - Subscription Management
    
    /**
     * Subscribe to event stream
     * @param filter Event filter
     * @param autoCloseAfter Auto-close time in seconds (optional)
     * @return Returns subscription ID on success, nil on failure
     */
    public func subscribe(filter: NostrFilter, autoCloseAfter: UInt64? = nil) -> String? {
        guard let client = self.client else {
            self.lastError = "Client not initialized"
            return nil
        }
        
        guard isConnected else {
            self.lastError = "Not connected to relay servers"
            return nil
        }
        
        do {
            let result = try client.subscribe(filter: filter, autoCloseAfter: autoCloseAfter)
            let subscriptionId = result.subscriptionId
            subscriptions[subscriptionId] = result
            self.lastError = nil
            return subscriptionId
        } catch {
            self.lastError = "Failed to subscribe: \(error.localizedDescription)"
            return nil
        }
    }
    
    /**
     * Unsubscribe from event stream
     * @param subscriptionId Subscription ID
     * @return Returns true on success, false on failure
     */
    public func unsubscribe(_ subscriptionId: String) -> Bool {
        guard let client = self.client else {
            self.lastError = "Client not initialized"
            return false
        }
        
        do {
            try client.unsubscribe(subscriptionId: subscriptionId)
            subscriptions.removeValue(forKey: subscriptionId)
            self.lastError = nil
            return true
        } catch {
            self.lastError = "Failed to unsubscribe: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Event Management
    
    /**
     * Publish a generic event with specified kind
     * @param kind Event kind (e.g., 1 for text note, 0 for metadata, etc.)
     * @param content Event content
     * @param tags Optional tags array
     * @return Returns event ID on success, nil on failure
     */
    public func publishEvent(kind: UInt16, content: String, tags: [[String]]? = nil) -> String? {
        guard let client = self.client else {
            self.lastError = "Client not initialized"
            return nil
        }
        
        guard isConnected else {
            self.lastError = "Not connected to relay servers"
            return nil
        }
        
        do {
            let eventId = try client.publishEvent(kind: kind, content: content, tags: tags)
            self.lastError = nil
            return eventId
        } catch {
            self.lastError = "Failed to publish event: \(error.localizedDescription)"
            return nil
        }
    }
    
    /**
     * Fetch events based on filter
     * @param filter Event filter criteria
     * @param timeoutSeconds Timeout in seconds
     * @return Array of events matching the filter
     */
    public func fetchEvents(filter: NostrFilter, timeoutSeconds: UInt64 = 10) -> [NostrEvent] {
        guard let client = self.client else {
            self.lastError = "Client not initialized"
            return []
        }
        
        do {
            let events = try client.fetchEvents(filter: filter, timeoutSeconds: timeoutSeconds)
            self.lastError = nil
            return events
        } catch {
            self.lastError = "Failed to fetch events: \(error.localizedDescription)"
            return []
        }
    }
    
    // MARK: - Utility Methods
    
    /**
     * Check if ready to publish events
     * @return Returns true if ready, false otherwise
     */
    public var canPublish: Bool {
        return client != nil && keys != nil && isConnected
    }
    
    /**
     * Get current status description
     * @return Status description string
     */
    public func getStatusDescription() -> String {
        if keys == nil {
            return "Keys not generated"
        } else if client == nil {
            return "Client not initialized"
        } else if !isConnected {
            return "Not connected to relays"
        } else {
            return "Ready"
        }
    }
    
    /**
     * Clean up resources
     */
    public func cleanup() {
        // Cancel all subscriptions
        for subscriptionId in subscriptions.keys {
            _ = unsubscribe(subscriptionId)
        }
        
        // Disconnect
        _ = disconnect()
        
        // Clean up state
        client = nil
        keys = nil
        subscriptions.removeAll()
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Cleaned up"
            self.activeRelays.removeAll()
            self.lastError = nil
        }
    }
}

// MARK: - Extension: Convenience Methods

extension NostrUtils {
    
    /**
     * Quick setup and connect convenience method
     */
    public func quickSetupAndConnect() -> Bool {
        guard quickSetup() else {
            print("❌ Quick setup failed")
            return false
        }
        
        guard connect() else {
            print("❌ Connection failed")
            return false
        }
        
        print("✅ Setup and connection successful")
        return true
    }
    
    /**
     * Reset all keys and data (for testing or starting fresh)
     * @return Returns true on success, false on failure
     */
    public func resetAllData() -> Bool {
        // 1. Clean up current session
        cleanup()
        
        // 2. Delete stored private key
        let deleteSuccess = deleteStoredPrivateKey()
        
        if deleteSuccess {
            print("✅ All data reset successfully")
            return true
        } else {
            print("⚠️ Failed to delete stored private key")
            return false
        }
    }
    
    /**
     * Quick post: setup, connect and publish an event
     * @param kind Event kind
     * @param content Event content to publish
     * @param tags Optional tags
     * @return Returns event ID on success, nil on failure
     */
    public func quickPublish(kind: UInt16, content: String, tags: [[String]]? = nil) -> String? {
        guard quickSetupAndConnect() else {
            return nil
        }
        
        return publishEvent(kind: kind, content: content, tags: tags)
    }
    
    /**
     * Create a simple event filter
     * @param kinds Array of event kinds (optional)
     * @param authors Array of author public keys (optional)
     * @param limit Maximum number of events to fetch
     * @param since Unix timestamp to fetch events since (optional)
     * @return NostrFilter configured with specified criteria
     */
    public static func createFilter(kinds: [UInt16]? = nil, authors: [String]? = nil, limit: UInt64 = 20, since: UInt64? = nil) -> NostrFilter {
        return NostrFilter(
            ids: nil,
            authors: authors,
            kinds: kinds,
            since: since,
            until: nil,
            limit: limit,
            search: nil
        )
    }
    
    /**
     * Create a filter for a specific event
     * @param eventId The event ID to fetch
     * @return NostrFilter configured for the specific event
     */
    public static func createEventFilter(eventId: String) -> NostrFilter {
        return NostrFilter(
            ids: [eventId],
            authors: nil,
            kinds: nil,
            since: nil,
            until: nil,
            limit: 1,
            search: nil
        )
    }
    
    /**
     * Create a filter for user's profile events
     * @param pubkey User's public key
     * @return NostrFilter configured for metadata events
     */
    public static func createProfileFilter(pubkey: String) -> NostrFilter {
        return NostrFilter(
            ids: nil,
            authors: [pubkey],
            kinds: [0], // Metadata events
            since: nil,
            until: nil,
            limit: 1,
            search: nil
        )
    }
} 