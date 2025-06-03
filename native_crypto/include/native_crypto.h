#ifndef NATIVE_CRYPTO_H
#define NATIVE_CRYPTO_H

#include <stddef.h> // For size_t
#include <stdint.h> // For uint8_t

// If compiled with a C++ compiler, use extern "C" to prevent name mangling
#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Encrypts plaintext using AES-256-GCM.
 *
 * @param plaintext Pointer to the plaintext data to encrypt.
 * @param plaintext_len Length of the plaintext data.
 * @param key Pointer to the 256-bit (32-byte) encryption key.
 * @param nonce Pointer to the nonce (Initialization Vector - IV). Recommended size is 12 bytes.
 * @param nonce_len Length of the nonce.
 * @param aad Pointer to the Additional Associated Data (AAD). Can be NULL if aad_len is 0.
 * @param aad_len Length of the AAD.
 * @param out_ciphertext_tag Pointer to the output buffer where the ciphertext and authentication tag will be written.
 * @return The total number of bytes written (ciphertext + tag) on success, or a negative error code.
 */
int encrypt_aes_gcm_256(
        const uint8_t* plaintext, size_t plaintext_len,
        const uint8_t* key,
        const uint8_t* nonce,     size_t nonce_len,
        const uint8_t* aad,       size_t aad_len,
        uint8_t* out_ciphertext_tag
);

/**
 * @brief Decrypts ciphertext using AES-256-GCM.
 *
 * @param ciphertext_tag Pointer to the combined ciphertext and authentication tag.
 * @param ciphertext_tag_len Length of the combined ciphertext and tag.
 * @param key Pointer to the 256-bit (32-byte) decryption key.
 * @param nonce Pointer to the nonce (IV) used during encryption.
 * @param nonce_len Length of the nonce (must be 12 bytes).
 * @param aad Pointer to the Additional Associated Data (AAD) used during encryption. Can be NULL if aad_len is 0.
 * @param aad_len Length of the AAD.
 * @param out_plaintext Pointer to the output buffer where the decrypted plaintext will be written.
 * @return The number of bytes written to out_plaintext on success (plaintext length), or a negative error code.
 */
int decrypt_aes_gcm_256(
        const uint8_t* ciphertext_tag, size_t ciphertext_tag_len,
        const uint8_t* key,
        const uint8_t* nonce,          size_t nonce_len,
        const uint8_t* aad,            size_t aad_len,
        uint8_t* out_plaintext
);

/**
 * @brief Encrypts plaintext using ChaCha20-Poly1305.
 *
 * @param plaintext Pointer to the plaintext data to encrypt.
 * @param plaintext_len Length of the plaintext data.
 * @param key Pointer to the 256-bit (32-byte) encryption key.
 * @param nonce Pointer to the nonce (IV). Recommended size is 12 bytes.
 * @param nonce_len Length of the nonce.
 * @param aad Pointer to the Additional Associated Data (AAD). Can be NULL if aad_len is 0.
 * @param aad_len Length of the AAD.
 * @param out_ciphertext_tag Pointer to the output buffer where the ciphertext and authentication tag will be written.
 * @return The total number of bytes written (ciphertext + tag) on success, or a negative error code.
 */
int encrypt_chacha20_poly1305(
        const uint8_t* plaintext, size_t plaintext_len,
        const uint8_t* key,
        const uint8_t* nonce,     size_t nonce_len,
        const uint8_t* aad,       size_t aad_len,
        uint8_t* out_ciphertext_tag
);

/**
 * @brief Decrypts ciphertext using ChaCha20-Poly1305.
 *
 * @param ciphertext_tag Pointer to the combined ciphertext and authentication tag.
 * @param ciphertext_tag_len Length of the combined ciphertext and tag.
 * @param key Pointer to the 256-bit (32-byte) decryption key.
 * @param nonce Pointer to the nonce (IV) used during encryption.
 * @param nonce_len Length of the nonce (must be 12 bytes).
 * @param aad Pointer to the Additional Associated Data (AAD) used during encryption. Can be NULL if aad_len is 0.
 * @param aad_len Length of the AAD.
 * @param out_plaintext Pointer to the output buffer where the decrypted plaintext will be written.
 * @return The number of bytes written to out_plaintext on success (plaintext length), or a negative error code.
 */
int decrypt_chacha20_poly1305(
        const uint8_t* ciphertext_tag, size_t ciphertext_tag_len,
        const uint8_t* key,
        const uint8_t* nonce,          size_t nonce_len,
        const uint8_t* aad,            size_t aad_len,
        uint8_t* out_plaintext
);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // NATIVE_CRYPTO_H
