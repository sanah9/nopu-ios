//
//  CreateSubscriptionView.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import SwiftUI

struct CreateSubscriptionView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = SubscriptionViewModel()
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    // UI input states
    @State private var newEventId = ""
    @State private var newAuthor = ""
    @State private var newKind = ""
    @State private var newTagKey = ""
    @State private var newTagValue = ""
    @State private var newRelay = ""
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Settings
                Section("Basic Settings") {
                    TextField("Topic name, e.g. nopu_alerts", text: $viewModel.topicName)
                        .disableAutocorrection(true)
                }
                
                DisclosureGroup("Use another push server", isExpanded: $viewModel.useAnotherServer) {
                    TextField("Push server URL, e.g. https://nopu.sh", text: $viewModel.serverURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                // Basic Push Options
                DisclosureGroup("Use basic push options", isExpanded: $viewModel.enableBasicOptions) {
                    Section("User Public Key") {
                        TextField("Enter your public key (npub or hex format)", text: $viewModel.userPubkey)
                            .font(.system(.caption, design: .monospaced))
                            .disableAutocorrection(true)
                            .autocapitalization(.none)
                    }
                    
                    Section("Interaction Notifications") {
                        NotificationToggle(
                            title: "Like notifications",
                            subtitle: "Notify when someone likes your notes",
                            isOn: $viewModel.notifyOnLikes
                        )
                        
                        NotificationToggle(
                            title: "Repost notifications",
                            subtitle: "Notify when someone reposts your notes",
                            isOn: $viewModel.notifyOnReposts
                        )
                        
                        NotificationToggle(
                            title: "Reply notifications", 
                            subtitle: "Notify when someone replies to your notes",
                            isOn: $viewModel.notifyOnReplies
                        )
                        
                        NotificationToggle(
                            title: "Zap notifications",
                            subtitle: "Notify when someone sends you a zap",
                            isOn: $viewModel.notifyOnZaps
                        )
                    }
                    
                    Section("Social Notifications") {
                        NotificationToggle(
                            title: "Following posts",
                            subtitle: "Notify when people you follow post new notes",
                            isOn: $viewModel.notifyOnFollowsPosts
                        )
                        
                        NotificationToggle(
                            title: "Direct messages",
                            subtitle: "Notify when you receive direct messages",
                            isOn: $viewModel.notifyOnDMs
                        )
                    }
                } // End of "Use basic push options" DisclosureGroup
                
                // Advanced Filters
                DisclosureGroup("Use advanced filters", isExpanded: $viewModel.useAdvancedFilters) {
                    // Event IDs
                    Section("Event IDs") {
                        ForEach(viewModel.unifiedFilter.eventIds.indices, id: \.self) { index in
                            FilterItemRow(
                                text: viewModel.unifiedFilter.eventIds[index],
                                onRemove: { viewModel.unifiedFilter.eventIds.remove(at: index) }
                            )
                        }
                        
                        AddItemRow(
                            placeholder: "Add event ID",
                            text: $newEventId,
                            onAdd: {
                                if !newEventId.isEmpty {
                                    viewModel.unifiedFilter.eventIds.append(newEventId)
                                    newEventId = ""
                                }
                            }
                        )
                    }
                    
                    // Author Pubkeys
                    Section("Author Pubkeys") {
                        ForEach(viewModel.unifiedFilter.authors.indices, id: \.self) { index in
                            FilterItemRow(
                                text: viewModel.unifiedFilter.authors[index],
                                onRemove: { viewModel.unifiedFilter.authors.remove(at: index) }
                            )
                        }
                        
                        AddItemRow(
                            placeholder: "Add author pubkey",
                            text: $newAuthor,
                            onAdd: {
                                if !newAuthor.isEmpty {
                                    viewModel.unifiedFilter.authors.append(newAuthor)
                                    newAuthor = ""
                                }
                            }
                        )
                    }
                    
                    // Kinds
                    Section("Event Kinds") {
                        ForEach(viewModel.unifiedFilter.kinds.indices, id: \.self) { index in
                            FilterItemRow(
                                text: "\(viewModel.unifiedFilter.kinds[index])",
                                onRemove: { viewModel.unifiedFilter.kinds.remove(at: index) }
                            )
                        }
                        
                        HStack {
                            TextField("Add kind number", text: $newKind)
                                .keyboardType(.numberPad)
                                .disableAutocorrection(true)
                            Button("Add") {
                                if let kind = Int(newKind) {
                                    viewModel.unifiedFilter.kinds.append(kind)
                                    viewModel.unifiedFilter.kinds.sort()
                                    newKind = ""
                                }
                            }
                            .disabled(newKind.isEmpty)
                        }
                    }
                    
                    // Tag Filters
                    Section("Tag Filters") {
                        ForEach(viewModel.unifiedFilter.tags) { tag in
                            TagFilterView(
                                tag: tag,
                                onRemove: { viewModel.unifiedFilter.tags.removeAll { $0.id == tag.id } }
                            )
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
                                    viewModel.addTagFilter(key: newTagKey, value: newTagValue)
                                    newTagKey = ""
                                    newTagValue = ""
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
                            Toggle("", isOn: $viewModel.useSinceDate)
                        }
                        
                        if viewModel.useSinceDate {
                            DatePicker("Start time", selection: Binding(
                                get: { viewModel.unifiedFilter.sinceDate ?? Date() },
                                set: { viewModel.unifiedFilter.sinceDate = $0 }
                            ), displayedComponents: [.date, .hourAndMinute])
                        }
                        
                        HStack {
                            Text("Set end time")
                            Spacer()
                            Toggle("", isOn: $viewModel.useUntilDate)
                        }
                        
                        if viewModel.useUntilDate {
                            DatePicker("End time", selection: Binding(
                                get: { viewModel.unifiedFilter.untilDate ?? Date() },
                                set: { viewModel.unifiedFilter.untilDate = $0 }
                            ), displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                    
                    // Relay Servers
                    Section("Relay Servers") {
                        ForEach(viewModel.unifiedFilter.relays.indices, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(viewModel.unifiedFilter.relays[index])
                                            .font(.system(.body, design: .monospaced))
                                        Text("Relay #\(index + 1)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button("Remove") {
                                        viewModel.unifiedFilter.relays.remove(at: index)
                                    }
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                            }
                        }
                        
                        HStack {
                            TextField("e.g. wss://relay.damus.io", text: $newRelay)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            Button("Add") {
                                if !newRelay.isEmpty && viewModel.isValidWebSocketURL(newRelay) {
                                    viewModel.unifiedFilter.relays.append(newRelay)
                                    newRelay = ""
                                }
                            }
                            .disabled(newRelay.isEmpty || !viewModel.isValidWebSocketURL(newRelay))
                        }
                        
                        if viewModel.unifiedFilter.relays.isEmpty {
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
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Subscribe") {
                        // Create and save subscription
                        let subscription = Subscription(
                            topicName: viewModel.topicName,
                            serverURL: viewModel.useAnotherServer ? viewModel.serverURL : nil
                        )
                        subscriptionManager.addSubscription(subscription)
                        
                        // Build subscription config for API call (for future implementation)
                        let config = viewModel.buildSubscriptionConfig()
                        print("Subscription config:", config)
                        
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(viewModel.topicName.isEmpty)
                }
            }
        }
    }
}

// MARK: - UI Components

struct NotificationToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: $isOn)
                .fixedSize()
        }
    }
}

struct FilterItemRow: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            Spacer()
            Button("Remove") {
                onRemove()
            }
            .foregroundColor(.red)
            .font(.caption)
            .buttonStyle(BorderlessButtonStyle())
        }
    }
}

struct AddItemRow: View {
    let placeholder: String
    @Binding var text: String
    let onAdd: () -> Void
    
    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .disableAutocorrection(true)
            Button("Add") {
                onAdd()
            }
            .disabled(text.isEmpty)
        }
    }
}

struct TagFilterView: View {
    let tag: SubscriptionViewModel.TagFilter
    let onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("#\(tag.key)")
                    .font(.headline)
                Spacer()
                Button("Remove tag") {
                    onRemove()
                }
                .foregroundColor(.red)
                .font(.caption)
                .buttonStyle(BorderlessButtonStyle())
            }
            
            ForEach(tag.values, id: \.self) { value in
                Text("  • \(value)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
} 