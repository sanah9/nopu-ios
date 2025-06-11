//
//  NotificationEventDetailView.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import SwiftUI

struct NotificationEventDetailView: View {
    let notification: NotificationItem
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Basic Information")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 8) {
                            InfoRow(label: "Type", value: notification.type.displayName)
                            InfoRow(label: "Message", value: notification.message)
                            InfoRow(label: "Received At", value: formatFullDate(notification.receivedAt))
                            InfoRow(label: "Read Status", value: notification.isRead ? "Read" : "Unread")
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Event Details Section
                    if hasEventDetails {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Event Details")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 8) {
                                if let eventId = notification.eventId {
                                    InfoRow(label: "Event ID", value: eventId, isMonospace: true)
                                }
                                
                                if let authorPubkey = notification.authorPubkey {
                                    InfoRow(label: "Author Pubkey", value: authorPubkey, isMonospace: true)
                                }
                                
                                if let eventKind = notification.eventKind {
                                    InfoRow(label: "Event Kind", value: "\(eventKind)")
                                }
                                
                                if let eventCreatedAt = notification.eventCreatedAt {
                                    InfoRow(label: "Event Created At", value: formatFullDate(eventCreatedAt))
                                }
                                
                                if let relayURL = notification.relayURL {
                                    InfoRow(label: "Relay", value: relayURL, isMonospace: true)
                                }
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Event JSON Section
                    if let eventJSON = notification.eventJSON {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Event JSON")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            ScrollView(.horizontal, showsIndicators: true) {
                                Text(formatJSON(eventJSON))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .background(Color.black.opacity(0.05))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.green)
                }
                
                if let eventJSON = notification.eventJSON {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Copy JSON") {
                            UIPasteboard.general.string = eventJSON
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var hasEventDetails: Bool {
        notification.eventId != nil || 
        notification.authorPubkey != nil || 
        notification.eventKind != nil || 
        notification.eventCreatedAt != nil || 
        notification.relayURL != nil
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
    
    private func formatJSON(_ jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return jsonString
        }
        return prettyString
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var isMonospace: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            Text(value)
                .font(isMonospace ? .system(.caption, design: .monospaced) : .system(.caption))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
} 