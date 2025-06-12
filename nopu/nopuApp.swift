//
//  nopuApp.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import SwiftUI

@main
struct nopuApp: App {
    
    init() {
        // Automatically call quickSetup and connect when app launches
        if NostrManager.shared.quickSetupAndConnect() {
            print("✅ Nostr quick setup and connection successful")
        } else {
            print("❌ Nostr quick setup and connection failed: \(NostrManager.shared.lastError ?? "Unknown error")")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
