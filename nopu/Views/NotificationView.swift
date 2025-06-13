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
    @ObservedObject private var multiRelayManager = MultiRelayPoolManager.shared
    @State private var showingConnectionStatus = false
    // Temporarily disabled edit functionality
    // @State private var showingEditView = false
    // @State private var subscriptionToEdit: Subscription?
    
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
                            NavigationLink(destination: NotificationDetailView(
                                subscription: subscription,
                                subscriptionManager: subscriptionManager
                            )) {
                                SubscriptionRowContent(subscription: subscription)
                            }
                            .contextMenu {
                                // Temporarily disabled edit functionality
                                /*
                                Button {
                                    subscriptionToEdit = subscription
                                    showingEditView = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                */
                                
                                Button(role: .destructive) {
                                    subscriptionManager.removeSubscription(id: subscription.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: deleteSubscriptions)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Subscribed Topics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingConnectionStatus = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: connectionStatusIcon)
                                .foregroundColor(connectionStatusColor)
                            Text("\(multiRelayManager.connectedServersCount)/\(multiRelayManager.totalConnectionCount)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(connectionStatusColor)
                        }
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
            .sheet(isPresented: $showingConnectionStatus) {
                ConnectionStatusView(subscriptionManager: subscriptionManager)
            }
            // Temporarily disabled edit functionality
            /*
            .sheet(isPresented: $showingEditView) {
                if let subscription = subscriptionToEdit {
                    EditSubscriptionView(
                        subscription: subscription,
                        subscriptionManager: subscriptionManager
                    )
                }
            }
            */
        }
    }
    
    private func deleteSubscriptions(offsets: IndexSet) {
        for index in offsets {
            let subscription = subscriptionManager.subscriptions[index]
            subscriptionManager.removeSubscription(id: subscription.id)
        }
    }
    
    // MARK: - Computed Properties
    
    private var connectionStatusIcon: String {
        let connected = multiRelayManager.connectedServersCount
        let total = multiRelayManager.totalConnectionCount
        
        if total == 0 {
            return "wifi.slash"
        } else if connected == 0 {
            return "wifi.exclamationmark"
        } else if connected == total {
            return "wifi"
        } else {
            return "wifi.exclamationmark"
        }
    }
    
    private var connectionStatusColor: Color {
        let connected = multiRelayManager.connectedServersCount
        let total = multiRelayManager.totalConnectionCount
        
        if total == 0 || connected == 0 {
            return .red
        } else if connected == total {
            return .green
        } else {
            return .orange
        }
    }
}

struct SubscriptionRowContent: View {
    let subscription: Subscription
    
    var body: some View {
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
                                if subscription.unreadCount > 99 {
                                    Capsule()
                                        .fill(Color.red)
                                        .frame(width: 28, height: 20)
                                } else {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 20, height: 20)
                                }
                                
                                Text(subscription.unreadCount > 99 ? "99+" : "\(subscription.unreadCount)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
} 