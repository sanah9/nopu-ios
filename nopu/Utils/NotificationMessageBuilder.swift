import Foundation

struct NotificationMessageBuilder {
    
    // MARK: - Helper Methods
    
    private static func tagValue(_ name: String, from tags: [[String]]) -> String? {
        for tag in tags where tag.count >= 2 && tag[0] == name {
            return tag[1]
        }
        return nil
    }
    
    private static func buildMessage(for eventKind: Int, eventData: [String: Any], displayName: String) -> String {
        let tags = eventData["tags"] as? [[String]] ?? []
        let content = eventData["content"] as? String ?? ""
        let emojiMap = CustomEmojiManager.shared.parseEmojiTags(from: tags)
        
        switch eventKind {
        case 1:
            let processedContent = CustomEmojiManager.shared.processContent(content, emojiMap: emojiMap)
            if !displayName.isEmpty {
                if tagValue("p", from: tags) != nil {
                    if tagValue("q", from: tags) != nil {
                        return "\(displayName) quote reposted your message: \(processedContent)"
                    } else {
                        return "\(displayName) replied to your message: \(processedContent)"
                    }
                }
                return "\(displayName) sent a new message: \(processedContent)"
            } else {
                // Original logic for when displayName is not available
                if tagValue("p", from: tags) != nil {
                    if tagValue("q", from: tags) != nil {
                        return "Quote reposted your message: \(processedContent)"
                    } else {
                        return "Replied to your message: \(processedContent)"
                    }
                }
                return "New message: \(processedContent)"
            }
        case 7:
            let formattedContent = CustomEmojiManager.shared.formatReactionContent(content, emojiMap: emojiMap)
            return "\(displayName) liked your note: \(formattedContent)"
        case 1059:
            return "Received a direct message"
        case 6:
            return "\(displayName) reposted your message"
        case 9735:
            if let _ = tagValue("p", from: tags), let bolt11 = tagValue("bolt11", from: tags) {
                let sats = EventProcessor.shared.parseBolt11Amount(bolt11) ?? 0
                if !displayName.isEmpty {
                    return "\(displayName) zapped you: \(sats) sats"
                } else {
                    return "Received \(sats) sats via Zap"
                }
            }
            if !displayName.isEmpty {
                return "\(displayName) zapped you"
            }
            return "Received a Zap"
        default:
            return "Received a new notification"
        }
    }
    
    // MARK: - Public Methods
    
    static func message(for eventKind: Int, eventData: [String: Any]) -> String {
        // Handle cases that need pubkey
        if (eventKind == 1 || eventKind == 6 || eventKind == 7 || eventKind == 9735), let pubkey = eventData["pubkey"] as? String {
            let displayName = UserProfileManager.shared.getCachedDisplayName(for: pubkey)
            
            // Trigger async fetch to update cache for future use
            UserProfileManager.shared.prefetchUserProfile(pubkey: pubkey)
            
            return buildMessage(for: eventKind, eventData: eventData, displayName: displayName)
        }
        
        // For other event types or if pubkey is missing, displayName is not used
        return buildMessage(for: eventKind, eventData: eventData, displayName: "")
    }
    
    /// Asynchronously get message content, will update message after getting username
    static func messageAsync(for eventKind: Int, eventData: [String: Any], completion: @escaping (String) -> Void) {
        // Handle cases that need pubkey
        if (eventKind == 1 || eventKind == 6 || eventKind == 7 || eventKind == 9735), let pubkey = eventData["pubkey"] as? String {
            UserProfileManager.shared.getDisplayName(for: pubkey) { displayName in
                let message = buildMessage(for: eventKind, eventData: eventData, displayName: displayName)
                completion(message)
            }
        } else {
            // For other event types or if pubkey is missing, displayName is not used
            let message = buildMessage(for: eventKind, eventData: eventData, displayName: "")
            completion(message)
        }
    }
} 
