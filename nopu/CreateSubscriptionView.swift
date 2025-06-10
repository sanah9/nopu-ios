//
//  CreateSubscriptionView.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import SwiftUI

struct CreateSubscriptionView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var topicName = ""
    @State private var useAnotherServer = false
    @State private var serverURL = ""
    
    // Basic push options
    @State private var enableBasicOptions = false
    @State private var notifyOnLikes = false
    @State private var notifyOnReposts = false
    @State private var notifyOnReplies = false
    @State private var notifyOnZaps = false
    @State private var notifyOnFollowsPosts = false
    @State private var notifyOnDMs = false
    @State private var userPubkey = ""
    
    // UI state for advanced filters
    @State private var useAdvancedFilters = false
    @State private var newEventId = ""
    @State private var newAuthor = ""
    @State private var newKind = ""
    @State private var newTagKey = ""
    @State private var newTagValue = ""
    @State private var useSinceDate = false
    @State private var useUntilDate = false
    @State private var newRelay = ""
    
    struct TagFilter: Identifiable {
        let id = UUID()
        var key: String
        var values: [String]
    }
    
    // Unified filter structure
    @State private var unifiedFilter = NostrFilter()
    
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
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Settings
                Section("Basic Settings") {
                    TextField("Topic name, e.g. nopu_alerts", text: $topicName)
                        .disableAutocorrection(true)
                }
                
                DisclosureGroup("Use another push server", isExpanded: $useAnotherServer) {
                    TextField("Push server URL, e.g. https://nopu.sh", text: $serverURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                // Basic Push Options
                DisclosureGroup("Use basic push options", isExpanded: $enableBasicOptions) {
                    Section("User Public Key") {
                        TextField("Enter your public key (hex format)", text: $userPubkey)
                            .font(.system(.caption, design: .monospaced))
                            .disableAutocorrection(true)
                            .autocapitalization(.none)
                    }
                    
                    Section("Interaction Notifications") {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Like notifications")
                                Text("Notify when someone likes your notes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Toggle("", isOn: $notifyOnLikes)
                                .fixedSize()
                        }
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Repost notifications")
                                Text("Notify when someone reposts your notes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Toggle("", isOn: $notifyOnReposts)
                                .fixedSize()
                        }
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reply notifications")
                                Text("Notify when someone replies to your notes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Toggle("", isOn: $notifyOnReplies)
                                .fixedSize()
                        }
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Zap notifications")
                                Text("Notify when someone sends you a zap")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Toggle("", isOn: $notifyOnZaps)
                                .fixedSize()
                        }
                    }
                    
                    Section("Social Notifications") {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Following posts")
                                Text("Notify when people you follow post new notes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Toggle("", isOn: $notifyOnFollowsPosts)
                                .fixedSize()
                        }
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Direct messages")
                                Text("Notify when you receive direct messages")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Toggle("", isOn: $notifyOnDMs)
                                .fixedSize()
                        }
                    }
                }
                
                // Current Filter Preview
                if !unifiedFilter.isEmpty {
                    Section("Current Filter") {
                        VStack(alignment: .leading, spacing: 4) {
                            if !unifiedFilter.kinds.isEmpty {
                                HStack {
                                    Text("Kinds:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(unifiedFilter.kinds.map(String.init).joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            ForEach(unifiedFilter.tags) { tag in
                                HStack {
                                    Text("#\(tag.key):")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(tag.values.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            if !unifiedFilter.authors.isEmpty {
                                HStack {
                                    Text("Authors:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(unifiedFilter.authors.count) pubkeys")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            if unifiedFilter.sinceDate != nil || unifiedFilter.untilDate != nil {
                                HStack {
                                    Text("Time range:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatTimeRange())
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Advanced Filters
                DisclosureGroup("Use advanced filters", isExpanded: $useAdvancedFilters) {
                    // Event IDs
                    Section("Event IDs") {
                        ForEach(unifiedFilter.eventIds.indices, id: \.self) { index in
                            HStack {
                                Text(unifiedFilter.eventIds[index])
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Remove") {
                                    unifiedFilter.eventIds.remove(at: index)
                                }
                                .foregroundColor(.red)
                                .font(.caption)
                            }
                        }
                        
                        HStack {
                            TextField("Add event ID", text: $newEventId)
                                .disableAutocorrection(true)
                            Button("Add") {
                                if !newEventId.isEmpty {
                                    unifiedFilter.eventIds.append(newEventId)
                                    newEventId = ""
                                }
                            }
                            .disabled(newEventId.isEmpty)
                        }
                    }
                    
                    // Author Pubkeys
                    Section("Author Pubkeys") {
                        ForEach(unifiedFilter.authors.indices, id: \.self) { index in
                            HStack {
                                Text(unifiedFilter.authors[index])
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Remove") {
                                    unifiedFilter.authors.remove(at: index)
                                }
                                .foregroundColor(.red)
                                .font(.caption)
                            }
                        }
                        
                        HStack {
                            TextField("Add author pubkey", text: $newAuthor)
                                .disableAutocorrection(true)
                            Button("Add") {
                                if !newAuthor.isEmpty {
                                    unifiedFilter.authors.append(newAuthor)
                                    newAuthor = ""
                                }
                            }
                            .disabled(newAuthor.isEmpty)
                        }
                    }
                    
                    // Kinds
                    Section("Event Kinds") {
                        ForEach(unifiedFilter.kinds.indices, id: \.self) { index in
                            HStack {
                                Text("\(unifiedFilter.kinds[index])")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Remove") {
                                    unifiedFilter.kinds.remove(at: index)
                                }
                                .foregroundColor(.red)
                                .font(.caption)
                            }
                        }
                        
                        HStack {
                            TextField("Add kind number", text: $newKind)
                                .keyboardType(.numberPad)
                                .disableAutocorrection(true)
                            Button("Add") {
                                if let kind = Int(newKind) {
                                    unifiedFilter.kinds.append(kind)
                                    unifiedFilter.kinds.sort()
                                    newKind = ""
                                }
                            }
                            .disabled(newKind.isEmpty)
                        }
                    }
                    
                    // Tag Filters
                    Section("Tag Filters") {
                        ForEach(unifiedFilter.tags) { tag in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("#\(tag.key)")
                                        .font(.headline)
                                    Spacer()
                                    Button("Remove tag") {
                                        unifiedFilter.tags.removeAll { $0.id == tag.id }
                                    }
                                    .foregroundColor(.red)
                                    .font(.caption)
                                }
                                
                                ForEach(tag.values, id: \.self) { value in
                                    Text("  • \(value)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        VStack(spacing: 8) {
                            HStack {
                                TextField("Tag key (a-z)", text: $newTagKey)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                TextField("Tag value", text: $newTagValue)
                                    .disableAutocorrection(true)
                            }
                            HStack {
                                Spacer()
                                Button("Add") {
                                    addTagFilter()
                                }
                                .disabled(newTagKey.isEmpty || newTagValue.isEmpty)
                            }
                        }
                    }
                    
                    // Time Range
                    Section("Time Range") {
                        HStack {
                            Text("Set start time")
                            Spacer()
                            Toggle("", isOn: $useSinceDate)
                        }
                        
                        if useSinceDate {
                            DatePicker("Start time", selection: Binding(
                                get: { unifiedFilter.sinceDate ?? Date() },
                                set: { unifiedFilter.sinceDate = $0 }
                            ), displayedComponents: [.date, .hourAndMinute])
                        }
                        
                        HStack {
                            Text("Set end time")
                            Spacer()
                            Toggle("", isOn: $useUntilDate)
                        }
                        
                        if useUntilDate {
                            DatePicker("End time", selection: Binding(
                                get: { unifiedFilter.untilDate ?? Date() },
                                set: { unifiedFilter.untilDate = $0 }
                            ), displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                    
                    // Relay Servers
                    Section("Relay Servers") {
                        ForEach(unifiedFilter.relays.indices, id: \.self) { index in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(unifiedFilter.relays[index])
                                        .font(.system(.body, design: .monospaced))
                                    Text("Relay #\(index + 1)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Remove") {
                                    unifiedFilter.relays.remove(at: index)
                                }
                                .foregroundColor(.red)
                                .font(.caption)
                            }
                        }
                        
                        HStack {
                            TextField("e.g. wss://relay.damus.io", text: $newRelay)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            Button("Add") {
                                if !newRelay.isEmpty && isValidWebSocketURL(newRelay) {
                                    unifiedFilter.relays.append(newRelay)
                                    newRelay = ""
                                }
                            }
                            .disabled(newRelay.isEmpty || !isValidWebSocketURL(newRelay))
                        }
                        
                        if unifiedFilter.relays.isEmpty {
                            Text("Default server will be used when no relays are specified")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .onChange(of: notifyOnLikes) {
                syncBasicOptionsToAdvancedFilters()
            }
            .onChange(of: notifyOnReposts) {
                syncBasicOptionsToAdvancedFilters()
            }
            .onChange(of: notifyOnReplies) {
                syncBasicOptionsToAdvancedFilters()
            }
            .onChange(of: notifyOnZaps) {
                syncBasicOptionsToAdvancedFilters()
            }
            .onChange(of: notifyOnFollowsPosts) {
                syncBasicOptionsToAdvancedFilters()
            }
            .onChange(of: notifyOnDMs) {
                syncBasicOptionsToAdvancedFilters()
            }
            .onChange(of: userPubkey) {
                syncBasicOptionsToAdvancedFilters()
            }
            .navigationTitle("Add subscription")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.green)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Subscribe") {
                        // Add subscription logic
                        let config = buildSubscriptionConfig()
                        print("Subscription config:", config)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.secondary)
                    .disabled(topicName.isEmpty || (hasBasicOptionsSelected() && userPubkey.isEmpty))
                }
            }
        }
    }
    
    private func syncBasicOptionsToAdvancedFilters() {
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
    
    private func hasBasicOptionsSelected() -> Bool {
        return notifyOnLikes || notifyOnReposts || notifyOnReplies || 
               notifyOnZaps || notifyOnFollowsPosts || notifyOnDMs || 
               !userPubkey.isEmpty
    }
    
    private func clearSyncedFilters() {
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
    
    private func addTagFilter() {
        let key = newTagKey.lowercased()
        let value = newTagValue
        
        if let existingIndex = unifiedFilter.tags.firstIndex(where: { $0.key == key }) {
            unifiedFilter.tags[existingIndex].values.append(value)
        } else {
            unifiedFilter.tags.append(TagFilter(key: key, values: [value]))
        }
        
        newTagKey = ""
        newTagValue = ""
    }
    
    private func formatTimeRange() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        var range = ""
        if let since = unifiedFilter.sinceDate {
            range += "from \(formatter.string(from: since))"
        }
        if let until = unifiedFilter.untilDate {
            if !range.isEmpty { range += " " }
            range += "until \(formatter.string(from: until))"
        }
        return range
    }
    
    private func buildNostrFilter() -> [String: Any] {
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
    
    private func buildSubscriptionConfig() -> [String: Any] {
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
    
    private func isValidWebSocketURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "ws" || url.scheme == "wss"
    }
} 