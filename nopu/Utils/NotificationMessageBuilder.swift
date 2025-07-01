import Foundation

struct NotificationMessageBuilder {
    
    // MARK: - Configuration
    
    /// A set of event kinds that should display the sender's name.
    /// This centralizes the logic for deciding when to fetch a user profile.
    private static let kindsRequiringDisplayName: Set<Int> = [1, 6, 7, 9735]
    
    // MARK: - Private Helpers
    
    /// Extracts a tag value by its name from a list of tags.
    private static func tagValue(_ name: String, from tags: [[String]]) -> String? {
        for tag in tags where tag.count >= 2 && tag[0] == name {
            return tag[1]
        }
        return nil
    }
    
    /// A centralized place to process general event content.
    /// This is where custom emoji and future 'nostr:' scheme parsing will happen.
    private static func processContent(_ content: String, tags: [[String]]) -> String {
        let emojiMap = CustomEmojiManager.shared.parseEmojiTags(from: tags)
        let processedContent = CustomEmojiManager.shared.processContent(content, emojiMap: emojiMap)
        // TODO: Add parsing for nostr: schemes here in the future.
        return processedContent
    }
    
    /// A specific formatter for reaction content, which can be just an emoji or a short string.
    private static func formatReactionContent(_ content: String, tags: [[String]]) -> String {
        let emojiMap = CustomEmojiManager.shared.parseEmojiTags(from: tags)
        return CustomEmojiManager.shared.formatReactionContent(content, emojiMap: emojiMap)
    }

    /// The core logic for constructing the final notification message string.
    /// It determines the message template based on the event kind and fills it with the appropriate data.
    static func buildMessage(for eventKind: Int, eventData: [String: Any], displayName: String) -> String {
        let tags = eventData["tags"] as? [[String]] ?? []
        let content = eventData["content"] as? String ?? ""
        let hasDisplayName = !displayName.isEmpty

        switch eventKind {
        case 1:
            let processedContent = processContent(content, tags: tags)
            if hasDisplayName {
                if tagValue("p", from: tags) != nil {
                    if tagValue("q", from: tags) != nil {
                        return "\(displayName) quote reposted your message: \(processedContent)"
                    } else {
                        return "\(displayName) replied to your message: \(processedContent)"
                    }
                }
                return "\(displayName) sent a new message: \(processedContent)"
            } else {
                // Fallback messages when no display name is available.
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
            let formattedContent = formatReactionContent(content, tags: tags)
            let author = hasDisplayName ? displayName : "Someone"
            return "\(author) liked your note: \(formattedContent)"
            
        case 6:
            let author = hasDisplayName ? displayName : "Someone"
            return "\(author) reposted your message"
            
        case 9735:
            let processedContent = processContent(content, tags: tags)
            let contentSuffix = !processedContent.isEmpty ? ": \(processedContent)" : ""

            if let _ = tagValue("p", from: tags), let bolt11 = tagValue("bolt11", from: tags) {
                let sats = EventProcessor.shared.parseBolt11Amount(bolt11) ?? 0
                if hasDisplayName {
                    return "\(displayName) zapped you \(sats) sats\(contentSuffix)"
                } else {
                    return "Received \(sats) sats via Zap\(contentSuffix)"
                }
            }
            
            // Fallback for zaps without amount information
            if hasDisplayName {
                return "\(displayName) zapped you\(contentSuffix)"
            } else {
                return "Received a Zap\(contentSuffix)"
            }

        case 1059:
            return "Received a direct message"
            
        default:
            return "Received a new notification"
        }
    }
    
    // MARK: - Public API
    
    /// Generates a notification message synchronously using a cached display name.
    /// This method provides an immediate message and triggers a background profile update.
    static func message(for eventKind: Int, eventData: [String: Any]) -> String {
        // Special handling for kind 9735 (Zap) - use P tag for sender pubkey
        if eventKind == 9735 {
            let tags = eventData["tags"] as? [[String]] ?? []
            if let senderPubkey = tagValue("P", from: tags) {
                // Trigger a background fetch to update the profile cache for future use.
                UserProfileManager.shared.prefetchUserProfile(pubkey: senderPubkey)
                
                // Immediately return a message with the currently cached name (or pubkey prefix).
                let cachedDisplayName = UserProfileManager.shared.getCachedDisplayName(for: senderPubkey)
                return buildMessage(for: eventKind, eventData: eventData, displayName: cachedDisplayName)
            } else {
                // No P tag found, build message without sender name
                return buildMessage(for: eventKind, eventData: eventData, displayName: "")
            }
        }
        
        // For other event kinds that need pubkey
        guard let pubkey = eventData["pubkey"] as? String, kindsRequiringDisplayName.contains(eventKind) else {
            // For events that don't need a name or if pubkey is missing, build with an empty name.
            return buildMessage(for: eventKind, eventData: eventData, displayName: "")
        }
        
        // Trigger a background fetch to update the profile cache for future use.
        UserProfileManager.shared.prefetchUserProfile(pubkey: pubkey)
        
        // Immediately return a message with the currently cached name (or pubkey prefix).
        let cachedDisplayName = UserProfileManager.shared.getCachedDisplayName(for: pubkey)
        return buildMessage(for: eventKind, eventData: eventData, displayName: cachedDisplayName)
    }
    
    /// Generates a notification message asynchronously, fetching the latest display name.
    /// Use this to update an existing notification with the proper user name.
    static func messageAsync(for eventKind: Int, eventData: [String: Any], completion: @escaping (String) -> Void) {
        // Special handling for kind 9735 (Zap) - use P tag for sender pubkey
        if eventKind == 9735 {
            let tags = eventData["tags"] as? [[String]] ?? []
            if let senderPubkey = tagValue("P", from: tags) {
                // Fetch the latest display name and then build the message.
                UserProfileManager.shared.getDisplayName(for: senderPubkey) { fetchedDisplayName in
                    let message = buildMessage(for: eventKind, eventData: eventData, displayName: fetchedDisplayName)
                    completion(message)
                }
            } else {
                // No P tag found, build message without sender name
                let message = buildMessage(for: eventKind, eventData: eventData, displayName: "")
                completion(message)
            }
            return
        }
        
        // For other event kinds that need pubkey
        guard let pubkey = eventData["pubkey"] as? String, kindsRequiringDisplayName.contains(eventKind) else {
            // For events that don't need a name, complete with the basic message.
            let message = buildMessage(for: eventKind, eventData: eventData, displayName: "")
            completion(message)
            return
        }
        
        // Fetch the latest display name and then build the message.
        UserProfileManager.shared.getDisplayName(for: pubkey) { fetchedDisplayName in
            let message = buildMessage(for: eventKind, eventData: eventData, displayName: fetchedDisplayName)
            completion(message)
        }
    }
} 
