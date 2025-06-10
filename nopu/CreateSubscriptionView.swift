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
    @State private var userPubkey = "" // User's public key for filtering related events
    
    // Nostr filter related states
    @State private var useAdvancedFilters = false
    @State private var eventIds: [String] = []
    @State private var newEventId = ""
    @State private var authors: [String] = []
    @State private var newAuthor = ""
    @State private var kinds: [Int] = []
    @State private var newKind = ""
    @State private var tags: [TagFilter] = []
    @State private var newTagKey = ""
    @State private var newTagValue = ""
    @State private var sinceDate: Date? = nil
    @State private var untilDate: Date? = nil
    @State private var useSinceDate = false
    @State private var useUntilDate = false
    @State private var relays: [String] = []
    @State private var newRelay = ""
    
    struct TagFilter: Identifiable {
        let id = UUID()
        var key: String
        var values: [String]
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Settings
                Section("Basic Settings") {
                    TextField("Topic name, e.g. nopu_alerts", text: $topicName)
                        .disableAutocorrection(true)
                }
                
                Section {
                    HStack(spacing: 12) {
                        Text("Use another push server")
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Toggle("", isOn: $useAnotherServer)
                            .fixedSize()
                    }
                }
                
                if useAnotherServer {
                    Section {
                        TextField("Push server URL, e.g. https://nopu.sh", text: $serverURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                
                // Basic Push Options
                Section {
                    HStack(spacing: 12) {
                        Text("Enable basic push options")
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Toggle("", isOn: $enableBasicOptions)
                            .fixedSize()
                    }
                }
                
                if enableBasicOptions {
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
                
                // Advanced Filters
                Section {
                    HStack(spacing: 12) {
                        Text("Enable advanced filters")
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Toggle("", isOn: $useAdvancedFilters)
                            .fixedSize()
                    }
                }
                
                if useAdvancedFilters {
                    // Event IDs
                    Section("Event IDs") {
                        ForEach(eventIds.indices, id: \.self) { index in
                            HStack {
                                Text(eventIds[index])
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Remove") {
                                    eventIds.remove(at: index)
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
                                    eventIds.append(newEventId)
                                    newEventId = ""
                                }
                            }
                            .disabled(newEventId.isEmpty)
                        }
                    }
                    
                    // Author Pubkeys
                    Section("Author Pubkeys") {
                        ForEach(authors.indices, id: \.self) { index in
                            HStack {
                                Text(authors[index])
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Remove") {
                                    authors.remove(at: index)
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
                                    authors.append(newAuthor)
                                    newAuthor = ""
                                }
                            }
                            .disabled(newAuthor.isEmpty)
                        }
                    }
                    
                    // Kinds
                    Section("Event Kinds") {
                        ForEach(kinds.indices, id: \.self) { index in
                            HStack {
                                Text("\(kinds[index])")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Remove") {
                                    kinds.remove(at: index)
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
                                    kinds.append(kind)
                                    newKind = ""
                                }
                            }
                            .disabled(newKind.isEmpty)
                        }
                    }
                    
                    // Tag Filters
                    Section("Tag Filters") {
                        ForEach(tags) { tag in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("#\(tag.key)")
                                        .font(.headline)
                                    Spacer()
                                    Button("Remove tag") {
                                        tags.removeAll { $0.id == tag.id }
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
                                get: { sinceDate ?? Date() },
                                set: { sinceDate = $0 }
                            ), displayedComponents: [.date, .hourAndMinute])
                        }
                        
                        HStack {
                            Text("Set end time")
                            Spacer()
                            Toggle("", isOn: $useUntilDate)
                        }
                        
                        if useUntilDate {
                            DatePicker("End time", selection: Binding(
                                get: { untilDate ?? Date() },
                                set: { untilDate = $0 }
                            ), displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                    
                    // Relay Servers
                    Section("Relay Servers") {
                        ForEach(relays.indices, id: \.self) { index in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(relays[index])
                                        .font(.system(.body, design: .monospaced))
                                    Text("Relay #\(index + 1)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Remove") {
                                    relays.remove(at: index)
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
                                    relays.append(newRelay)
                                    newRelay = ""
                                }
                            }
                            .disabled(newRelay.isEmpty || !isValidWebSocketURL(newRelay))
                        }
                        
                        if relays.isEmpty {
                            Text("Default server will be used when no relays are specified")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
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
                    .disabled(topicName.isEmpty || (enableBasicOptions && userPubkey.isEmpty))
                }
            }
        }
    }
    
    private func addTagFilter() {
        let key = newTagKey.lowercased()
        let value = newTagValue
        
        if let existingIndex = tags.firstIndex(where: { $0.key == key }) {
            tags[existingIndex].values.append(value)
        } else {
            tags.append(TagFilter(key: key, values: [value]))
        }
        
        newTagKey = ""
        newTagValue = ""
    }
    
    private func buildNostrFilter() -> [String: Any] {
        // If basic options are enabled, build basic filter, otherwise use advanced filter
        if enableBasicOptions {
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
        
        if !eventIds.isEmpty {
            filter["ids"] = eventIds
        }
        
        if !authors.isEmpty {
            filter["authors"] = authors
        }
        
        if !kinds.isEmpty {
            filter["kinds"] = kinds
        }
        
        for tag in tags {
            filter["#\(tag.key)"] = tag.values
        }
        
        if useSinceDate, let since = sinceDate {
            filter["since"] = Int(since.timeIntervalSince1970)
        }
        
        if useUntilDate, let until = untilDate {
            filter["until"] = Int(until.timeIntervalSince1970)
        }
        
        return filter
    }
    
    private func buildSubscriptionConfig() -> [String: Any] {
        var config: [String: Any] = [:]
        
        config["topic"] = topicName
        config["filter"] = buildNostrFilter()
        
        if !relays.isEmpty {
            config["relays"] = relays
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