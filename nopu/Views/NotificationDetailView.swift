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
    @State private var showingEventDetail = false
    
    var body: some View {
            VStack(spacing: 0) {
                if subscription.notifications.isEmpty {
                    // Empty state view
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
                } else {
                    // Notification list
                    List {
                        ForEach(subscription.notifications) { notification in
                            NotificationItemRow(
                                notification: notification,
                                onTap: {
                                    selectedNotification = notification
                                    showingEventDetail = true
                                }
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle(subscription.topicName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
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
                // Mark as read when the page appears
                subscriptionManager.markAsRead(id: subscription.id)
            }
            .sheet(isPresented: $showingEventDetail) {
                if let notification = selectedNotification {
                    NotificationEventDetailView(notification: notification)
                }
            }
    }
}

struct NotificationItemRow: View {
    let notification: NotificationItem
    let onTap: () -> Void
    
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
            .background(notification.isRead ? Color.clear : Color.blue.opacity(0.03))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconColor: Color {
        switch notification.type {
        case .like:
            return .red
        case .repost:
            return .green
        case .reply:
            return .blue
        case .zap:
            return .yellow
        case .directMessage:
            return .purple
        case .general:
            return .gray
        }
    }
    
    private var iconBackgroundColor: Color {
        switch notification.type {
        case .like:
            return .red.opacity(0.15)
        case .repost:
            return .green.opacity(0.15)
        case .reply:
            return .blue.opacity(0.15)
        case .zap:
            return .yellow.opacity(0.15)
        case .directMessage:
            return .purple.opacity(0.15)
        case .general:
            return .gray.opacity(0.15)
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
} 