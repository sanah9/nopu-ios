import Foundation

// MARK: - C Function Declarations
// These are the functions we need to define in the C header file

// Key management
@_silgen_name("nostr_keys_generate")
func nostr_keys_generate() -> UnsafeMutableRawPointer?

@_silgen_name("nostr_keys_from_nsec")
func nostr_keys_from_nsec(nsec: UnsafePointer<CChar>) -> UnsafeMutableRawPointer?

@_silgen_name("nostr_keys_public_key")
func nostr_keys_public_key(keys: UnsafeMutableRawPointer, output: UnsafeMutablePointer<CChar>, len: Int32) -> Int32

@_silgen_name("nostr_keys_secret_key")
func nostr_keys_secret_key(keys: UnsafeMutableRawPointer, output: UnsafeMutablePointer<CChar>, len: Int32) -> Int32

@_silgen_name("nostr_keys_free")
func nostr_keys_free(keys: UnsafeMutableRawPointer)

// Event management
@_silgen_name("nostr_event_builder_text_note")
func nostr_event_builder_text_note(content: UnsafePointer<CChar>, keys: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?

@_silgen_name("nostr_event_as_json")
func nostr_event_as_json(event: UnsafeMutableRawPointer, output: UnsafeMutablePointer<CChar>, len: Int32) -> Int32

@_silgen_name("nostr_event_free")
func nostr_event_free(event: UnsafeMutableRawPointer)

// Client management
@_silgen_name("nostr_client_new")
func nostr_client_new() -> UnsafeMutableRawPointer?

@_silgen_name("nostr_client_add_relay")
func nostr_client_add_relay(client: UnsafeMutableRawPointer, url: UnsafePointer<CChar>) -> Int32

@_silgen_name("nostr_client_connect")
func nostr_client_connect(client: UnsafeMutableRawPointer) -> Int32

@_silgen_name("nostr_client_send_event")
func nostr_client_send_event(client: UnsafeMutableRawPointer, event: UnsafeMutableRawPointer) -> Int32

@_silgen_name("nostr_client_free")
func nostr_client_free(client: UnsafeMutableRawPointer)

// MARK: - Swift Wrapper Classes

public class NostrKeys {
    private let ptr: UnsafeMutableRawPointer
    
    public init?() {
        guard let ptr = nostr_keys_generate() else { return nil }
        self.ptr = ptr
    }
    
    public init?(nsec: String) {
        guard let ptr = nsec.withCString({ nostr_keys_from_nsec(nsec: $0) }) else { return nil }
        self.ptr = ptr
    }
    
    public var publicKey: String? {
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: 128)
        defer { buffer.deallocate() }
        
        let result = nostr_keys_public_key(keys: ptr, output: buffer, len: 128)
        guard result == 0 else { return nil }
        
        return String(cString: buffer)
    }
    
    public var secretKey: String? {
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: 128)
        defer { buffer.deallocate() }
        
        let result = nostr_keys_secret_key(keys: ptr, output: buffer, len: 128)
        guard result == 0 else { return nil }
        
        return String(cString: buffer)
    }
    
    deinit {
        nostr_keys_free(ptr)
    }
}

public class NostrEvent {
    private let ptr: UnsafeMutableRawPointer
    
    internal init(ptr: UnsafeMutableRawPointer) {
        self.ptr = ptr
    }
    
    public static func textNote(content: String, keys: NostrKeys) -> NostrEvent? {
        guard let eventPtr = content.withCString({ 
            nostr_event_builder_text_note(content: $0, keys: keys.ptr) 
        }) else { return nil }
        
        return NostrEvent(ptr: eventPtr)
    }
    
    public func asJSON() -> String? {
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: 4096)
        defer { buffer.deallocate() }
        
        let result = nostr_event_as_json(event: ptr, output: buffer, len: 4096)
        guard result == 0 else { return nil }
        
        return String(cString: buffer)
    }
    
    deinit {
        nostr_event_free(ptr)
    }
}

public class NostrClient {
    private let ptr: UnsafeMutableRawPointer
    
    public init?() {
        guard let ptr = nostr_client_new() else { return nil }
        self.ptr = ptr
    }
    
    public func addRelay(_ url: String) -> Bool {
        return url.withCString { 
            nostr_client_add_relay(client: ptr, url: $0) == 0 
        }
    }
    
    public func connect() -> Bool {
        return nostr_client_connect(client: ptr) == 0
    }
    
    public func sendEvent(_ event: NostrEvent) -> Bool {
        return nostr_client_send_event(client: ptr, event: event.ptr) == 0
    }
    
    deinit {
        nostr_client_free(ptr)
    }
}

// MARK: - Convenience Extensions

extension NostrClient {
    public func sendTextNote(_ content: String, with keys: NostrKeys) -> Bool {
        guard let event = NostrEvent.textNote(content: content, keys: keys) else {
            return false
        }
        return sendEvent(event)
    }
}

// MARK: - Error Handling

public enum NostrError: Error {
    case keyGenerationFailed
    case eventCreationFailed
    case clientConnectionFailed
    case relayAddFailed
    case eventSendFailed
    case jsonSerializationFailed
    
    public var localizedDescription: String {
        switch self {
        case .keyGenerationFailed:
            return "Key generation failed"
        case .eventCreationFailed:
            return "Event creation failed"
        case .clientConnectionFailed:
            return "Client connection failed"
        case .relayAddFailed:
            return "Relay addition failed"
        case .eventSendFailed:
            return "Event sending failed"
        case .jsonSerializationFailed:
            return "JSON serialization failed"
        }
    }
} 