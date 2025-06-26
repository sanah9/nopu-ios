import Foundation

struct UserProfile: Codable {
    let pubkey: String
    let name: String?
    let about: String?
    let picture: String?
    let createdAt: Date  // Nostr event created_at timestamp
    let updatedAt: Date  // Local cache update timestamp
    
    init(pubkey: String, name: String?, about: String?, picture: String?, createdAt: Date, updatedAt: Date = Date()) {
        self.pubkey = pubkey
        self.name = name
        self.about = about
        self.picture = picture
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Convenience init for backward compatibility
    init(pubkey: String, name: String?, about: String?, picture: String?, updatedAt: Date = Date()) {
        self.pubkey = pubkey
        self.name = name
        self.about = about
        self.picture = picture
        self.createdAt = updatedAt  // Use updatedAt as fallback for createdAt
        self.updatedAt = updatedAt
    }
    
    /// Get display name, prioritize name, otherwise use first 8 characters of pubkey
    var displayName: String {
        return name?.isEmpty == false ? name! : String(pubkey.prefix(8))
    }
} 