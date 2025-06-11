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
        if NostrUtils.shared.quickSetupAndConnect() {
            print("✅ Nostr quick setup and connection successful")
        } else {
            print("❌ Nostr quick setup and connection failed: \(NostrUtils.shared.lastError ?? "Unknown error")")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
