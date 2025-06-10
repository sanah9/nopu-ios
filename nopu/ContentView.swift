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
            SubscriptionsView(showingAddSubscription: $showingAddSubscription)
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
            AddSubscriptionView()
        }
    }
}

struct SubscriptionsView: View {
    @Binding var showingAddSubscription: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Empty state view
                VStack(spacing: 24) {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Text("It looks like you don't have any subscriptions yet")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        VStack(spacing: 8) {
                            Text("Click the + to create or subscribe to a topic")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Subscribed topics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddSubscription = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
}

struct AddSubscriptionView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var topicName = ""
    @State private var useAnotherServer = true
    @State private var serverURL = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    Section {
                        TextField("Topic name, e.g. phil_alerts", text: $topicName)
                    }
                    
                    Section {
                        HStack {
                            Text("Use another server")
                            Spacer()
                            Toggle("", isOn: $useAnotherServer)
                        }
                    }
                    
                    if useAnotherServer {
                        Section {
                            TextField("Service URL, e.g. https://nopu.sh", text: $serverURL)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                        }
                    }
                }
            }
            .navigationTitle("Add subscription")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.green)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Subscribe") {
                        // Add subscription logic here
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.secondary)
                    .disabled(topicName.isEmpty)
                }
            }
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationView {
            Form {
                Section("GENERAL") {
                    HStack {
                        Text("Default server")
                        Spacer()
                        Text("nopu.sh")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Text("When subscribing to new topics, this server will be used as a default.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
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

#Preview {
    ContentView()
}
