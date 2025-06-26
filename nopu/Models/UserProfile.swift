import Foundation

struct UserProfile: Codable {
    let pubkey: String
    let name: String?
    let about: String?
    let picture: String?
    let updatedAt: Date
    
    init(pubkey: String, name: String?, about: String?, picture: String?, updatedAt: Date = Date()) {
        self.pubkey = pubkey
        self.name = name
        self.about = about
        self.picture = picture
        self.updatedAt = updatedAt
    }
    
    /// Get display name, prioritize name, otherwise use first 8 characters of pubkey
    var displayName: String {
        return name?.isEmpty == false ? name! : String(pubkey.prefix(8))
    }
} 