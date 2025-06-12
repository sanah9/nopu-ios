import SwiftUI
import Foundation

class SubscriptionViewModel: ObservableObject {
    // Basic subscription info
    @Published var topicName = ""
    @Published var serverURL = ""
    @Published var useAnotherServer = false
    
    // UI unified filter
    @Published var unifiedFilter = UINostrFilter()
    
    // Time filter controls
    @Published var useSinceDate = false
    @Published var useUntilDate = false
    
    // Basic push options
    @Published var enableBasicOptions = false
    @Published var notifyOnLikes = false
    @Published var notifyOnReposts = false
    @Published var notifyOnReplies = false
    @Published var notifyOnZaps = false
    @Published var notifyOnFollowsPosts = false
    @Published var notifyOnDMs = false
    @Published var userPubkey = ""
    
    // UI state for advanced filters
    @Published var useAdvancedFilters = false
    
    struct UINostrFilter {
        var eventIds: [String] = []
        var authors: [String] = []
        var kinds: [Int] = []
        var tags: [TagFilter] = []
        var sinceDate: Date? = nil
        var untilDate: Date? = nil
        var relays: [String] = []
        
        var isEmpty: Bool {
            return eventIds.isEmpty && authors.isEmpty && kinds.isEmpty && 
                   tags.isEmpty && sinceDate == nil && untilDate == nil
        }
    }
    
    struct TagFilter: Identifiable {
        let id = UUID()
        var key: String
        var values: [String]
    }
    
    init() {
        // Default configuration
        // Add some common event kinds
        unifiedFilter.kinds = [1, 7, 6, 9735] // Text Notes, Likes, Reposts, Zaps
        
        // Add default relay
        unifiedFilter.relays = ["ws://127.0.0.1:8080"]
        
        // Set up observers for basic options changes
        setupObservers()
    }
    
    private func setupObservers() {
        // Use Combine to observe changes and sync filters
        Publishers.CombineLatest4($notifyOnLikes, $notifyOnReposts, $notifyOnReplies, $notifyOnZaps)
            .sink { [weak self] _ in
                self?.syncBasicOptionsToAdvancedFilters()
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest3($notifyOnFollowsPosts, $notifyOnDMs, $userPubkey)
            .sink { [weak self] _ in
                self?.syncBasicOptionsToAdvancedFilters()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Basic Options Sync
    
    func syncBasicOptionsToAdvancedFilters() {
        // Clear previous sync settings while preserving manually added settings
        let basicKinds: Set<Int> = [1, 6, 7, 1059, 9735]
        var newKinds: Set<Int> = Set(unifiedFilter.kinds.filter { !basicKinds.contains($0) })
        var newTags: [TagFilter] = unifiedFilter.tags.compactMap { tag in
            if tag.key == "p" && !userPubkey.isEmpty {
                let filteredValues = tag.values.filter { $0 != userPubkey }
                if filteredValues.isEmpty {
                    return nil
                } else {
                    return TagFilter(key: tag.key, values: filteredValues)
                }
            }
            return tag
        }
        
        // Re-add filters based on basic options
        // Like notifications (kind 7, #p tag)
        if notifyOnLikes {
            newKinds.insert(7)
        }
        
        // Repost notifications (kind 6, #p tag)  
        if notifyOnReposts {
            newKinds.insert(6)
        }
        
        // Reply notifications (kind 1, #p tag)
        if notifyOnReplies {
            newKinds.insert(1)
        }
        
        // Zap notifications (kind 9735, #p tag)
        if notifyOnZaps {
            newKinds.insert(9735)
        }
        
        // Following posts (kind 1)
        if notifyOnFollowsPosts {
            newKinds.insert(1)
            // Note: Need to get user's following list, only adding kind for now
        }
        
        // Direct message notifications (kind 1059, #p tag)
        if notifyOnDMs {
            newKinds.insert(1059)
        }
        
        // Add user pubkey to #p tag if any notification type is selected and pubkey is provided
        if !userPubkey.isEmpty && (notifyOnLikes || notifyOnReposts || notifyOnReplies || notifyOnZaps || notifyOnDMs) {
            setUserPubkeyTag(&newTags, value: userPubkey)
        }
        
        // Update unified filter
        unifiedFilter.kinds = Array(newKinds).sorted()
        unifiedFilter.tags = newTags
    }
    
    // MARK: - Tag Management
    
    func addTagFilter(key: String, value: String) {
        if let existingIndex = unifiedFilter.tags.firstIndex(where: { $0.key == key }) {
            // Tag already exists, add value
            if !unifiedFilter.tags[existingIndex].values.contains(value) {
                unifiedFilter.tags[existingIndex].values.append(value)
            }
        } else {
            // New tag
            unifiedFilter.tags.append(TagFilter(key: key, values: [value]))
        }
    }
    
    private func addOrUpdateTag(_ tags: inout [TagFilter], key: String, value: String) {
        if let existingIndex = tags.firstIndex(where: { $0.key == key }) {
            if !tags[existingIndex].values.contains(value) {
                tags[existingIndex].values.append(value)
            }
        } else {
            tags.append(TagFilter(key: key, values: [value]))
        }
    }
    
    private func setUserPubkeyTag(_ tags: inout [TagFilter], value: String) {
        // Remove existing p tag for user pubkey
        tags.removeAll { $0.key == "p" }
        // Add new p tag with user pubkey
        tags.append(TagFilter(key: "p", values: [value]))
    }
    
    // MARK: - Helper Functions
    
    func hasBasicOptionsSelected() -> Bool {
        return notifyOnLikes || notifyOnReposts || notifyOnReplies || 
               notifyOnZaps || notifyOnFollowsPosts || notifyOnDMs || 
               !userPubkey.isEmpty
    }
    
    func clearSyncedFilters() {
        // Clear filter settings generated by basic options sync
        let basicKinds: Set<Int> = [1, 6, 7, 1059, 9735]
        unifiedFilter.kinds = unifiedFilter.kinds.filter { !basicKinds.contains($0) }
        
        // Remove p tags related to user pubkey
        unifiedFilter.tags = unifiedFilter.tags.compactMap { tag in
            if tag.key == "p" {
                let filteredValues = tag.values.filter { $0 != userPubkey }
                if filteredValues.isEmpty {
                    return nil
                } else {
                    return TagFilter(key: tag.key, values: filteredValues)
                }
            }
            return tag
        }
    }
    
    func isValidWebSocketURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "ws" || url.scheme == "wss"
    }
    
    // MARK: - Filter Building
    
    func buildNostrFilter() -> [String: Any] {
        // If basic options are selected, build basic filter, otherwise use advanced filter
        if hasBasicOptionsSelected() {
            return buildBasicFilter()
        } else {
            return buildAdvancedFilter()
        }
    }
    
    private func buildBasicFilter() -> [String: Any] {
        var kinds: [Int] = []
        var filter: [String: Any] = [
            "since": Int(Date().timeIntervalSince1970)
        ]
        
        // Collect all selected notification kinds
        if notifyOnLikes {
            kinds.append(7)  // Like notifications
        }
        
        if notifyOnReposts {
            kinds.append(6)  // Repost notifications
        }
        
        if notifyOnReplies {
            kinds.append(1)  // Reply notifications
        }
        
        if notifyOnZaps {
            kinds.append(9735)  // Zap notifications
        }
        
        if notifyOnFollowsPosts {
            if !kinds.contains(1) {
                kinds.append(1)  // Following posts (also kind 1)
            }
        }
        
        if notifyOnDMs {
            kinds.append(1059)  // Direct messages (NIP-44)
            kinds.append(4)     // Direct messages (legacy)
        }
        
        // Set the kinds array
        if !kinds.isEmpty {
            filter["kinds"] = kinds.sorted()
        } else {
            filter["kinds"] = [1]  // Fallback
        }
        
        // Add user pubkey filter if available
        if !userPubkey.isEmpty {
            filter["#p"] = [userPubkey]
        }
        
        return filter
    }
    
    private func buildAdvancedFilter() -> [String: Any] {
        var filter: [String: Any] = [:]
        
        if !unifiedFilter.eventIds.isEmpty {
            filter["ids"] = unifiedFilter.eventIds
        }
        
        if !unifiedFilter.authors.isEmpty {
            filter["authors"] = unifiedFilter.authors
        }
        
        if !unifiedFilter.kinds.isEmpty {
            filter["kinds"] = unifiedFilter.kinds
        }
        
        for tag in unifiedFilter.tags {
            filter["#\(tag.key)"] = tag.values
        }
        
        if useSinceDate, let since = unifiedFilter.sinceDate {
            filter["since"] = Int(since.timeIntervalSince1970)
        }
        
        if useUntilDate, let until = unifiedFilter.untilDate {
            filter["until"] = Int(until.timeIntervalSince1970)
        }
        
        return filter
    }
    
    func buildSubscriptionConfig() -> [String: Any] {
        var config: [String: Any] = [:]
        
        config["topic"] = topicName
        config["filter"] = buildNostrFilter()
        
        if !unifiedFilter.relays.isEmpty {
            config["relays"] = unifiedFilter.relays
        }
        
        if useAnotherServer {
            config["server"] = serverURL
        }
        
        return config
    }
    
    // MARK: - NIP-29 Group Creation
    
    func createSubscriptionWithGroup(subscriptionManager: SubscriptionManager, completion: @escaping (Bool) -> Void) {
        // Generate a unique group ID
        let groupId = UUID().uuidString.lowercased()
        
        // Create NIP-29 group creation event (kind 9007)
        createNIP29Group(groupId: groupId, groupName: topicName) { [weak self] success, eventId in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if success {
                    // Fetch events with kind 20284 and h tag = groupId
                    self.fetchGroupEvents(groupId: groupId)
                    
                    // Create subscription with filter configuration
                    let filters = self.convertUIFilterToNostrFilterConfig()
                    let subscription = Subscription(
                        topicName: self.topicName,
                        groupId: groupId,
                        serverURL: self.useAnotherServer ? self.serverURL : "",
                        filters: filters
                    )
                    subscriptionManager.addSubscription(subscription)
                    
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
    }
    
    private func fetchGroupEvents(groupId: String) {
        // Create filter for kind 20284 events with h tag filtering
        let filter = NostrFilter(
            ids: nil,
            authors: nil,
            kinds: [20284],
            since: UInt64(Date().timeIntervalSince1970),
            until: nil,
            limit: nil,
            search: nil,
            tags: [["h", groupId]]
        )
        
        // Fetch events with h tag filtering applied at Rust layer
        let events = NostrManager.shared.fetchEvents(filter: filter, timeoutSeconds: 10)
        
        // Additional client-side verification (optional) - split into separate parts to help compiler
        let verifiedEvents = events.filter { event in
            let matchingTags = event.tags.filter { tag in
                tag.name == "h" && tag.value == groupId
            }
            return !matchingTags.isEmpty
        }
    }
    
    private func createNIP29Group(groupId: String, groupName: String, completion: @escaping (Bool, String?) -> Void) {
        // Create NIP-29 group using NostrUtils
        guard NostrManager.shared.isConnected else {
            completion(false, nil)
            return
        }
        
        // Build NostrFilter JSON string for about field (just the filter, not REQ format)
        let filterConfig = buildNostrFilter()
        let aboutJsonString: String
        
        do {
            // Build REQ format array: ["REQ", subscription_id, filter1, filter2, ...]
            let subscriptionId = "sub_\(groupId)"
            var reqArray: [Any] = ["REQ", subscriptionId]
            
            if let filters = filterConfig["filters"] as? [[String: Any]] {
                // If already contains multiple filters, add them all
                reqArray.append(contentsOf: filters)
            } else if !filterConfig.isEmpty {
                // If single filter object, add it
                reqArray.append(filterConfig)
            } else {
                // Empty filter case - add a minimal filter
                reqArray.append(["kinds": [1]] as [String: Any])
            }
            
            // JSON encode the REQ array to string for about field
            let jsonData = try JSONSerialization.data(withJSONObject: reqArray, options: [])
            aboutJsonString = String(data: jsonData, encoding: .utf8) ?? "[\"REQ\",\"sub_default\",{\"kinds\":[1]}]"
        } catch {
            aboutJsonString = "[\"REQ\",\"sub_default\",{\"kinds\":[1]}]"
        }
        
        // NIP-29 group creation event tags
        let tags: [[String]] = [
            ["h", groupId],           // Group identifier
            ["name", groupName],      // Group name
            ["about", aboutJsonString], // NostrFilter as JSON string
            ["private"],
            ["closed"]
        ]
        
        // Publish kind 9007 event (NIP-29 group creation)
        if let eventId = NostrManager.shared.publishEvent(kind: 9007, content: "Create topic group: \(groupName)", tags: tags) {
            completion(true, eventId)
        } else {
            completion(false, nil)
        }
    }
    
    // Convert UINostrFilter to NostrFilterConfig
    func convertUIFilterToNostrFilterConfig() -> NostrFilterConfig {
        var config = NostrFilterConfig()
        
        config.eventIds = unifiedFilter.eventIds
        config.authors = unifiedFilter.authors
        config.kinds = unifiedFilter.kinds
        
        // Convert UIFilterTag to dictionary format
        var tagDict: [String: [String]] = [:]
        for tag in unifiedFilter.tags {
            tagDict[tag.key] = tag.values
        }
        config.tags = tagDict
        
        // Convert dates
        config.since = useSinceDate ? unifiedFilter.sinceDate : nil
        config.until = useUntilDate ? unifiedFilter.untilDate : nil
        
        config.relays = unifiedFilter.relays
        
        return config
    }
    
    // Load from NostrFilterConfig to UI
    func loadFromNostrFilterConfig(_ config: NostrFilterConfig) {
        unifiedFilter.eventIds = config.eventIds
        unifiedFilter.authors = config.authors
        unifiedFilter.kinds = config.kinds
        
        // Convert dictionary to UIFilterTag
        unifiedFilter.tags = config.tags.map { key, values in
            TagFilter(key: key, values: values)
        }
        
        // Set dates and states
        if let since = config.since {
            unifiedFilter.sinceDate = since
            useSinceDate = true
        } else {
            useSinceDate = false
        }
        
        if let until = config.until {
            unifiedFilter.untilDate = until
            useUntilDate = true
        } else {
            useUntilDate = false
        }
        
        unifiedFilter.relays = config.relays
    }
}

import Combine