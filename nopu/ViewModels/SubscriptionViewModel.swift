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
    
    // MARK: - NIP-29 Group Management
    
    func buildAboutJsonString() -> String {
        let filterConfig = buildNostrFilter()
        
        do {
            // Build REQ format array: ["REQ", subscription_id, filter1, filter2, ...]
            let subscriptionId: String
            if let token = PushTokenManager.shared.token, !token.isEmpty {
                subscriptionId = token
            } else {
                subscriptionId = UUID().uuidString.lowercased()
            }
            var reqArray: [Any] = ["REQ", subscriptionId]
            
            if let filters = filterConfig["filters"] as? [[String: Any]] {
                reqArray.append(contentsOf: filters)
            } else if !filterConfig.isEmpty {
                reqArray.append(filterConfig)
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: reqArray, options: [])
            return String(data: jsonData, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
    
    private func createNIP29Group(groupId: String, groupName: String, aboutJsonString: String, completion: @escaping (Bool, String?) -> Void) {
        // Create NIP-29 group using NostrUtils
        guard NostrManager.shared.isConnected else {
            completion(false, nil)
            return
        }
        
        // Step 1: Create group with kind 9007 event
        // Only h tag is needed for group creation
        let createGroupTags: [[String]] = [
            ["h", groupId]
        ]
        
        // Publish kind 9007 event to create the group
        guard NostrManager.shared.publishEvent(
            kind: 9007,
            content: "Create topic group: \(groupName)",
            tags: createGroupTags
        ) != nil else {
            completion(false, nil)
            return
        }
        
        let delay: TimeInterval = 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.updateGroupConfig(groupId: groupId, groupName: groupName, aboutJsonString: aboutJsonString) { success, eventId in
                completion(success, eventId)
            }
        }
    }
    
    func updateGroupConfig(groupId: String, groupName: String, aboutJsonString: String, completion: @escaping (Bool, String?) -> Void) {
        guard NostrManager.shared.isConnected else {
            completion(false, nil)
            return
        }
        
        // Set group configuration tags
        let configTags: [[String]] = [
            ["h", groupId],           // Group identifier
            ["name", groupName],      // Group name
            ["about", aboutJsonString], // NostrFilter as JSON string
            ["private"],
            ["closed"]
        ]
        
        // Publish kind 9002 event to update group configuration
        if let configEventId = NostrManager.shared.publishEvent(
            kind: 9002,
            content: "Update topic group: \(groupName)",
            tags: configTags
        ) {
            completion(true, configEventId)
        } else {
            completion(false, nil)
        }
    }
    
    func createSubscriptionWithGroup(subscriptionManager: SubscriptionManager, completion: @escaping (Bool) -> Void) {
        // Generate a unique group ID
        let groupId = UUID().uuidString.lowercased()
        
        // Build about JSON string first
        let aboutJsonString = buildAboutJsonString()
        
        // Create NIP-29 group creation event (kind 9007)
        createNIP29Group(groupId: groupId, groupName: topicName, aboutJsonString: aboutJsonString) { [weak self] success, eventId in
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
        NostrManager.shared.fetchEvents(filter: filter, timeoutSeconds: 10)
            .sink { completion in
                print("Event subscription completed: \(completion)")
            } receiveValue: { event in
                print("Received event - ID: \(event.id)")
            }
            .store(in: &cancellables)
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
