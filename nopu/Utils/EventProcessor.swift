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
} 