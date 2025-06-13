import Foundation

class EventProcessor {
    static let shared = EventProcessor()
    
    private init() {}
    
    func processEvent20284(_ eventString: String) -> (groupId: String, event: String)? {
        print("Starting to parse 20284 event: \(eventString)")
        
        // Parse event string
        guard let data = eventString.data(using: .utf8),
              let eventArray = try? JSONSerialization.jsonObject(with: data) as? [Any],
              eventArray.count >= 3,
              let eventData = eventArray[2] as? [String: Any],
              let tags = eventData["tags"] as? [[String]],
              let content = eventData["content"] as? String else {
            print("Failed to parse event string")
            return nil
        }
        print("Successfully parsed event data")
        
        // Find h tag
        var groupId: String?
        for tag in tags {
            if tag.count >= 2 && tag[0] == "h" {
                groupId = tag[1]
                break
            }
        }
        
        guard let groupId = groupId else {
            print("h tag not found")
            return nil
        }
        print("Found h tag: \(groupId)")
        
        return (groupId, content)
    }
    
    func getEventKind(from eventContent: String) -> Int {
        guard let data = eventContent.data(using: .utf8),
              let eventData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kind = eventData["kind"] as? Int else {
            return 1 // Default to kind 1, which represents a text note
        }
        return kind
    }
    
    // Get tag value by name
    func getTagValue(from eventContent: String, tagName: String) -> String? {
        guard let data = eventContent.data(using: .utf8),
              let eventData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tags = eventData["tags"] as? [[String]] else {
            return nil
        }
        
        for tag in tags {
            if tag.count >= 2 && tag[0] == tagName {
                return tag[1]
            }
        }
        return nil
    }
    
    // Get event content
    func getEventContent(from eventContent: String) -> String? {
        guard let data = eventContent.data(using: .utf8),
              let eventData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = eventData["content"] as? String else {
            return nil
        }
        return content
    }
    
    // Get event publisher's public key
    func getEventPubkey(from eventContent: String) -> String? {
        guard let data = eventContent.data(using: .utf8),
              let eventData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pubkey = eventData["pubkey"] as? String else {
            return nil
        }
        return pubkey
    }
    
    // Parse amount from bolt11 string
    func parseBolt11Amount(_ bolt11: String) -> Int? {
        // Remove 'lightning:' prefix if present
        let cleanBolt11 = bolt11.hasPrefix("lightning:") ? String(bolt11.dropFirst(10)) : bolt11
        
        // Decode bech32 string
        let parts = cleanBolt11.split(separator: "1", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        
        // Get the amount from the prefix (if any)
        // Format: lnbc{amount}{multiplier} or lnbc1
        let prefix = String(parts[0])
        guard prefix.hasPrefix("ln") else { return nil }
        
        // If format is 'lnbc1', there's no amount specified
        if prefix == "lnbc1" || prefix == "lntb1" || prefix == "lnbcrt1" {
            return nil
        }
        
        // Extract amount and multiplier
        // Remove 'ln{network}' prefix (e.g., 'lnbc', 'lntb', 'lnbcrt')
        let amountStr = String(prefix.dropFirst(4))
        guard !amountStr.isEmpty else { return nil }
        
        // Last character is the multiplier
        let multiplier: Int
        switch amountStr.last {
        case "p": multiplier = 1            // pico
        case "n": multiplier = 1_000        // nano
        case "u": multiplier = 1_000_000    // micro
        case "m": multiplier = 1_000_000_000 // milli
        default: return nil
        }
        
        // Parse the numeric part
        let numericPart = String(amountStr.dropLast())
        guard let amount = Int(numericPart) else { return nil }
        
        return amount * multiplier
    }
} 