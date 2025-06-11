use nostr::prelude::*;
use nostr_sdk::prelude::*;
use std::sync::Arc;
use std::time::Duration;
use tokio::runtime::Runtime;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::ptr;

// UniFFI imports
uniffi::include_scaffolding!("nopu_ffi");

// Global runtime
lazy_static::lazy_static! {
    static ref RUNTIME: Runtime = Runtime::new().expect("Failed to create Tokio runtime");
}

#[derive(thiserror::Error, Debug)]
pub enum NostrError {
    #[error("Invalid hex: {0}")]
    InvalidHex(String),
    #[error("Invalid public key: {0}")]
    InvalidPublicKey(String),
    #[error("Invalid private key: {0}")]
    InvalidPrivateKey(String),
    #[error("Relay connection failed: {0}")]
    RelayConnectionFailed(String),
    #[error("Event creation failed: {0}")]
    EventCreationFailed(String),
    #[error("Event publishing failed: {0}")]
    EventPublishingFailed(String),
    #[error("Event query failed: {0}")]
    EventQueryFailed(String),
    #[error("Subscription failed: {0}")]
    SubscriptionFailed(String),
    #[error("Generic error: {0}")]
    Generic(String),
}

// Data structures
#[derive(Debug, Clone)]
pub struct NostrKeys {
    pub public_key: String,
    pub private_key: String,
}

#[derive(Debug, Clone)]
pub struct NostrEvent {
    pub id: String,
    pub pubkey: String,
    pub created_at: u64,
    pub kind: u16,
    pub tags: Vec<Vec<String>>,
    pub content: String,
    pub sig: String,
}

#[derive(Debug, Clone)]
pub struct NostrFilter {
    pub ids: Option<Vec<String>>,
    pub authors: Option<Vec<String>>,
    pub kinds: Option<Vec<u16>>,
    pub since: Option<u64>,
    pub until: Option<u64>,
    pub limit: Option<u64>,
    pub search: Option<String>,
}

#[derive(Debug, Clone)]
pub struct NostrMetadata {
    pub name: Option<String>,
    pub about: Option<String>,
    pub picture: Option<String>,
    pub banner: Option<String>,
    pub display_name: Option<String>,
    pub nip05: Option<String>,
    pub lud16: Option<String>,
    pub website: Option<String>,
}

#[derive(Debug, Clone)]
pub struct RelayInfo {
    pub url: String,
    pub status: String,
    pub connected: bool,
}

#[derive(Debug, Clone)]
pub struct SubscriptionResult {
    pub subscription_id: String,
    pub events: Vec<NostrEvent>,
}

pub struct NostrClient {
    client: Arc<Client>,
    runtime: Arc<Runtime>,
    keys: Keys,
}

impl NostrClient {
    pub fn new(keys: NostrKeys) -> Result<Self, NostrError> {
        let runtime = Arc::new(
            Runtime::new()
                .map_err(|e| NostrError::Generic(format!("Failed to create runtime: {}", e)))?
        );
        
        let secret_key = SecretKey::from_hex(&keys.private_key)
            .map_err(|e| NostrError::InvalidPrivateKey(e.to_string()))?;
        let my_keys = Keys::new(secret_key);
        
        let client = Client::new(my_keys.clone());
        
        Ok(Self {
            client: Arc::new(client),
            runtime,
            keys: my_keys,
        })
    }

    pub fn get_public_key(&self) -> Result<String, NostrError> {
        Ok(self.keys.public_key().to_hex())
    }

    pub fn add_relay(&self, url: String) -> Result<(), NostrError> {
        self.runtime.block_on(async {
            self.client.add_relay(&url).await
                .map_err(|_e| NostrError::RelayConnectionFailed(url.clone()))?;
            
            if let Err(_e) = self.client.connect_relay(&url).await {
                return Err(NostrError::RelayConnectionFailed(url));
            }
            
            Ok(())
        })
    }

    pub fn remove_relay(&self, url: String) -> Result<(), NostrError> {
        self.runtime.block_on(async {
            self.client.remove_relay(&url).await
                .map_err(|_e| NostrError::RelayConnectionFailed(url))?;
            Ok(())
        })
    }

    pub fn connect(&self) -> Result<(), NostrError> {
        self.runtime.block_on(async {
            self.client.connect().await;
            Ok(())
        })
    }

    pub fn disconnect(&self) -> Result<(), NostrError> {
        self.runtime.block_on(async {
            self.client.disconnect().await;
            Ok(())
        })
    }

    pub fn get_relay_status(&self) -> Vec<RelayInfo> {
        self.runtime.block_on(async {
            let relays = self.client.relays().await;
            let mut relay_infos = Vec::new();
            
            for (url, relay) in relays {
                let stats = relay.stats();
                let connected_at = stats.connected_at();
                let connected = connected_at.as_u64() > 0;
                
                relay_infos.push(RelayInfo {
                    url: url.to_string(),
                    status: if connected { "connected".to_string() } else { "disconnected".to_string() },
                    connected,
                });
            }
            
            relay_infos
        })
    }

    pub fn publish_text_note(&self, content: String, tags: Option<Vec<Vec<String>>>) -> Result<String, NostrError> {
        self.runtime.block_on(async {
            let mut builder = EventBuilder::text_note(&content);
            
            if let Some(tag_list) = tags {
                let mut parsed_tags = Vec::new();
                for tag in tag_list {
                    if tag.len() >= 2 {
                        if tag[0] == "t" {
                            parsed_tags.push(Tag::hashtag(&tag[1]));
                        } else if tag[0] == "e" {
                            if let Ok(event_id) = EventId::from_hex(&tag[1]) {
                                parsed_tags.push(Tag::event(event_id));
                            }
                        } else if tag[0] == "p" {
                            if let Ok(pubkey) = PublicKey::from_hex(&tag[1]) {
                                parsed_tags.push(Tag::public_key(pubkey));
                            }
                        }
                    }
                }
                
                if !parsed_tags.is_empty() {
                    builder = builder.tags(parsed_tags);
                }
            }
            
            let unsigned_event = builder.build(self.keys.public_key());
            let event = unsigned_event.sign(&self.keys).await
                .map_err(|e| NostrError::EventCreationFailed(e.to_string()))?;
            
            let event_id = self.client.send_event(&event).await
                .map_err(|e| NostrError::EventPublishingFailed(e.to_string()))?;
            
            Ok(event_id.to_hex())
        })
    }

    pub fn set_metadata(&self, metadata: NostrMetadata) -> Result<String, NostrError> {
        self.runtime.block_on(async {
            let mut nostr_metadata = Metadata::new();
            
            if let Some(name) = metadata.name {
                nostr_metadata = nostr_metadata.name(name);
            }
            if let Some(about) = metadata.about {
                nostr_metadata = nostr_metadata.about(about);
            }
            if let Some(picture) = metadata.picture {
                nostr_metadata = nostr_metadata.picture(Url::parse(&picture)
                    .map_err(|e| NostrError::Generic(e.to_string()))?);
            }
            if let Some(banner) = metadata.banner {
                nostr_metadata = nostr_metadata.banner(Url::parse(&banner)
                    .map_err(|e| NostrError::Generic(e.to_string()))?);
            }
            if let Some(display_name) = metadata.display_name {
                nostr_metadata = nostr_metadata.display_name(display_name);
            }
            if let Some(nip05) = metadata.nip05 {
                nostr_metadata = nostr_metadata.nip05(nip05);
            }
            if let Some(lud16) = metadata.lud16 {
                nostr_metadata = nostr_metadata.lud16(lud16);
            }
            if let Some(website) = metadata.website {
                nostr_metadata = nostr_metadata.website(Url::parse(&website)
                    .map_err(|e| NostrError::Generic(e.to_string()))?);
            }
            
            let builder = EventBuilder::metadata(&nostr_metadata);
            let unsigned_event = builder.build(self.keys.public_key());
            let event = unsigned_event.sign(&self.keys).await
                .map_err(|e| NostrError::EventCreationFailed(e.to_string()))?;
            
            let event_id = self.client.send_event(&event).await
                .map_err(|e| NostrError::EventPublishingFailed(e.to_string()))?;
            
            Ok(event_id.to_hex())
        })
    }

    pub fn fetch_events(&self, filter: NostrFilter, timeout_seconds: Option<u64>) -> Result<Vec<NostrEvent>, NostrError> {
        self.runtime.block_on(async {
            let timeout = Duration::from_secs(timeout_seconds.unwrap_or(10));
            
            let mut nostr_filter = Filter::new();
            
            if let Some(ids) = filter.ids {
                let event_ids: Result<Vec<EventId>, _> = ids.iter().map(|id| EventId::from_hex(id)).collect();
                nostr_filter = nostr_filter.ids(event_ids.map_err(|e| NostrError::InvalidHex(e.to_string()))?);
            }
            
            if let Some(authors) = filter.authors {
                let pubkeys: Result<Vec<PublicKey>, _> = authors.iter().map(|pk| PublicKey::from_hex(pk)).collect();
                nostr_filter = nostr_filter.authors(pubkeys.map_err(|e| NostrError::InvalidPublicKey(e.to_string()))?);
            }
            
            if let Some(kinds) = filter.kinds {
                let kinds: Vec<Kind> = kinds.into_iter().map(Kind::from).collect();
                nostr_filter = nostr_filter.kinds(kinds);
            }
            
            if let Some(since) = filter.since {
                nostr_filter = nostr_filter.since(Timestamp::from(since));
            }
            
            if let Some(until) = filter.until {
                nostr_filter = nostr_filter.until(Timestamp::from(until));
            }
            
            if let Some(limit) = filter.limit {
                nostr_filter = nostr_filter.limit(limit as usize);
            }
            
            let events = self.client.fetch_events(nostr_filter, timeout).await
                .map_err(|e| NostrError::EventQueryFailed(e.to_string()))?;
            
            let mut result_events = Vec::new();
            for e in events.iter() {
                result_events.push(NostrEvent {
                    id: e.id.to_hex(),
                    pubkey: e.pubkey.to_hex(),
                    created_at: e.created_at.as_u64(),
                    kind: e.kind.as_u16(),
                    tags: e.tags.iter().map(|t| t.clone().to_vec()).collect(),
                    content: e.content.clone(),
                    sig: format!("{:?}", e.sig),
                });
            }
            
            Ok(result_events)
        })
    }

    pub fn get_metadata(&self, _pubkey: String) -> Result<Option<NostrMetadata>, NostrError> {
        // Simplified implementation - actual usage requires event database support
        Err(NostrError::Generic("Metadata fetching requires database backend".to_string()))
    }

    pub fn subscribe(&self, filter: NostrFilter, auto_close_after: Option<u64>) -> Result<SubscriptionResult, NostrError> {
        self.runtime.block_on(async {
            let mut nostr_filter = Filter::new();
            
            if let Some(ids) = filter.ids {
                let event_ids: Result<Vec<EventId>, _> = ids.iter().map(|id| EventId::from_hex(id)).collect();
                nostr_filter = nostr_filter.ids(event_ids.map_err(|e| NostrError::InvalidHex(e.to_string()))?);
            }
            
            if let Some(authors) = filter.authors {
                let pubkeys: Result<Vec<PublicKey>, _> = authors.iter().map(|pk| PublicKey::from_hex(pk)).collect();
                nostr_filter = nostr_filter.authors(pubkeys.map_err(|e| NostrError::InvalidPublicKey(e.to_string()))?);
            }
            
            if let Some(kinds) = filter.kinds {
                let kinds: Vec<Kind> = kinds.into_iter().map(Kind::from).collect();
                nostr_filter = nostr_filter.kinds(kinds);
            }
            
            let auto_close_opts = auto_close_after.map(|seconds| {
                SubscribeAutoCloseOptions::default().timeout(Some(Duration::from_secs(seconds)))
            });
            
            let output = self.client.subscribe(nostr_filter, auto_close_opts).await
                .map_err(|e| NostrError::SubscriptionFailed(e.to_string()))?;
            
            Ok(SubscriptionResult {
                subscription_id: output.id().to_string(),
                events: Vec::new(),
            })
        })
    }

    pub fn unsubscribe(&self, subscription_id: String) -> Result<(), NostrError> {
        self.runtime.block_on(async {
            let sub_id = SubscriptionId::new(subscription_id);
            self.client.unsubscribe(&sub_id).await;
            Ok(())
        })
    }

    pub fn send_private_message(&self, receiver_pubkey: String, message: String) -> Result<String, NostrError> {
        self.runtime.block_on(async {
            let receiver = PublicKey::from_hex(&receiver_pubkey)
                .map_err(|e| NostrError::InvalidPublicKey(e.to_string()))?;
            
            // Create direct message event (kind 4)
            let builder = EventBuilder::new(Kind::EncryptedDirectMessage, &message)
                .tag(Tag::public_key(receiver));
            
            let unsigned_event = builder.build(self.keys.public_key());
            let event = unsigned_event.sign(&self.keys).await
                .map_err(|e| NostrError::EventCreationFailed(e.to_string()))?;
            
            let event_id = self.client.send_event(&event).await
                .map_err(|e| NostrError::EventPublishingFailed(e.to_string()))?;
            
            Ok(event_id.to_hex())
        })
    }
}

// Factory functions
pub fn generate_keys() -> NostrKeys {
    let keys = Keys::generate();
    NostrKeys {
        public_key: keys.public_key().to_hex(),
        private_key: keys.secret_key().display_secret().to_string(),
    }
}

pub fn keys_from_secret_key(secret_key_hex: String) -> Result<NostrKeys, NostrError> {
    let secret_key = SecretKey::from_hex(&secret_key_hex)
        .map_err(|e| NostrError::InvalidPrivateKey(e.to_string()))?;
    let keys = Keys::new(secret_key);
    
    Ok(NostrKeys {
        public_key: keys.public_key().to_hex(),
        private_key: keys.secret_key().display_secret().to_string(),
    })
}

pub fn pubkey_from_secret_key(secret_key_hex: String) -> Result<String, NostrError> {
    let secret_key = SecretKey::from_hex(&secret_key_hex)
        .map_err(|e| NostrError::InvalidPrivateKey(e.to_string()))?;
    let keys = Keys::new(secret_key);
    Ok(keys.public_key().to_hex())
}

// Key management
#[no_mangle]
pub extern "C" fn nostr_keys_generate() -> *mut Keys {
    match Keys::generate() {
        keys => Box::into_raw(Box::new(keys)),
    }
}

#[no_mangle]
pub extern "C" fn nostr_keys_from_nsec(nsec: *const c_char) -> *mut Keys {
    if nsec.is_null() {
        return ptr::null_mut();
    }
    
    let nsec_str = match unsafe { CStr::from_ptr(nsec) }.to_str() {
        Ok(s) => s,
        Err(_) => return ptr::null_mut(),
    };
    
    match Keys::parse(nsec_str) {
        Ok(keys) => Box::into_raw(Box::new(keys)),
        Err(_) => ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn nostr_keys_public_key(keys: *mut Keys, output: *mut c_char, len: i32) -> i32 {
    if keys.is_null() || output.is_null() || len <= 0 {
        return -1;
    }
    
    let keys = unsafe { &*keys };
    let public_key = keys.public_key().to_string();
    
    if public_key.len() >= len as usize {
        return -1;
    }
    
    let c_string = match CString::new(public_key) {
        Ok(s) => s,
        Err(_) => return -1,
    };
    
    unsafe {
        ptr::copy_nonoverlapping(c_string.as_ptr(), output, c_string.to_bytes().len() + 1);
    }
    
    0
}

#[no_mangle]
pub extern "C" fn nostr_keys_secret_key(keys: *mut Keys, output: *mut c_char, len: i32) -> i32 {
    if keys.is_null() || output.is_null() || len <= 0 {
        return -1;
    }
    
    let keys = unsafe { &*keys };
    let secret_key = keys.secret_key().to_secret_hex();
    
    if secret_key.len() >= len as usize {
        return -1;
    }
    
    let c_string = match CString::new(secret_key) {
        Ok(s) => s,
        Err(_) => return -1,
    };
    
    unsafe {
        ptr::copy_nonoverlapping(c_string.as_ptr(), output, c_string.to_bytes().len() + 1);
    }
    
    0
}

#[no_mangle]
pub extern "C" fn nostr_keys_free(keys: *mut Keys) {
    if !keys.is_null() {
        unsafe {
            let _box = Box::from_raw(keys);
        }
    }
}

// Event management
#[no_mangle]
pub extern "C" fn nostr_event_builder_text_note(content: *const c_char, keys: *mut Keys) -> *mut Event {
    if content.is_null() || keys.is_null() {
        return ptr::null_mut();
    }
    
    let content_str = match unsafe { CStr::from_ptr(content) }.to_str() {
        Ok(s) => s,
        Err(_) => return ptr::null_mut(),
    };
    
    let keys = unsafe { &*keys };
    
    match RUNTIME.block_on(EventBuilder::text_note(content_str).sign(keys)) {
        Ok(event) => Box::into_raw(Box::new(event)),
        Err(_) => ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn nostr_event_as_json(event: *mut Event, output: *mut c_char, len: i32) -> i32 {
    if event.is_null() || output.is_null() || len <= 0 {
        return -1;
    }
    
    let event = unsafe { &*event };
    let json = event.as_json();
    
    if json.len() >= len as usize {
        return -1;
    }
    
    let c_string = match CString::new(json) {
        Ok(s) => s,
        Err(_) => return -1,
    };
    
    unsafe {
        ptr::copy_nonoverlapping(c_string.as_ptr(), output, c_string.to_bytes().len() + 1);
    }
    
    0
}

#[no_mangle]
pub extern "C" fn nostr_event_free(event: *mut Event) {
    if !event.is_null() {
        unsafe {
            let _box = Box::from_raw(event);
        }
    }
}

// Client management
#[no_mangle]
pub extern "C" fn nostr_client_new() -> *mut Client {
    let client = Client::new(&Keys::generate());
    Box::into_raw(Box::new(client))
}

#[no_mangle]
pub extern "C" fn nostr_client_add_relay(client: *mut Client, url: *const c_char) -> i32 {
    if client.is_null() || url.is_null() {
        return -1;
    }
    
    let url_str = match unsafe { CStr::from_ptr(url) }.to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };
    
    let client = unsafe { &*client };
    
    RUNTIME.block_on(async {
        match client.add_relay(url_str).await {
            Ok(_) => 0,
            Err(_) => -1,
        }
    })
}

#[no_mangle]
pub extern "C" fn nostr_client_connect(client: *mut Client) -> i32 {
    if client.is_null() {
        return -1;
    }
    
    let client = unsafe { &*client };
    
    RUNTIME.block_on(async {
        match client.connect().await {
            () => 0,
        }
    })
}

#[no_mangle]
pub extern "C" fn nostr_client_send_event(client: *mut Client, event: *mut Event) -> i32 {
    if client.is_null() || event.is_null() {
        return -1;
    }
    
    let client = unsafe { &*client };
    let event = unsafe { &*event };
    
    RUNTIME.block_on(async {
        match client.send_event(&event.clone()).await {
            Ok(_) => 0,
            Err(_) => -1,
        }
    })
}

#[no_mangle]
pub extern "C" fn nostr_client_free(client: *mut Client) {
    if !client.is_null() {
        unsafe {
            let _box = Box::from_raw(client);
        }
    }
}
