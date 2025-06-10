//
//  ContentView.swift
//  nopu
//
//  Created by sana on 2025/6/10.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showingAddSubscription = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NotificationView(showingAddSubscription: $showingAddSubscription)
                .tabItem {
                    Image(systemName: "bell")
                    Text("Notifications")
                }
                .tag(0)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(1)
        }
        .sheet(isPresented: $showingAddSubscription) {
            CreateSubscriptionView()
        }
    }
}

#Preview {
    ContentView()
}
