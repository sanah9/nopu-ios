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
        // Automatically call quickSetup when app launches
        if NostrUtils.shared.quickSetup() {
            print("✅ Nostr quick setup successful")
        } else {
            print("❌ Nostr quick setup failed: \(NostrUtils.shared.lastError ?? "Unknown error")")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
