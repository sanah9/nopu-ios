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
    
    // Parse amount from bolt11 string (simple implementation, might need more complex parsing)
    func parseBolt11Amount(_ bolt11: String) -> Int? {
        // Need to implement complete bolt11 parsing
        // This is just a simple implementation, should use a dedicated Lightning library in production
        guard let data = bolt11.data(using: .utf8),
              let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let amount = decoded["amount"] as? Int else {
            return nil
        }
        return amount
    }
} 