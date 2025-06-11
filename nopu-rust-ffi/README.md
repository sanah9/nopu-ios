# Nostr iOS SDK - Rust FFI

This project provides complete Nostr protocol support for iOS applications by binding the `rust-nostr/nostr-sdk` Rust library to Swift using UniFFI.

## Project Overview

- **Rust Library**: Based on `nostr-sdk 0.42`, providing complete Nostr protocol implementation
- **FFI Technology**: Uses UniFFI to automatically generate Swift bindings
- **iOS Support**: Generates XCFramework supporting iOS devices, simulator, and macOS

## Project Structure

```
nopu-rust-ffi/
├── Cargo.toml              # Rust project configuration
├── build.rs                # UniFFI build script
├── build-ios.sh            # iOS build script
├── src/
│   ├── lib.rs              # Rust FFI implementation
│   ├── nopu_ffi.udl        # UniFFI interface definition
│   └── bin/
│       └── uniffi-bindgen.rs  # Binding generator
└── bindings/               # Generated binding files
    ├── nopu_ffi.swift      # Swift bindings
    ├── nopu_ffiFFI.h       # C header file
    └── nopu_ffiFFI.modulemap  # Module mapping
```

## Features

### Core Features
- ✅ Nostr key pair generation and management
- ✅ Event creation, signing, and verification
- ✅ Relay server connection management
- ✅ Event publishing and querying
- ✅ User metadata management
- ✅ Subscriptions and real-time event streams
- ✅ Private messages (NIP-04)
- ✅ Error handling and type safety

### Swift API

```swift
// Generate keys
let keys = generateKeys()

// Create client
let client = try NostrClient(keys: keys)

// Add relay
try client.addRelay(url: "wss://relay.damus.io")

// Connect
try client.connect()

// Publish note
let eventId = try client.publishTextNote(content: "Hello Nostr!", tags: nil)

// Query events
let filter = NostrFilter(
    ids: nil,
    authors: [keys.publicKey],
    kinds: [1],
    since: nil,
    until: nil,
    limit: 10,
    search: nil
)
let events = try client.fetchEvents(filter: filter, timeoutSeconds: 5)
```

## Data Types

### NostrKeys
```swift
public struct NostrKeys {
    public var publicKey: String
    public var privateKey: String
}
```

### NostrEvent
```swift
public struct NostrEvent {
    public var id: String
    public var pubkey: String
    public var createdAt: UInt64
    public var kind: UInt16
    public var tags: [[String]]
    public var content: String
    public var sig: String
}
```

### NostrFilter
```swift
public struct NostrFilter {
    public var ids: [String]?
    public var authors: [String]?
    public var kinds: [UInt16]?
    public var since: UInt64?
    public var until: UInt64?
    public var limit: UInt64?
    public var search: String?
}
```

### NostrMetadata
```swift
public struct NostrMetadata {
    public var name: String?
    public var about: String?
    public var picture: String?
    public var banner: String?
    public var displayName: String?
    public var nip05: String?
    public var lud16: String?
    public var website: String?
}
```

## Build Instructions

### Prerequisites
- Rust 1.70+
- Xcode 14+
- iOS deployment target 13.0+

### Build Steps

1. **Build Rust library**:
```bash
cargo build --release
```

2. **Generate Swift bindings**:
```bash
cargo run --bin uniffi-bindgen -- generate --library target/debug/libnopu_rust_ffi.dylib --language swift --out-dir bindings
```

3. **Build iOS framework**:
```bash
./build-ios.sh
```

This will generate:
- `../nopu/NopuFFI.xcframework` - iOS framework
- `./NostrFFI.swift` - Swift binding file
- `./include/nopu_ffiFFI.h` - C header file
- `./include/nopu_ffiFFI.modulemap` - Module map file

## Integration into iOS Project

1. **Add XCFramework**:
   - Drag `NopuFFI.xcframework` into your Xcode project
   - Make sure it's set to "Embed & Sign" in "Frameworks, Libraries, and Embedded Content"

2. **Import Swift bindings**:
   - Copy `NostrFFI.swift` from the `nopu-rust-ffi` directory to your project

3. **Use the API**:
```swift
import Foundation

// Simple example
let keys = generateKeys()
let client = try NostrClient(keys: keys)
try client.addRelay(url: "wss://relay.damus.io")
try client.connect()
```

## Error Handling

All operations that can fail will throw `NostrError`:

```swift
public enum NostrError: Error {
    case invalidHex(String)
    case invalidPublicKey(String)
    case invalidPrivateKey(String)
    case relayConnectionFailed(String)
    case eventCreationFailed(String)
    case eventPublishingFailed(String)
    case eventQueryFailed(String)
    case subscriptionFailed(String)
    case generic(String)
}
```

## Dependency Versions

- `nostr-sdk`: 0.42.0
- `uniffi`: 0.29.3
- `tokio`: 1.0 (full features)

## Contributing

Issues and Pull Requests are welcome!

## License

This project is licensed under the MIT License.

## Acknowledgments

- [rust-nostr](https://github.com/rust-nostr/nostr) - Excellent Rust Nostr implementation
- [UniFFI](https://mozilla.github.io/uniffi-rs/) - Mozilla's multi-language binding tool
- [Nostr Protocol](https://github.com/nostr-protocol/nostr) - Decentralized social network protocol 