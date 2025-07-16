//
//  UserProfileDetailView.swift
//  nopu
//
//  Created by assistant on 2025/1/27.
//

import SwiftUI

struct UserProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentUserPubkey: String = ""
    @State private var currentUserNpub: String = ""
    @State private var currentUserNsec: String = ""
    @State private var currentUserDisplayName: String = ""
    @State private var currentUserAbout: String = ""
    @State private var currentUserPicture: String = ""
    @State private var showingCopiedAlert = false
    @State private var copiedText = ""
    
    private let randomNameKey = "CachedRandomUserName"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // User Profile Header
                    VStack(spacing: 16) {
                        // Avatar
                        if !currentUserPicture.isEmpty {
                            AsyncImage(url: URL(string: currentUserPicture)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.gray)
                        }
                        
                        // Display Name
                        Text(currentUserDisplayName.isEmpty ? getOrGenerateRandomName() : currentUserDisplayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        // About
                        if !currentUserAbout.isEmpty {
                            Text(currentUserAbout)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                    
                    // Keys Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Keys")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            // NPUB
                            KeyDisplayCard(
                                title: "Public Key (npub)",
                                value: currentUserNpub,
                                icon: "key.fill",
                                color: .blue
                            ) {
                                copyToClipboard(currentUserNpub, "Public Key")
                            }
                            
                            // NSEC
                            KeyDisplayCard(
                                title: "Private Key (nsec)",
                                value: currentUserNsec,
                                icon: "lock.fill",
                                color: .red
                            ) {
                                copyToClipboard(currentUserNsec, "Private Key")
                            }
                        }
                        .padding(.horizontal)
                    }
                    

                }
                .padding(.bottom, 30)
            }
            .navigationTitle("Profile Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadCurrentUserInfo()
        }
        .alert("Copied!", isPresented: $showingCopiedAlert) {
            Button("OK") { }
        } message: {
            Text("\(copiedText) has been copied to clipboard")
        }
    }
    
    // MARK: - Private Methods
    
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
            
            // Get private key and convert to nsec
            if let privateKey = NostrManager.shared.getPrivateKey() {
                if let nsec = NIP19Parser.shared.hexToNsec(privateKey) {
                    currentUserNsec = nsec
                } else {
                    currentUserNsec = privateKey // Fallback to hex if conversion fails
                }
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
    
    // Generate or get cached random username
    private func getOrGenerateRandomName() -> String {
        if let cached = UserDefaults.standard.string(forKey: randomNameKey) {
            return cached
        }
        let adjectives = ["Swift", "Bright", "Clever", "Witty", "Smart", "Quick", "Sharp", "Bright", "Clever", "Witty"]
        let nouns = ["User", "Person", "Member", "Friend", "Buddy", "Pal", "Mate", "Comrade", "Fellow", "Citizen"]
        let randomAdjective = adjectives.randomElement() ?? "Swift"
        let randomNoun = nouns.randomElement() ?? "User"
        let randomNumber = Int.random(in: 100...999)
        let name = "\(randomAdjective)\(randomNoun)\(randomNumber)"
        UserDefaults.standard.set(name, forKey: randomNameKey)
        return name
    }
    
    private func copyToClipboard(_ text: String, _ label: String) {
        UIPasteboard.general.string = text
        copiedText = label
        showingCopiedAlert = true
    }
}

// MARK: - Key Display Card

struct KeyDisplayCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let onCopy: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16, weight: .medium))
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .medium))
                }
            }
            
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .textSelection(.enabled)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    UserProfileDetailView()
} 