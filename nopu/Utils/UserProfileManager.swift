import Foundation
import Combine
import NostrSDK

class UserProfileManager: ObservableObject {
    static let shared = UserProfileManager()
    
    private var profileCache: [String: UserProfile] = [:]
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "UserProfileCache"
    
    private var cancellables = Set<AnyCancellable>()
    private var profileRelayPool: RelayPool?
    
    // Profile-specific relays
    private let profileRelays = [
        "wss://relay.damus.io",
        "wss://nos.lol",
        "wss://relay.nostr.band",
        "wss://relay.0xchat.com",
        "wss://yabu.me"
    ]
    
    private init() {
        loadCacheFromUserDefaults()
        setupProfileRelayPool()
    }
    
    // MARK: - Profile Relay Pool Setup
    
    private func setupProfileRelayPool() {
        var relays: [Relay] = []
        for relayUrl in profileRelays {
            if let url = URL(string: relayUrl) {
                do {
                    let relay = try Relay(url: url)
                    relays.append(relay)
                } catch {
                    print("Failed to create relay \(relayUrl): \(error)")
                }
            }
        }
        
        if !relays.isEmpty {
            profileRelayPool = RelayPool(relays: Set(relays), delegate: self)
            profileRelayPool?.connect()
        }
    }
    
    // MARK: - Public Interface
    
    /// Get user display name, return cached immediately if available, then fetch latest async
    func getDisplayName(for pubkey: String, completion: @escaping (String) -> Void) {
        // First return cached value if available
        if let cachedProfile = profileCache[pubkey] {
            completion(cachedProfile.displayName)
        } else {
            // If no cache, return default value first
            completion(String(pubkey.prefix(8)))
        }
        
        // Always fetch latest profile async
        fetchUserProfile(pubkey: pubkey) { [weak self] profile in
            guard let self = self, let profile = profile else { return }
            
            // Check if we got new information
            let shouldUpdate = self.profileCache[pubkey] == nil || 
                              self.profileCache[pubkey]?.name != profile.name ||
                              self.profileCache[pubkey]?.about != profile.about ||
                              self.profileCache[pubkey]?.picture != profile.picture
            
            if shouldUpdate {
                DispatchQueue.main.async {
                    self.cacheProfile(profile)
                    completion(profile.displayName)
                }
            }
        }
    }
    
    /// Synchronously get display name (cache only)
    func getCachedDisplayName(for pubkey: String) -> String {
        if let profile = profileCache[pubkey] {
            return profile.displayName
        }
        return String(pubkey.prefix(8))
    }
    
    /// Prefetch user profile (always fetch latest)
    func prefetchUserProfile(pubkey: String) {
        fetchUserProfile(pubkey: pubkey) { [weak self] profile in
            guard let self = self, let profile = profile else { return }
            DispatchQueue.main.async {
                self.cacheProfile(profile)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchUserProfile(pubkey: String, completion: @escaping (UserProfile?) -> Void) {
        guard let profileRelayPool = profileRelayPool else {
            completion(nil)
            return
        }
        
        // Create filter to get user's kind 0 event
        guard let filter = Filter(
            authors: [pubkey],
            kinds: [0],
            limit: 1
        ) else {
            completion(nil)
            return
        }
        
        // Subscribe to get events
        let subscriptionId = profileRelayPool.subscribe(with: filter)
        
        // Set up timeout
        let timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.cleanupProfileSubscription(subscriptionId)
            completion(nil)
        }
        
        // Store timer for cleanup
        profileEventTimeouts[subscriptionId] = timer
        
        // Store completion for this subscription
        profileEventCompletions[subscriptionId] = completion
    }
    
    private var profileEventTimeouts: [String: Timer] = [:]
    private var profileEventCompletions: [String: (UserProfile?) -> Void] = [:]
    
    private func cleanupProfileSubscription(_ subscriptionId: String) {
        profileEventTimeouts[subscriptionId]?.invalidate()
        profileEventTimeouts.removeValue(forKey: subscriptionId)
        profileEventCompletions.removeValue(forKey: subscriptionId)
        profileRelayPool?.closeSubscription(with: subscriptionId)
    }
    
    private func parseUserProfileFromEvent(event: NostrEvent, subscriptionId: String) {
        do {
            // Parse JSON content
            guard let contentData = event.content.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
                return
            }
            
            let pubkey = event.pubkey
            let name = json["name"] as? String
            let about = json["about"] as? String
            let picture = json["picture"] as? String
            
            let profile = UserProfile(
                pubkey: pubkey,
                name: name,
                about: about,
                picture: picture
            )
            
            // Get completion and cleanup
            if let completion = profileEventCompletions[subscriptionId] {
                cleanupProfileSubscription(subscriptionId)
                completion(profile)
            }
            
        } catch {
            // Silent fail
        }
    }
    
    private func cacheProfile(_ profile: UserProfile) {
        profileCache[profile.pubkey] = profile
        saveCacheToUserDefaults()
    }
    
    // MARK: - Persistence
    
    private func loadCacheFromUserDefaults() {
        guard let data = userDefaults.data(forKey: cacheKey),
              let profiles = try? JSONDecoder().decode([String: UserProfile].self, from: data) else {
            return
        }
        
        profileCache = profiles
    }
    
    private func saveCacheToUserDefaults() {
        guard let data = try? JSONEncoder().encode(profileCache) else { return }
        userDefaults.set(data, forKey: cacheKey)
    }
    
    // MARK: - Cache Management
    
    /// Clear all cache
    func clearAllCache() {
        profileCache.removeAll()
        userDefaults.removeObject(forKey: cacheKey)
    }
}

// MARK: - RelayDelegate

extension UserProfileManager: RelayDelegate {
    func relayStateDidChange(_ relay: Relay, state: Relay.State) {
        // Silent relay state changes
    }
    
    func relay(_ relay: Relay, didReceive response: RelayResponse) {
        switch response {
        case .event:
            break // Events will be handled in didReceive event
        case .eose(_):
            break // End of stored events
        case .closed(let subscriptionId, _):
            cleanupProfileSubscription(subscriptionId)
        default:
            break
        }
    }
    
    func relay(_ relay: Relay, didReceive event: RelayEvent) {
        // Only process kind 0 (metadata) events
        if event.event.kind == EventKind.metadata {
            parseUserProfileFromEvent(event: event.event, subscriptionId: event.subscriptionId)
        }
    }
} 
