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
    @State private var currentUserPubkey: String = ""
    @State private var currentUserNpub: String = ""
    @State private var currentUserDisplayName: String = ""
    @State private var currentUserAbout: String = ""
    @State private var currentUserPicture: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                // User Profile Section
                Section(header: Text("USER PROFILE")) {
                    // User avatar and basic info
                    HStack {
                        if !currentUserPicture.isEmpty {
                            AsyncImage(url: URL(string: currentUserPicture)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentUserDisplayName.isEmpty ? generateRandomName() : currentUserDisplayName)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if !currentUserNpub.isEmpty {
                                Text(currentUserNpub)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    
                    // About information
                    if !currentUserAbout.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("About")
                                .foregroundColor(.primary)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(currentUserAbout)
                                .foregroundColor(.secondary)
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
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
            .onAppear {
                loadCurrentUserInfo()
            }
            .onDisappear {
                // Remove notification observer when view disappears
                NotificationCenter.default.removeObserver(self)
            }
        }
    }
    
    // Load current user information
    private func loadCurrentUserInfo() {
        // Get current user's pubkey from NostrManager
        if let pubkey = NostrManager.shared.getPublicKey() {
            currentUserPubkey = pubkey
            
            // Convert to npub format
            if let npub = NIP19Parser.shared.hexToNpub(pubkey) {
                currentUserNpub = npub
            } else {
                currentUserNpub = pubkey // Fallback to hex if conversion fails
            }
            
            // Load full user profile for additional information
            loadFullUserProfile(pubkey: pubkey)
        }
    }
    
    // Load full user profile information
    private func loadFullUserProfile(pubkey: String) {
        // First load cached profile if available
        if let cachedProfile = UserProfileManager.shared.getCachedProfile(for: pubkey) {
            self.currentUserDisplayName = cachedProfile.displayName
            self.currentUserAbout = cachedProfile.about ?? ""
            self.currentUserPicture = cachedProfile.picture ?? ""
        }
        
        // Prefetch latest profile
        UserProfileManager.shared.prefetchUserProfile(pubkey: pubkey)
        
        // Listen for profile updates
        NotificationCenter.default.addObserver(
            forName: UserProfileManager.profileUpdatedNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let profilePubkey = userInfo["pubkey"] as? String,
               let profile = userInfo["profile"] as? UserProfile,
               profilePubkey == pubkey {
                
                self.currentUserDisplayName = profile.displayName
                self.currentUserAbout = profile.about ?? ""
                self.currentUserPicture = profile.picture ?? ""
            }
        }
    }
    
    // Generate a random username
    private func generateRandomName() -> String {
        let adjectives = ["Swift", "Bright", "Clever", "Witty", "Smart", "Quick", "Sharp", "Bright", "Clever", "Witty"]
        let nouns = ["User", "Person", "Member", "Friend", "Buddy", "Pal", "Mate", "Comrade", "Fellow", "Citizen"]
        
        let randomAdjective = adjectives.randomElement() ?? "Swift"
        let randomNoun = nouns.randomElement() ?? "User"
        let randomNumber = Int.random(in: 100...999)
        
        return "\(randomAdjective)\(randomNoun)\(randomNumber)"
    }
} 