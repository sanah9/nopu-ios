import Foundation

final class PushTokenManager {
    static let shared = PushTokenManager()
    private init() {
        // Load token from UserDefaults if available
        if let saved = UserDefaults.standard.string(forKey: "deviceToken") {
            token = saved
        }
    }

    var token: String? {
        didSet {
            guard let token = token else { return }
            UserDefaults.standard.set(token, forKey: "deviceToken")
        }
    }
} 