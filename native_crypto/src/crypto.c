#include "native_crypto.h" // Include the header file for this module (presumably defines function prototypes)
#include <openssl/aead.h>   // Include BoringSSL/OpenSSL header for AEAD (Authenticated Encryption with Associated Data) operations
#include <openssl/err.h>    // Include BoringSSL/OpenSSL header for error handling
#include <string.h>         // Include standard C library for string operations (though not explicitly used in this snippet, often useful)
#include <stdio.h>          // Include standard C library for input/output operations (like fprintf)

/**
 * @brief Handles and prints BoringSSL/OpenSSL errors to stderr.
 *
 * This function retrieves and prints all errors currently in the BoringSSL/OpenSSL
 * error queue, prepending a custom context message.
 *
 * @param context_message A string describing the context in which the error occurred.
 */
static void handle_boringssl_errors(const char* context_message) {
    // Print the user-provided context message.
    fprintf(stderr, "BoringSSL/OpenSSL Error in %s:\n", context_message);
    unsigned long err_code;
    // Loop through the error queue until it's empty.
    while ((err_code = ERR_get_error()) != 0) {
        char err_buf[256]; // Buffer to hold the error string.
        // Convert the error code to a human-readable string.
        ERR_error_string_n(err_code, err_buf, sizeof(err_buf));
        // Print the error string to stderr.
        fprintf(stderr, "- %s\n", err_buf);
    }
}

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
 * The buffer should be large enough to hold plaintext_len + 16 bytes (for the tag).
 * @return The total number of bytes written (ciphertext + tag) on success,
 * -1 for invalid parameters or initialization errors,
 * or other negative values for encryption failures.
 */
int encrypt_aes_gcm_256(
        const uint8_t* plaintext, size_t plaintext_len,
        const uint8_t* key, const uint8_t* nonce, size_t nonce_len,
        const uint8_t* aad, size_t aad_len, uint8_t* out_ciphertext_tag
) {
    // Get the AEAD algorithm structure for AES-256-GCM.
    const EVP_AEAD *aead_alg = EVP_aead_aes_256_gcm();
    EVP_AEAD_CTX ctx; // AEAD context structure.
    size_t actual_out_len = 0; // Variable to store the actual length of the output.
    // Calculate the maximum possible output length (plaintext + tag overhead).
    size_t max_out_len = plaintext_len + EVP_AEAD_max_overhead(aead_alg);
    int result_status = -1; // Initialize result status to an error state.

    // --- Parameter Validation ---
    // Check for NULL pointers for essential inputs.
    if (!plaintext || !key || !nonce || !out_ciphertext_tag) return -1; // Invalid arguments
    // AES-256-GCM requires a 32-byte (256-bit) key.
    if (EVP_AEAD_key_length(aead_alg) != 32) return -1; // Should not happen with EVP_aead_aes_256_gcm, but good practice.
    // GCM standard nonce size is 12 bytes (96 bits).
    if (nonce_len != 12) return -1; // Invalid nonce length

    // --- AEAD Context Initialization ---
    // Initialize the AEAD context with the algorithm, key, key length, and default tag length.
    if (!EVP_AEAD_CTX_init(&ctx, aead_alg, key, EVP_AEAD_key_length(aead_alg),
                           EVP_AEAD_DEFAULT_TAG_LENGTH, NULL)) {
        handle_boringssl_errors("EVP_AEAD_CTX_init (encrypt AES)");
        goto cleanup_aes_encrypt; // Jump to cleanup on failure.
    }

    // --- Encryption (Seal Operation) ---
    // Perform the encryption and authentication.
    // EVP_AEAD_CTX_seal encrypts `plaintext` and generates an authentication tag.
    // The ciphertext and tag are written contiguously to `out_ciphertext_tag`.
    if (!EVP_AEAD_CTX_seal(&ctx, out_ciphertext_tag, &actual_out_len, max_out_len,
                           nonce, nonce_len, plaintext, plaintext_len, aad, aad_len)) {
        handle_boringssl_errors("EVP_AEAD_CTX_seal (AES)");
        goto cleanup_aes_encrypt; // Jump to cleanup on failure.
    }

    // If encryption was successful, set the result status to the actual output length.
    result_status = (int)actual_out_len;

    cleanup_aes_encrypt:
    // --- Cleanup ---
    // Clean up the AEAD context to free any allocated resources.
    EVP_AEAD_CTX_cleanup(&ctx);
    return result_status; // Return the result (output length or error code).
}

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
 * The buffer should be large enough to hold ciphertext_tag_len - 16 bytes (tag length).
 * @return The number of bytes written to out_plaintext on success (plaintext length),
 * -1 for invalid parameters or initialization errors,
 * -2 for authentication failure (tag mismatch) or if ciphertext_tag_len is too short.
 */
int decrypt_aes_gcm_256(
        const uint8_t* ciphertext_tag, size_t ciphertext_tag_len,
        const uint8_t* key, const uint8_t* nonce, size_t nonce_len,
        const uint8_t* aad, size_t aad_len, uint8_t* out_plaintext
) {
    // Get the AEAD algorithm structure for AES-256-GCM.
    const EVP_AEAD *aead_alg = EVP_aead_aes_256_gcm();
    EVP_AEAD_CTX ctx; // AEAD context structure.
    size_t actual_out_len = 0; // Variable to store the actual length of the decrypted plaintext.
    // For decryption, max_out_len is the ciphertext_tag_len itself, as plaintext cannot be larger.
    size_t max_out_len = ciphertext_tag_len;
    int result_status = -1; // Initialize result status to an error state.

    // --- Parameter Validation ---
    if (!ciphertext_tag || !key || !nonce || !out_plaintext) return -1; // Invalid arguments
    if (EVP_AEAD_key_length(aead_alg) != 32) return -1; // Key length check
    if (nonce_len != 12) return -1; // Nonce length check
    // Ciphertext + tag length must be at least the tag length.
    if (ciphertext_tag_len < EVP_AEAD_DEFAULT_TAG_LENGTH) return -2; // Input too short to contain a tag

    // --- AEAD Context Initialization ---
    if (!EVP_AEAD_CTX_init(&ctx, aead_alg, key, EVP_AEAD_key_length(aead_alg),
                           EVP_AEAD_DEFAULT_TAG_LENGTH, NULL)) {
        handle_boringssl_errors("EVP_AEAD_CTX_init (decrypt AES)");
        goto cleanup_aes_decrypt;
    }

    // --- Decryption (Open Operation) ---
    // Perform the decryption and authentication verification.
    // EVP_AEAD_CTX_open decrypts `ciphertext_tag` and verifies the authentication tag.
    // If verification fails, it returns 0 and no plaintext is written.
    if (!EVP_AEAD_CTX_open(&ctx, out_plaintext, &actual_out_len, max_out_len,
                           nonce, nonce_len, ciphertext_tag, ciphertext_tag_len, aad, aad_len)) {
        // Authentication failed or other decryption error.
        handle_boringssl_errors("EVP_AEAD_CTX_open (AES)");
        result_status = -2; // Indicate authentication/decryption failure
        goto cleanup_aes_decrypt;
    }

    // If decryption was successful, set the result status to the actual plaintext length.
    result_status = (int)actual_out_len;

    cleanup_aes_decrypt:
    // --- Cleanup ---
    EVP_AEAD_CTX_cleanup(&ctx);
    return result_status;
}

/**
 * @brief Encrypts plaintext using ChaCha20-Poly1305.
 *
 * @param plaintext Pointer to the plaintext data to encrypt.
 * @param plaintext_len Length of the plaintext data.
 * @param key Pointer to the 256-bit (32-byte) encryption key.
 * @param nonce Pointer to the nonce (IV). Recommended size is 12 bytes for ChaCha20-Poly1305.
 * @param nonce_len Length of the nonce.
 * @param aad Pointer to the Additional Associated Data (AAD). Can be NULL if aad_len is 0.
 * @param aad_len Length of the AAD.
 * @param out_ciphertext_tag Pointer to the output buffer where the ciphertext and authentication tag will be written.
 * The buffer should be large enough to hold plaintext_len + 16 bytes (for the tag).
 * @return The total number of bytes written (ciphertext + tag) on success,
 * -1 for invalid parameters or initialization errors,
 * or other negative values for encryption failures.
 */
int encrypt_chacha20_poly1305(
        const uint8_t* plaintext, size_t plaintext_len,
        const uint8_t* key, const uint8_t* nonce, size_t nonce_len,
        const uint8_t* aad, size_t aad_len, uint8_t* out_ciphertext_tag
) {
    // Get the AEAD algorithm structure for ChaCha20-Poly1305.
    const EVP_AEAD *aead_alg = EVP_aead_chacha20_poly1305();
    EVP_AEAD_CTX ctx;
    size_t actual_out_len = 0;
    size_t max_out_len = plaintext_len + EVP_AEAD_max_overhead(aead_alg); // Max output: plaintext + tag
    int result_status = -1;

    // --- Parameter Validation ---
    if (!plaintext || !key || !nonce || !out_ciphertext_tag) return -1;
    // ChaCha20-Poly1305 uses a 256-bit (32-byte) key.
    if (EVP_AEAD_key_length(aead_alg) != 32) return -1;
    // ChaCha20-Poly1305 typically uses a 12-byte (96-bit) nonce.
    if (nonce_len != 12) return -1;

    // --- AEAD Context Initialization ---
    if (!EVP_AEAD_CTX_init(&ctx, aead_alg, key, EVP_AEAD_key_length(aead_alg),
                           EVP_AEAD_DEFAULT_TAG_LENGTH, NULL)) {
        handle_boringssl_errors("EVP_AEAD_CTX_init (encrypt ChaCha)");
        goto cleanup_chacha_encrypt;
    }

    // --- Encryption (Seal Operation) ---
    if (!EVP_AEAD_CTX_seal(&ctx, out_ciphertext_tag, &actual_out_len, max_out_len,
                           nonce, nonce_len, plaintext, plaintext_len, aad, aad_len)) {
        handle_boringssl_errors("EVP_AEAD_CTX_seal (ChaCha)");
        goto cleanup_chacha_encrypt;
    }
    result_status = (int)actual_out_len;

    cleanup_chacha_encrypt:
    // --- Cleanup ---
    EVP_AEAD_CTX_cleanup(&ctx);
    return result_status;
}

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
 * The buffer should be large enough to hold ciphertext_tag_len - 16 bytes (tag length).
 * @return The number of bytes written to out_plaintext on success (plaintext length),
 * -1 for invalid parameters or initialization errors,
 * -2 for authentication failure (tag mismatch) or if ciphertext_tag_len is too short.
 */
int decrypt_chacha20_poly1305(
        const uint8_t* ciphertext_tag, size_t ciphertext_tag_len,
        const uint8_t* key, const uint8_t* nonce, size_t nonce_len,
        const uint8_t* aad, size_t aad_len, uint8_t* out_plaintext
) {
    // Get the AEAD algorithm structure for ChaCha20-Poly1305.
    const EVP_AEAD *aead_alg = EVP_aead_chacha20_poly1305();
    EVP_AEAD_CTX ctx;
    size_t actual_out_len = 0;
    size_t max_out_len = ciphertext_tag_len; // Plaintext cannot be larger than ciphertext + tag
    int result_status = -1;

    // --- Parameter Validation ---
    if (!ciphertext_tag || !key || !nonce || !out_plaintext) return -1;
    if (EVP_AEAD_key_length(aead_alg) != 32) return -1; // Key length check
    if (nonce_len != 12) return -1; // Nonce length check
    // Ciphertext + tag length must be at least the tag length.
    if (ciphertext_tag_len < EVP_AEAD_DEFAULT_TAG_LENGTH) return -2; // Input too short

    // --- AEAD Context Initialization ---
    if (!EVP_AEAD_CTX_init(&ctx, aead_alg, key, EVP_AEAD_key_length(aead_alg),
                           EVP_AEAD_DEFAULT_TAG_LENGTH, NULL)) {
        handle_boringssl_errors("EVP_AEAD_CTX_init (decrypt ChaCha)");
        goto cleanup_chacha_decrypt;
    }

    // --- Decryption (Open Operation) ---
    if (!EVP_AEAD_CTX_open(&ctx, out_plaintext, &actual_out_len, max_out_len,
                           nonce, nonce_len, ciphertext_tag, ciphertext_tag_len, aad, aad_len)) {
        handle_boringssl_errors("EVP_AEAD_CTX_open (ChaCha)");
        result_status = -2; // Indicate authentication/decryption failure
        goto cleanup_chacha_decrypt;
    }
    result_status = (int)actual_out_len;

    cleanup_chacha_decrypt:
    // --- Cleanup ---
    EVP_AEAD_CTX_cleanup(&ctx);
    return result_status;
}
