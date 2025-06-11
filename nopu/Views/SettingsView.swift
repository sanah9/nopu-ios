//
//  SettingsView.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import SwiftUI

struct SettingsView: View {
    @State private var selectedServer = "nopu.sh"
    @State private var showingCustomServerInput = false
    @State private var customServerURL = ""
    
    private let defaultServer = "nopu.sh"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("GENERAL"), footer: Text("When subscribing to new topics, this server will be used as a default.")) {
                    Button(action: {
                        customServerURL = selectedServer
                        showingCustomServerInput = true
                    }) {
                        HStack {
                            Text("Default server")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(selectedServer)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Section("ABOUT") {
                    Button(action: {
                        if let url = URL(string: "https://github.com/sanah9/nopu-ios/issues") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Report a bug")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("github.com")
                                .foregroundColor(.secondary)
                            Image(systemName: "link")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("nopu 0.1 (1)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Default Server", isPresented: $showingCustomServerInput) {
                TextField("Enter server URL", text: $customServerURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                Button("Cancel", role: .cancel) {
                    customServerURL = ""
                }
                Button("Reset to nopu.sh", role: .destructive) {
                    selectedServer = defaultServer
                    customServerURL = ""
                }
                Button("Save") {
                    if !customServerURL.isEmpty {
                        // Simple URL format validation
                        var serverURL = customServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Add https:// by default if user didn't input protocol
                        if !serverURL.hasPrefix("http://") && !serverURL.hasPrefix("https://") {
                            serverURL = "https://" + serverURL
                        }
                        
                        // Remove trailing slash
                        if serverURL.hasSuffix("/") {
                            serverURL = String(serverURL.dropLast())
                        }
                        
                        selectedServer = serverURL
                        customServerURL = ""
                    }
                }
                .disabled(customServerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Enter the URL of your server (e.g., nopu.sh or https://my-server.com)")
            }
        }
    }
} 