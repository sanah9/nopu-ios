import Foundation

/// NIP-19 and NIP-21 Parser for Nostr identifiers
class NIP19Parser {
    static let shared = NIP19Parser()
    
    private init() {}
    
    // MARK: - NIP-19 Bech32 Decoding
    
    /// Decode bech32 string and return the data
    private func decodeBech32(_ bech32String: String) -> (prefix: String, data: Data)? {
        do {
            let (prefix, data5) = try Bech32.decode(bech32String)
            guard let data = convertBits5to8(data5) else { return nil }
            return (prefix, Data(data))
        } catch {
            return nil
        }
    }
    
    /// Convert 5-bit words to 8-bit byte array
    private func convertBits5to8(_ data: Data) -> [UInt8]? {
        var acc = 0
        var bits = 0
        var result: [UInt8] = []
        
        for v in data {
            if v >> 5 != 0 { return nil } // value must be less than 32
            acc = (acc << 5) | Int(v)
            bits += 5
            while bits >= 8 {
                bits -= 8
                let byte = UInt8((acc >> bits) & 0xFF)
                result.append(byte)
            }
        }
        
        return result
    }
    
    // MARK: - NIP-19 Identifier Parsing
    
    /// Parse npub and extract pubkey
    func parseNpub(_ npub: String) -> String? {
        guard npub.lowercased().hasPrefix("npub") else { return nil }
        
        guard let (prefix, data) = decodeBech32(npub),
              prefix.lowercased() == "npub",
              data.count == 32 else {
            return nil
        }
        
        return data.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Parse note and extract event ID
    func parseNote(_ note: String) -> String? {
        guard note.lowercased().hasPrefix("note") else { return nil }
        
        guard let (prefix, data) = decodeBech32(note),
              prefix.lowercased() == "note",
              data.count == 32 else {
            return nil
        }
        
        return data.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Parse nprofile and extract pubkey
    func parseNprofile(_ nprofile: String) -> String? {
        guard nprofile.lowercased().hasPrefix("nprofile") else { return nil }
        
        guard let (prefix, data) = decodeBech32(nprofile),
              prefix.lowercased() == "nprofile" else {
            return nil
        }
        
        // nprofile format: [pubkey, relay1, relay2, ...]
        // First 32 bytes are the pubkey
        guard data.count >= 32 else { return nil }
        let pubkeyData = data.prefix(32)
        return pubkeyData.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Parse nevent and extract event ID
    func parseNevent(_ nevent: String) -> String? {
        guard nevent.lowercased().hasPrefix("nevent") else { return nil }
        
        guard let (prefix, data) = decodeBech32(nevent),
              prefix.lowercased() == "nevent" else {
            return nil
        }
        
        // nevent format: [eventId, relay1, relay2, ...]
        // First 32 bytes are the event ID
        guard data.count >= 32 else { return nil }
        let eventIdData = data.prefix(32)
        return eventIdData.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - NIP-21 URI Parsing
    
    /// Parse NIP-21 URI and extract relevant information
    func parseNIP21URI(_ uri: String) -> NIP21Data? {
        guard uri.hasPrefix("nostr:") else { return nil }
        
        let content = String(uri.dropFirst(6)) // Remove "nostr:" prefix
        
        // Handle different NIP-21 formats
        if content.hasPrefix("npub") {
            if let pubkey = parseNpub(content) {
                return NIP21Data(type: .npub, identifier: pubkey, original: content)
            }
        } else if content.hasPrefix("note") {
            if let eventId = parseNote(content) {
                return NIP21Data(type: .note, identifier: eventId, original: content)
            }
        } else if content.hasPrefix("nprofile") {
            if let pubkey = parseNprofile(content) {
                return NIP21Data(type: .nprofile, identifier: pubkey, original: content)
            }
        } else if content.hasPrefix("nevent") {
            if let eventId = parseNevent(content) {
                return NIP21Data(type: .nevent, identifier: eventId, original: content)
            }
        } else {
            // Handle hex format directly
            if content.count == 64 && content.range(of: "^[0-9a-fA-F]{64}$", options: .regularExpression) != nil {
                // Could be either pubkey or event ID, we'll treat as pubkey for now
                return NIP21Data(type: .hex, identifier: content, original: content)
            }
        }
        
        return nil
    }
    
    // MARK: - Content Parsing
    
    /// Extract all NIP-19 and NIP-21 identifiers from content
    func extractIdentifiers(from content: String) -> [NostrIdentifier] {
        var identifiers: [NostrIdentifier] = []
        
        // Regular expressions for different identifier types
        let patterns = [
            // NIP-21 URIs
            "nostr:([a-zA-Z0-9]+[a-zA-Z0-9]*[a-zA-Z0-9]*)",
            // NIP-19 identifiers
            "\\b(npub[a-zA-Z0-9]+)\\b",
            "\\b(note[a-zA-Z0-9]+)\\b",
            "\\b(nprofile[a-zA-Z0-9]+)\\b",
            "\\b(nevent[a-zA-Z0-9]+)\\b",
            // Hex pubkeys/event IDs
            "\\b([0-9a-fA-F]{64})\\b"
        ]
        
        for pattern in patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: content.utf16.count)
            
            regex?.enumerateMatches(in: content, options: [], range: range) { match, _, _ in
                guard let match = match else { return }
                
                // Safely convert NSRange to Range<String.Index>
                guard let matchRange = Range(match.range, in: content) else { return }
                let matchedString = String(content[matchRange])
                
                // Parse the matched identifier
                if let identifier = parseIdentifier(matchedString) {
                    // Create a new identifier with the range information
                    let identifierWithRange = NostrIdentifier(
                        type: identifier.type,
                        identifier: identifier.identifier,
                        original: identifier.original,
                        range: matchRange
                    )
                    identifiers.append(identifierWithRange)
                }
            }
        }
        
        return identifiers
    }
    
    /// Parse a single identifier string
    private func parseIdentifier(_ identifier: String) -> NostrIdentifier? {
        // Try NIP-21 URI first
        if identifier.hasPrefix("nostr:") {
            if let nip21Data = parseNIP21URI(identifier) {
                return NostrIdentifier(
                    type: nip21Data.type,
                    identifier: nip21Data.identifier,
                    original: nip21Data.original,
                    range: nil
                )
            }
        }
        
        // Try NIP-19 formats
        if identifier.hasPrefix("npub") {
            if let pubkey = parseNpub(identifier) {
                return NostrIdentifier(
                    type: .npub,
                    identifier: pubkey,
                    original: identifier,
                    range: nil
                )
            }
        } else if identifier.hasPrefix("note") {
            if let eventId = parseNote(identifier) {
                return NostrIdentifier(
                    type: .note,
                    identifier: eventId,
                    original: identifier,
                    range: nil
                )
            }
        } else if identifier.hasPrefix("nprofile") {
            if let pubkey = parseNprofile(identifier) {
                return NostrIdentifier(
                    type: .nprofile,
                    identifier: pubkey,
                    original: identifier,
                    range: nil
                )
            }
        } else if identifier.hasPrefix("nevent") {
            if let eventId = parseNevent(identifier) {
                return NostrIdentifier(
                    type: .nevent,
                    identifier: eventId,
                    original: identifier,
                    range: nil
                )
            }
        } else if identifier.count == 64 && identifier.range(of: "^[0-9a-fA-F]{64}$", options: .regularExpression) != nil {
            // Hex format - assume pubkey for now
            return NostrIdentifier(
                type: .hex,
                identifier: identifier,
                original: identifier,
                range: nil
            )
        }
        
        return nil
    }
    
    // MARK: - Utility Methods
    
    /// Check if a string is a valid NIP-19 or NIP-21 identifier
    func isValidIdentifier(_ string: String) -> Bool {
        return parseIdentifier(string) != nil
    }
    
    /// Convert any valid identifier to hex format
    func toHex(_ identifier: String) -> String? {
        if let parsed = parseIdentifier(identifier) {
            return parsed.identifier
        }
        return nil
    }
}

// MARK: - Data Structures

struct NIP21Data {
    let type: NIP21Type
    let identifier: String
    let original: String
}

enum NIP21Type {
    case npub
    case note
    case nprofile
    case nevent
    case hex
}

struct NostrIdentifier {
    let type: NIP21Type
    let identifier: String  // Hex format
    let original: String    // Original format
    let range: Range<String.Index>?  // Position in content
}

// MARK: - Bech32 Implementation

/// Simple Bech32 implementation for NIP-19
struct Bech32 {
    private static let charset = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
    private static let generator = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
    
    static func decode(_ bech32String: String) throws -> (String, Data) {
        guard bech32String.count >= 8 else {
            throw Bech32Error.invalidLength
        }
        
        // Convert to lowercase for processing
        let lowercased = bech32String.lowercased()
        
        // Find the separator
        guard let separatorIndex = lowercased.lastIndex(of: "1") else {
            throw Bech32Error.noSeparator
        }
        
        let prefix = String(lowercased[..<separatorIndex])
        let dataString = String(lowercased[lowercased.index(after: separatorIndex)...])
        
        // Convert data string to 5-bit values
        var data: [UInt8] = []
        for char in dataString {
            guard let index = charset.firstIndex(of: char) else {
                throw Bech32Error.invalidCharacter
            }
            data.append(UInt8(charset.distance(from: charset.startIndex, to: index)))
        }
        
        // Verify checksum
        guard verifyChecksum(prefix: prefix, data: data) else {
            throw Bech32Error.invalidChecksum
        }
        
        // Remove checksum (last 6 values)
        let payload = Array(data.dropLast(6))
        
        return (prefix, Data(payload))
    }
    
    private static func verifyChecksum(prefix: String, data: [UInt8]) -> Bool {
        var values = expandHRP(prefix)
        values.append(contentsOf: data)
        
        let checksum = polymod(values)
        return checksum == 1
    }
    
    private static func expandHRP(_ hrp: String) -> [UInt8] {
        var result: [UInt8] = []
        
        for char in hrp {
            result.append(UInt8(char.asciiValue! >> 5))
        }
        result.append(0)
        
        for char in hrp {
            result.append(UInt8(char.asciiValue! & 31))
        }
        
        return result
    }
    
    private static func polymod(_ values: [UInt8]) -> Int {
        var chk = 1
        
        for value in values {
            let top = chk >> 25
            chk = ((chk & 0x1ffffff) << 5) ^ Int(value)
            
            for i in 0..<5 {
                if (top >> i) & 1 != 0 {
                    chk ^= generator[i]
                }
            }
        }
        
        return chk
    }
}

enum Bech32Error: Error {
    case invalidLength
    case noSeparator
    case invalidCharacter
    case invalidChecksum
} 