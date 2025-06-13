//
//  nopuApp.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import SwiftUI

@main
struct nopuApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    init() {
        // Initialize NostrManager
        _ = NostrManager.shared.quickSetupAndConnect()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
