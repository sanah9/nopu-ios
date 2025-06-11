#ifndef NOSTR_FFI_H
#define NOSTR_FFI_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Key management functions
void* nostr_keys_generate(void);
void* nostr_keys_from_nsec(const char* nsec);
int32_t nostr_keys_public_key(void* keys, char* output, int32_t len);
int32_t nostr_keys_secret_key(void* keys, char* output, int32_t len);
void nostr_keys_free(void* keys);

// Event management functions
void* nostr_event_builder_text_note(const char* content, void* keys);
int32_t nostr_event_as_json(void* event, char* output, int32_t len);
void nostr_event_free(void* event);

// Client management functions
void* nostr_client_new(void);
int32_t nostr_client_add_relay(void* client, const char* url);
int32_t nostr_client_connect(void* client);
int32_t nostr_client_send_event(void* client, void* event);
void nostr_client_free(void* client);

#ifdef __cplusplus
}
#endif

#endif // NOSTR_FFI_H 