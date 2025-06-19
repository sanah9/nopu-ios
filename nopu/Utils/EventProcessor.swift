import Foundation

@MainActor
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
        
        // Find the first digit in the string
        guard let firstDigitIndex = cleanBolt11.firstIndex(where: { $0.isNumber }) else { return nil }
        
        // Get the substring from the first digit
        let amountPart = String(cleanBolt11[firstDigitIndex...])
        
        // Extract numeric part and multiplier
        var numericPart = ""
        var multiplierStr = ""
        
        for char in amountPart {
            if char.isNumber {
                numericPart.append(char)
            } else {
                multiplierStr.append(char)
                break  // Stop at the first non-numeric character
            }
        }
        
        guard !numericPart.isEmpty, !multiplierStr.isEmpty else { return nil }
        guard let amount = Double(numericPart) else { return nil }
        
        // Calculate multiplier
        let multiplier: Double
        switch multiplierStr {
        case "p": multiplier = 0.000000000001 // pico
        case "n": multiplier = 0.000000001    // nano
        case "u": multiplier = 0.000001       // micro
        case "m": multiplier = 0.001          // milli
        default: return nil
        }
        
        // Convert to satoshis (1 BTC = 100,000,000 satoshis)
        let btcAmount = amount * multiplier
        let satoshis = btcAmount * 100_000_000
        
        return Int(satoshis)
    }
} 