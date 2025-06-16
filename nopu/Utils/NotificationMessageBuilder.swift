import Foundation

struct NotificationMessageBuilder {
    static func message(for eventKind: Int, eventData: [String: Any]) -> String {
        let tags = eventData["tags"] as? [[String]] ?? []
        let content = eventData["content"] as? String ?? ""

        func tagValue(_ name: String) -> String? {
            for tag in tags where tag.count >= 2 && tag[0] == name {
                return tag[1]
            }
            return nil
        }

        switch eventKind {
        case 1:
            if tagValue("p") != nil {
                if tagValue("q") != nil {
                    return "Quote reposted your message: \(content)"
                } else {
                    return "Replied to your message: \(content)"
                }
            }
            return "New message: \(content)"
        case 7:
            if let pubkey = eventData["pubkey"] as? String {
                return "\(pubkey.prefix(8)) liked: \(content)"
            }
            return "Received a like"
        case 1059:
            return "Received a direct message"
        case 6:
            if let pubkey = eventData["pubkey"] as? String {
                return "\(pubkey.prefix(8)) reposted your message"
            }
            return "Message was reposted"
        case 9735:
            if let p = tagValue("p"), let bolt11 = tagValue("bolt11") {
                let sats = EventProcessor.shared.parseBolt11Amount(bolt11) ?? 0
                return "Received \(sats) sats via Zap"
            }
            return "Received a Zap"
        default:
            return "Received a new notification"
        }
    }
} 