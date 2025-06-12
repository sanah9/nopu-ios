//
//  EditSubscriptionView.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import SwiftUI

struct EditSubscriptionView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = SubscriptionViewModel()
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    let subscription: Subscription
    
    // UI input states
    @State private var newEventId = ""
    @State private var newAuthor = ""
    @State private var newKind = ""
    @State private var newTagKey = ""
    @State private var newTagValue = ""
    @State private var newRelay = ""
    
    init(subscription: Subscription, subscriptionManager: SubscriptionManager) {
        self.subscription = subscription
        self.subscriptionManager = subscriptionManager
    }
    
    var body: some View {
        Form {
                // Basic info (read-only)
                Section("Subscription Info") {
                    HStack {
                        Text("Topic Name")
                        Spacer()
                        Text(subscription.topicName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Group ID")
                        Spacer()
                        Text(subscription.groupId)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Server")
                        Spacer()
                        Text(subscription.serverURL.isEmpty ? "Default" : subscription.serverURL)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(subscription.createdAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Filter configuration
                Section("Filter Configuration") {
                    // Event IDs
                    DisclosureGroup("Event IDs") {
                        ForEach(viewModel.unifiedFilter.eventIds.indices, id: \.self) { index in
                            FilterItemRow(
                                text: viewModel.unifiedFilter.eventIds[index],
                                onRemove: { viewModel.unifiedFilter.eventIds.remove(at: index) }
                            )
                        }
                        
                        AddItemRow(
                            placeholder: "Add Event ID",
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
                    DisclosureGroup("Author Pubkeys") {
                        ForEach(viewModel.unifiedFilter.authors.indices, id: \.self) { index in
                            FilterItemRow(
                                text: viewModel.unifiedFilter.authors[index],
                                onRemove: { viewModel.unifiedFilter.authors.remove(at: index) }
                            )
                        }
                        
                        AddItemRow(
                            placeholder: "Add Author Pubkey",
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
                    DisclosureGroup("Event Kinds") {
                        ForEach(viewModel.unifiedFilter.kinds.indices, id: \.self) { index in
                            HStack {
                                Text(kindDescription(viewModel.unifiedFilter.kinds[index]))
                                Spacer()
                                Button("Remove") {
                                    viewModel.unifiedFilter.kinds.remove(at: index)
                                }
                                .foregroundColor(.red)
                                .font(.caption)
                            }
                        }
                        
                        HStack {
                            TextField("Event Kind Number", text: $newKind)
                                .keyboardType(.numberPad)
                            Button("Add") {
                                if let kind = Int(newKind), !newKind.isEmpty {
                                    viewModel.unifiedFilter.kinds.append(kind)
                                    newKind = ""
                                }
                            }
                            .disabled(newKind.isEmpty || Int(newKind) == nil)
                        }
                    }
                    
                    // Tags
                    DisclosureGroup("Tag Filters") {
                        ForEach(viewModel.unifiedFilter.tags) { tag in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("#\(tag.key)")
                                        .font(.headline)
                                    Spacer()
                                    Button("Delete Tag") {
                                        viewModel.unifiedFilter.tags.removeAll { $0.id == tag.id }
                                    }
                                    .foregroundColor(.red)
                                    .font(.caption)
                                }
                                
                                ForEach(tag.values.indices, id: \.self) { valueIndex in
                                    HStack {
                                        Text(tag.values[valueIndex])
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Button("Remove") {
                                            if let tagIndex = viewModel.unifiedFilter.tags.firstIndex(where: { $0.id == tag.id }) {
                                                viewModel.unifiedFilter.tags[tagIndex].values.remove(at: valueIndex)
                                                if viewModel.unifiedFilter.tags[tagIndex].values.isEmpty {
                                                    viewModel.unifiedFilter.tags.remove(at: tagIndex)
                                                }
                                            }
                                        }
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    }
                                }
                            }
                        }
                        
                        HStack {
                            TextField("Tag Key", text: $newTagKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(maxWidth: 60)
                            TextField("Tag Value", text: $newTagValue)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button("Add") {
                                if !newTagKey.isEmpty && !newTagValue.isEmpty {
                                    viewModel.addTagFilter(key: newTagKey, value: newTagValue)
                                    newTagKey = ""
                                    newTagValue = ""
                                }
                            }
                            .disabled(newTagKey.isEmpty || newTagValue.isEmpty)
                        }
                    }
                    
                    // Time Range
                    DisclosureGroup("Time Range") {
                        HStack {
                            Text("Set Start Time")
                            Spacer()
                            Toggle("", isOn: $viewModel.useSinceDate)
                        }
                        
                        if viewModel.useSinceDate {
                            DatePicker("Start Time", selection: Binding(
                                get: { viewModel.unifiedFilter.sinceDate ?? Date() },
                                set: { viewModel.unifiedFilter.sinceDate = $0 }
                            ), displayedComponents: [.date, .hourAndMinute])
                        }
                        
                        HStack {
                            Text("Set End Time")
                            Spacer()
                            Toggle("", isOn: $viewModel.useUntilDate)
                        }
                        
                        if viewModel.useUntilDate {
                            DatePicker("End Time", selection: Binding(
                                get: { viewModel.unifiedFilter.untilDate ?? Date() },
                                set: { viewModel.unifiedFilter.untilDate = $0 }
                            ), displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                    
                    // Relay Servers
                    DisclosureGroup("Relay Servers") {
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
            .navigationTitle("Edit Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSubscription()
                    }
                }
            }
            .onAppear {
                loadSubscriptionData()
            }
    }
    
    // MARK: - Private Methods
    
    private func loadSubscriptionData() {
        // Load existing subscription filter configuration to ViewModel
        viewModel.loadFromNostrFilterConfig(subscription.filters)
        viewModel.topicName = subscription.topicName
        viewModel.serverURL = subscription.serverURL
        viewModel.useAnotherServer = !subscription.serverURL.isEmpty
    }
    
    private func saveSubscription() {
        // Create updated subscription object
        let updatedFilters = viewModel.convertUIFilterToNostrFilterConfig()
        
        let updatedSubscription = Subscription(
            id: subscription.id,
            topicName: subscription.topicName, // Keep original topic name unchanged
            groupId: subscription.groupId,     // Keep original group ID unchanged
            createdAt: subscription.createdAt,
            lastNotificationAt: subscription.lastNotificationAt,
            unreadCount: subscription.unreadCount,
            latestMessage: subscription.latestMessage,
            isActive: subscription.isActive,
            serverURL: viewModel.useAnotherServer ? viewModel.serverURL : subscription.serverURL,
            notifications: subscription.notifications,
            filters: updatedFilters
        )
        
        // Update subscription
        subscriptionManager.updateSubscription(updatedSubscription)
        
        // Close view
        presentationMode.wrappedValue.dismiss()
    }
    
    private func kindDescription(_ kind: Int) -> String {
        switch kind {
        case 1: return "Text Notes (1)"
        case 6: return "Reposts (6)"
        case 7: return "Likes (7)"
        case 1059: return "Direct Messages (1059)"
        case 9735: return "Zaps (9735)"
        case 20284: return "NIP-29 Group Events (20284)"
        default: return "Event Kind \(kind)"
        }
    }
} 