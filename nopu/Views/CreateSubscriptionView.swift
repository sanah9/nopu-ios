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
    // Focus state to automatically focus Topic TextField on appear
    @FocusState private var topicNameFocused: Bool
    @State private var showErrorAlert = false
    @State private var errorMessage = "Subscription failed. Please ensure you are connected to at least one relay server."
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Settings
                Section("Basic Settings") {
                    TextField("Topic name, e.g. nopu_alerts", text: $viewModel.topicName)
                        .focused($topicNameFocused)
                        .disableAutocorrection(true)
                }
                
                HStack {
                    Text("Use another push server")
                    Spacer()
                    Text("Coming Soon")
                        .foregroundColor(.secondary)
                }
                
                // Basic Push Options
                DisclosureGroup(isExpanded: $viewModel.enableBasicOptions) {
                    Section("User Public Key") {
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("Enter public key (npub or hex format)", text: $viewModel.userPubkey)
                                .font(.system(.caption, design: .monospaced))
                                .disableAutocorrection(true)
                                .autocapitalization(.none)
                            if !viewModel.userPubkey.isEmpty && !viewModel.isValidPubkey(viewModel.userPubkey) {
                                Text("Invalid pubkey")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
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
                        // NotificationToggle(
                        //     title: "Following posts",
                        //     subtitle: "Notify when people you follow post new notes",
                        //     isOn: $viewModel.notifyOnFollowsPosts
                        // )
                        
                        NotificationToggle(
                            title: "Direct messages",
                            subtitle: "Notify when you receive direct messages",
                            isOn: $viewModel.notifyOnDMs
                        )
                    }
                } label: {
                    HStack {
                        Text("Basic options")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            viewModel.enableBasicOptions.toggle()
                        }
                    }
                }
                
                // Advanced Filters
                DisclosureGroup(isExpanded: $viewModel.useAdvancedFilters) {
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
                                if viewModel.isValidEventId(newEventId) {
                                    viewModel.unifiedFilter.eventIds.append(newEventId)
                                    newEventId = ""
                                }
                            },
                            validate: viewModel.isValidEventId
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
                                if viewModel.isValidPubkey(newAuthor) {
                                    viewModel.unifiedFilter.authors.append(newAuthor)
                                    newAuthor = ""
                                }
                            },
                            validate: viewModel.isValidPubkey
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
                        
                        VStack(alignment: .leading, spacing: 2) {
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
                                .disabled(newKind.isEmpty || !viewModel.isValidKindNumber(newKind))
                            }
                            if !newKind.isEmpty && !viewModel.isValidKindNumber(newKind) {
                                Text("Invalid kind number")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
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
                                    if viewModel.isValidTagKey(newTagKey) {
                                        viewModel.addTagFilter(key: newTagKey, value: newTagValue)
                                        newTagKey = ""
                                        newTagValue = ""
                                    }
                                }
                                .disabled(newTagKey.isEmpty || newTagValue.isEmpty || !viewModel.isValidTagKey(newTagKey))
                            }
                            if !newTagKey.isEmpty && !viewModel.isValidTagKey(newTagKey) {
                                Text("Invalid tag key")
                                    .font(.caption2)
                                    .foregroundColor(.red)
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
                    // Section("Relay Servers") {
                    //     ForEach(viewModel.unifiedFilter.relays.indices, id: \.self) { index in
                    //         VStack(alignment: .leading, spacing: 2) {
                    //             HStack {
                    //                 VStack(alignment: .leading, spacing: 2) {
                    //                     Text(viewModel.unifiedFilter.relays[index])
                    //                         .font(.system(.body, design: .monospaced))
                    //                     Text("Relay #\(index + 1)")
                    //                         .font(.caption2)
                    //                         .foregroundColor(.secondary)
                    //                 }
                    //                 Spacer()
                    //                 Button("Remove") {
                    //                     viewModel.unifiedFilter.relays.remove(at: index)
                    //                 }
                    //                 .foregroundColor(.red)
                    //                 .font(.caption)
                    //                 .buttonStyle(BorderlessButtonStyle())
                    //             }
                    //         }
                    //     }
                        
                    //     HStack {
                    //         TextField("e.g. wss://relay.damus.io", text: $newRelay)
                    //             .keyboardType(.URL)
                    //             .autocapitalization(.none)
                    //             .disableAutocorrection(true)
                    //         Button("Add") {
                    //             if !newRelay.isEmpty && viewModel.isValidWebSocketURL(newRelay) {
                    //                 viewModel.unifiedFilter.relays.append(newRelay)
                    //                 newRelay = ""
                    //             }
                    //         }
                    //         .disabled(newRelay.isEmpty || !viewModel.isValidWebSocketURL(newRelay))
                    //     }
                        
                    //     if viewModel.unifiedFilter.relays.isEmpty {
                    //         Text("Default server will be used when no relays are specified")
                    //             .font(.caption)
                    //             .foregroundColor(.secondary)
                    //     }
                    // }
                } label: {
                    HStack {
                        Text("Advanced options")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            viewModel.useAdvancedFilters.toggle()
                        }
                    }
                }
            }
            .simultaneousGesture(TapGesture().onEnded { UIApplication.shared.endEditing() })
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
                        viewModel.createSubscriptionWithGroup(subscriptionManager: subscriptionManager) { success, error in
                            if success {
                                presentationMode.wrappedValue.dismiss()
                            } else {
                                errorMessage = error ?? "Subscription failed. Please ensure you are connected to at least one relay server."
                                showErrorAlert = true
                            }
                        }
                    }
                    .disabled(viewModel.topicName.isEmpty || (!viewModel.userPubkey.isEmpty && !viewModel.isValidPubkey(viewModel.userPubkey)))
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            // Automatically focus the Topic TextField when the view appears
            .onAppear {
                // Slight delay ensures the field is available for focus
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    topicNameFocused = true
                }
            }
        }
    }

}

// MARK: - Resign First Responder Helper

extension UIApplication {
    /// Helper method to resign the current first responder and dismiss the keyboard.
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
} 