//
//  NotificationView.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import SwiftUI

struct NotificationView: View {
    @Binding var showingAddSubscription: Bool
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if subscriptionManager.subscriptions.isEmpty {
                    // Empty state view
                    VStack(spacing: 24) {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            Text("It looks like you don't have any subscriptions yet")
                                .font(.system(size: 17))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            VStack(spacing: 8) {
                                Text("Click the + to create or subscribe to a topic")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        }
                        
                        Spacer()
                    }
                } else {
                    // Subscription list
                    List {
                        ForEach(subscriptionManager.subscriptions) { subscription in
                            SubscriptionRow(
                                subscription: subscription,
                                onTap: {
                                    // Mark as read when tapped
                                    subscriptionManager.markAsRead(id: subscription.id)
                                }
                            )
                        }
                        .onDelete(perform: deleteSubscriptions)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Subscribed topics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Debug button to simulate notifications
                    if !subscriptionManager.subscriptions.isEmpty {
                        Button("Simulate") {
                            simulateNewNotification()
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddSubscription = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
    
    private func deleteSubscriptions(offsets: IndexSet) {
        for index in offsets {
            let subscription = subscriptionManager.subscriptions[index]
            subscriptionManager.removeSubscription(id: subscription.id)
        }
    }
    
    private func simulateNewNotification() {
        guard let randomSubscription = subscriptionManager.subscriptions.randomElement() else { return }
        
        let messages = [
            "Received a new like notification",
            "Someone reposted your content",
            "Received a new reply",
            "Received a new Zap",
            "Received a new direct message",
            "New content matches your subscription"
        ]
        
        let randomMessage = messages.randomElement() ?? "New notification"
        subscriptionManager.addNotificationToTopic(topicName: randomSubscription.topicName, message: randomMessage)
    }
}

struct SubscriptionRow: View {
    let subscription: Subscription
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Topic icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: subscription.unreadCount > 0 ? "bell.fill" : "bell")
                        .font(.system(size: 20))
                        .foregroundColor(subscription.unreadCount > 0 ? .green : .secondary)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(subscription.topicName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Time
                        if let lastNotification = subscription.lastNotificationAt {
                            Text(formatRelativeTime(lastNotification))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(subscription.filterSummary)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            if let latestMessage = subscription.latestMessage {
                                Text(latestMessage)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                            }
                        }
                        
                        Spacer()
                        
                        // Unread badge
                        if subscription.unreadCount > 0 {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 20, height: 20)
                                
                                Text("\(subscription.unreadCount)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
} 