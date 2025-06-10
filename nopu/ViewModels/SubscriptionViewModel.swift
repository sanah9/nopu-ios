import SwiftUI
import Foundation

class SubscriptionViewModel: ObservableObject {
    // Basic settings
    @Published var topicName = ""
    @Published var useAnotherServer = false
    @Published var serverURL = ""
    
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
    @Published var useSinceDate = false
    @Published var useUntilDate = false
    
    // Unified filter structure
    @Published var unifiedFilter = NostrFilter()
    
    struct NostrFilter {
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
        let key = key.lowercased()
        
        if let existingIndex = unifiedFilter.tags.firstIndex(where: { $0.key == key }) {
            unifiedFilter.tags[existingIndex].values.append(value)
        } else {
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
        var filters: [[String: Any]] = []
        
        guard !userPubkey.isEmpty else {
            return [:]
        }
        
        // Like notifications (kind 7)
        if notifyOnLikes {
            filters.append([
                "kinds": [7],
                "#e": [userPubkey], // Assuming userPubkey is also used as event ID
                "since": Int(Date().timeIntervalSince1970)
            ])
        }
        
        // Repost notifications (kind 6)
        if notifyOnReposts {
            filters.append([
                "kinds": [6],
                "#e": [userPubkey],
                "since": Int(Date().timeIntervalSince1970)
            ])
        }
        
        // Reply notifications (kind 1, containing user mentions)
        if notifyOnReplies {
            filters.append([
                "kinds": [1],
                "#p": [userPubkey],
                "since": Int(Date().timeIntervalSince1970)
            ])
        }
        
        // Zap notifications (kind 9735)
        if notifyOnZaps {
            filters.append([
                "kinds": [9735],
                "#p": [userPubkey],
                "since": Int(Date().timeIntervalSince1970)
            ])
        }
        
        // Following posts (kind 1) - This requires knowing who the user follows
        if notifyOnFollowsPosts {
            // Note: Need to get user's following list, leaving empty for now
            // In actual implementation, need to first get user's kind 3 event to get following list
            filters.append([
                "kinds": [1],
                "since": Int(Date().timeIntervalSince1970)
                // "authors": [] // Need to fill in followed users' pubkey list
            ])
        }
        
        // Direct message notifications (kind 4)
        if notifyOnDMs {
            filters.append([
                "kinds": [4],
                "#p": [userPubkey],
                "since": Int(Date().timeIntervalSince1970)
            ])
        }
        
        // If multiple filters exist, return array; if only one, return single object
        if filters.count == 1 {
            return filters[0]
        } else if filters.count > 1 {
            return ["filters": filters]
        } else {
            return [:]
        }
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
}

// MARK: - Combine Import
import Combine 