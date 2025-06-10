//
//  SettingsView.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("GENERAL"), footer: Text("When subscribing to new topics, this server will be used as a default.")) {
                    HStack {
                        Text("Default server")
                        Spacer()
                        Text("nopu.sh")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("ABOUT") {
                    HStack {
                        Text("Report a bug")
                        Spacer()
                        Text("github.com")
                            .foregroundColor(.secondary)
                        Image(systemName: "link")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    
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
        }
    }
} 