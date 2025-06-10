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
            VStack(spacing: 0) {
                Form {
                    // Basic Settings
                    Section("Basic Settings") {
                        TextField("Topic name, e.g. nopu_alerts", text: $topicName)
                    }
                    
                    Section {
                        HStack {
                            Text("Use another push server")
                            Spacer()
                            Toggle("", isOn: $useAnotherServer)
                        }
                    }
                    
                    if useAnotherServer {
                        Section {
                            TextField("Push server URL, e.g. https://nopu.sh", text: $serverURL)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                        }
                    }
                    
                    // Advanced Filters
                    Section {
                        HStack {
                            Text("Enable advanced filters (Nostr filter)")
                            Spacer()
                            Toggle("", isOn: $useAdvancedFilters)
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
                                HStack(spacing: 8) {
                                    TextField("Tag key (a-z)", text: $newTagKey)
                                        .textInputAutocapitalization(.never)
                                        .frame(maxWidth: 120)
                                    TextField("Tag value", text: $newTagValue)
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
                    .disabled(topicName.isEmpty)
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