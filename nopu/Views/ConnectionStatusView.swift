//
//  ConnectionStatusView.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import SwiftUI

struct ConnectionStatusView: View {
    @ObservedObject var multiRelayManager = MultiRelayPoolManager.shared
    @ObservedObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        NavigationView {
            List {
                // Summary information
                Section("Connection Status") {
                    HStack {
                        Text("Total Servers")
                        Spacer()
                        Text("\(multiRelayManager.totalConnectionCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Connected")
                        Spacer()
                        Text("\(multiRelayManager.connectedServersCount)")
                            .foregroundColor(multiRelayManager.connectedServersCount > 0 ? .green : .red)
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(overallStatusText)
                            .foregroundColor(overallStatusColor)
                    }
                }
                
                // Server details
                if !multiRelayManager.serverConnections.isEmpty {
                    Section("Server Details") {
                        ForEach(Array(multiRelayManager.serverConnections.keys.sorted()), id: \.self) { serverURL in
                            if let connection = multiRelayManager.serverConnections[serverURL] {
                                ServerConnectionRow(connection: connection)
                            }
                        }
                    }
                }
                
                // Control buttons
                Section("Controls") {
                    Button("Reconnect All") {
                        subscriptionManager.reconnectAllServers()
                    }
                    .foregroundColor(.blue)
                    
                    Button("Disconnect All") {
                        subscriptionManager.disconnectAllServers()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Connection Status")
            .refreshable {
                // Manual refresh trigger (mainly for UI)
                subscriptionManager.reconnectAllServers()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var overallStatusText: String {
        let connected = multiRelayManager.connectedServersCount
        let total = multiRelayManager.totalConnectionCount
        
        if total == 0 {
            return "No Servers"
        } else if connected == 0 {
            return "All Disconnected"
        } else if connected == total {
            return "All Connected"
        } else {
            return "Partially Connected"
        }
    }
    
    private var overallStatusColor: Color {
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

// MARK: - Server Connection Row Component

struct ServerConnectionRow: View {
    @ObservedObject var connection: ServerConnection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Server header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.serverURL == "default" ? "Default Server" : connection.serverURL)
                        .font(.headline)
                    Text("\(connection.relayURLs.count) relays")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Connection status
                HStack(spacing: 4) {
                    Circle()
                        .fill(connectionStatusColor)
                        .frame(width: 8, height: 8)
                    Text(connectionStatusText)
                        .font(.caption)
                        .foregroundColor(connectionStatusColor)
                }
            }
            
            // Relay details
            if !connection.activeRelays.isEmpty {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(connection.activeRelays.indices, id: \.self) { index in
                        let relay = connection.activeRelays[index]
                        RelayStatusLine(relay: relay, index: index)
                    }
                }
                .padding(.leading, 8)
            }
            
            // Error message
            if let error = connection.lastError {
                Text("Error: \(error)")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.leading, 8)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Computed Properties
    
    private var connectionStatusText: String {
        switch connection.connectionState {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .disconnected:
            return "Disconnected"
        }
    }
    
    private var connectionStatusColor: Color {
        switch connection.connectionState {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .red
        }
    }
}

// MARK: - Relay Status Line Component

struct RelayStatusLine: View {
    let relay: RelayInfo
    let index: Int
    
    var body: some View {
        HStack {
            Text("Relay \(index + 1)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
            
            Text(relay.url)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer(minLength: 8)
            
            HStack(spacing: 2) {
                Circle()
                    .fill(relay.status == "connected" ? .green : .red)
                    .frame(width: 6, height: 6)
                Text(relay.status.capitalized)
                    .font(.caption2)
                    .foregroundColor(relay.status == "connected" ? .green : .red)
            }
        }
    }
}

// MARK: - Preview

struct ConnectionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        let mockSubscriptionManager = SubscriptionManager()
        ConnectionStatusView(subscriptionManager: mockSubscriptionManager)
    }
} 