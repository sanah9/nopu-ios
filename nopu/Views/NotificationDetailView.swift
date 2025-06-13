//
//  NotificationDetailView.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import SwiftUI

struct NotificationDetailView: View {
    let subscription: Subscription
    @ObservedObject var subscriptionManager: SubscriptionManager
    @State private var selectedNotification: NotificationItem?
    @State private var showingEditView = false
    @State private var visibleRange: Range<Int> = 0..<20 // Initially load 20 items
    
    var body: some View {
        VStack(spacing: 0) {
            if subscription.notifications.isEmpty {
                EmptyNotificationView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(subscription.notifications[visibleRange].enumerated()), id: \.1.id) { index, notification in
                            NotificationItemRow(
                                notification: notification,
                                onTap: {
                                    selectedNotification = notification
                                }
                            )
                            .equatable()
                            .id(notification.id) // Preserve scroll position
                            .onAppear {
                                // Load more when the last 5 items come into view
                                if index >= visibleRange.upperBound - 5 && visibleRange.upperBound < subscription.notifications.count {
                                    loadMore()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle(subscription.topicName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Edit") {
                    showingEditView = true
                }
                .foregroundColor(.blue)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if !subscription.notifications.isEmpty {
                    Button("Mark All Read") {
                        subscriptionManager.markAsRead(id: subscription.id)
                    }
                    .foregroundColor(.blue)
                    .disabled(subscription.unreadCount == 0)
                }
            }
        }
        .onAppear {
            subscriptionManager.markAsRead(id: subscription.id)
        }
        .sheet(item: $selectedNotification) { notification in
            NotificationEventDetailView(notification: notification)
        }
        .sheet(isPresented: $showingEditView) {
            EditSubscriptionView(
                subscription: subscription,
                subscriptionManager: subscriptionManager
            )
        }
    }
    
    private func loadMore() {
        let newUpperBound = min(visibleRange.upperBound + 20, subscription.notifications.count)
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
        lhs.notification.id == rhs.notification.id && lhs.notification.isRead == rhs.notification.isRead
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
                    
                    Text(notification.message)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
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
} 