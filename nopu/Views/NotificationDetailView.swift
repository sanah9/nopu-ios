//
//  NotificationDetailView.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import SwiftUI

struct NotificationDetailView: View {
    let subscriptionId: UUID // Change to store ID instead of subscription object
    @ObservedObject var subscriptionManager: SubscriptionManager
    @State private var selectedNotification: NotificationItem?
    @State private var showingEditView = false
    @State private var visibleRange: Range<Int> = 0..<0 // Empty range by default; will be initialized in onAppear
    @State private var refreshTrigger = 0 // Add refresh trigger
    
    // Computed property to get current subscription
    private var subscription: Subscription? {
        subscriptionManager.subscriptions.first { $0.id == subscriptionId }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let subscription = subscription {
                if subscription.notifications.isEmpty {
                    EmptyNotificationView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(subscription.notifications.prefix(visibleRange.upperBound).enumerated()), id: \.1.id) { index, notification in
                                NotificationItemRow(
                                    notification: notification,
                                    onTap: {
                                        selectedNotification = notification
                                    }
                                )
                                .equatable()
                                .id("\(notification.id)-\(refreshTrigger)") // Include refresh trigger in ID
                                .onAppear {
                                    // Load more when scrolling near the bottom
                                    if index >= visibleRange.upperBound - 5 && visibleRange.upperBound < subscription.notifications.count {
                                        loadMore()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            } else {
                // Subscription not found
                Text("Subscription not found")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(subscription?.topicName ?? "Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Edit") {
                    showingEditView = true
                }
                .foregroundColor(.blue)
                .disabled(subscription == nil)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if let subscription = subscription, !subscription.notifications.isEmpty {
                    Button("Mark All Read") {
                        subscriptionManager.markAsRead(id: subscription.id)
                    }
                    .foregroundColor(.blue)
                    .disabled(subscription.unreadCount == 0)
                }
            }
        }
        .onAppear {
            // Mark as read and initialize visible range when the view appears
            if let subscription = subscription {
                subscriptionManager.markAsRead(id: subscription.id)
                let initialUpperBound = min(20, subscription.notifications.count)
                visibleRange = 0..<initialUpperBound
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserProfileManager.profileUpdatedNotification)) { _ in
            // Trigger view refresh when user profiles are updated
            refreshTrigger += 1
        }
        .sheet(item: $selectedNotification) { notification in
            NotificationEventDetailView(notification: notification)
        }
        .sheet(isPresented: $showingEditView) {
            if let subscription = subscription {
                EditSubscriptionView(
                    subscription: subscription,
                    subscriptionManager: subscriptionManager
                )
            }
        }
    }
    
    private func loadMore() {
        let newUpperBound = min(visibleRange.upperBound + 20, subscription?.notifications.count ?? 0)
        visibleRange = visibleRange.lowerBound..<newUpperBound
    }
}

// Empty state view component
struct EmptyNotificationView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "bell.slash")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                
                Text("No Notifications")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("This subscription hasn't received any notifications yet")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

struct NotificationItemRow: View, Equatable {
    let notification: NotificationItem
    let onTap: () -> Void
    
    // MARK: - Equatable
    static func == (lhs: NotificationItemRow, rhs: NotificationItemRow) -> Bool {
        lhs.notification.id == rhs.notification.id && 
        lhs.notification.isRead == rhs.notification.isRead &&
        lhs.notification.message == rhs.notification.message
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Notification type icon
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: notification.type.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }
                
                // Notification content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(notification.type.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatRelativeTime(notification.receivedAt))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    // Use rich text view if we have emoji data, otherwise use plain text
                    if let eventJSON = notification.eventJSON,
                       let eventData = eventJSON.data(using: .utf8),
                       let eventDict = try? JSONSerialization.jsonObject(with: eventData) as? [String: Any],
                       let tags = eventDict["tags"] as? [[String]],
                       let originalContent = eventDict["content"] as? String {
                        let emojiMap = CustomEmojiManager.shared.parseEmojiTags(from: tags)
                        if !emojiMap.isEmpty {
                            // Extract the content part from the notification message
                            let messagePrefix = extractMessagePrefix(notification.message, originalContent: originalContent, emojiMap: emojiMap)
                            
                            HStack(alignment: .top, spacing: 4) {
                                if !messagePrefix.isEmpty {
                                    Text(messagePrefix)
                                        .font(.system(size: 15))
                                        .foregroundColor(.primary)
                                }
                                RichTextView(content: originalContent, emojiMap: emojiMap)
                            }
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(notification.message)
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text(notification.message)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(notification.isRead ? Color.clear : Color.blue.opacity(0.03))
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconColor: Color {
        switch notification.type {
        case .general:
            return .gray
        case .repost:
            return .green
        case .mention:
            return .pink
        case .dm:
            return .purple
        case .reaction:
            return .orange
        case .zap:
            return .yellow
        case .follow:
            return .teal
        case .text:
            return .brown
        }
    }
    
    private var iconBackgroundColor: Color {
        switch notification.type {
        case .general:
            return .gray.opacity(0.15)
        case .repost:
            return .green.opacity(0.15)
        case .mention:
            return .pink.opacity(0.15)
        case .dm:
            return .purple.opacity(0.15)
        case .reaction:
            return .orange.opacity(0.15)
        case .zap:
            return .yellow.opacity(0.15)
        case .follow:
            return .teal.opacity(0.15)
        case .text:
            return .brown.opacity(0.15)
        }
    }
    
    // Use a static cached RelativeDateTimeFormatter to reduce allocations
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private func formatRelativeTime(_ date: Date) -> String {
        Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Extract the message prefix (like "John liked your note: ") from the notification message
    private func extractMessagePrefix(_ notificationMessage: String, originalContent: String, emojiMap: [String: String]) -> String {
        // Process original content to see what it would look like with 🖼️ replacements
        let processedContent = CustomEmojiManager.shared.processContentForPlainText(originalContent, emojiMap: emojiMap)
        
        // Find where the processed content appears in the notification message
        if let range = notificationMessage.range(of: processedContent) {
            // Return everything before the processed content
            return String(notificationMessage[..<range.lowerBound])
        }
        
        // Fallback: try to find common patterns
        let patterns = [": ", " liked your note: ", " reposted your message: ", " replied to your message: "]
        for pattern in patterns {
            if let range = notificationMessage.range(of: pattern) {
                return String(notificationMessage[...range.upperBound])
            }
        }
        
        // If we can't extract prefix, return empty string to show full rich text
        return ""
    }
} 