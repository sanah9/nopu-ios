//
//  SettingsView.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultServerURL") private var selectedServer: String = AppConfig.defaultServerURL
    @State private var showingComingSoonAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("GENERAL"), footer: Text("When subscribing to new topics, this server will be used as a default.")) {
                    Button(action: {
                        showingComingSoonAlert = true
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
            .alert("Coming Soon", isPresented: $showingComingSoonAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The custom push server feature is coming soon. Stay tuned!")
            }
        }
    }
} 