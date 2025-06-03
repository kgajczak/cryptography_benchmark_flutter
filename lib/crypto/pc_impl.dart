// ignore_for_file: avoid_print // For print logs during debugging

import 'package:flutter/services.dart'; // Required for MethodChannel and PlatformException

/// Cryptographic service for communication with native Android code
/// via Platform Channels.
class PlatformChannelCryptoService {
  // Definition of the communication channel.
  // The name must be identical on the native side (Android).
  // We use a name consistent with your project.
  static const platform = MethodChannel(
    'com.example.cryptography_benchmark_flutter/crypto',
  );

  // Note: In this implementation, we operate on raw key bytes (Uint8List)
  // and nonce, as objects like SecretKey from the 'cryptography' package
  // cannot be directly passed through the platform channel.
  // Nonce will also be generated on the Dart side and passed.

  // --- AES-GCM ---

  /// Encrypts data using AES-GCM via Platform Channel.
  /// Passes plainText, key, and nonce to the native code.
  /// Expects encrypted data (ciphertext + MAC) to be returned as Uint8List.
  Future<Uint8List?> encryptAesGcm(
    Uint8List plainText,
    Uint8List key, // Raw key bytes (32 bytes for AES-256)
    Uint8List nonce, // Raw nonce bytes (12 bytes for AES-GCM)
  ) async {
    // Basic length validation on the Dart side
    if (key.length != 32) {
      print(
          "PC Error (AES Encrypt): Invalid key length (${key.length}), expected 32.");
      return null;
    }
    if (nonce.length != 12) {
      print(
          "PC Error (AES Encrypt): Invalid nonce length (${nonce.length}), expected 12.");
      return null;
    }

    try {
      // Invoking the native method 'encryptAesGcm'
      // Arguments are passed as a map.
      final Uint8List? result = await platform.invokeMethod('encryptAesGcm', {
        'plainText': plainText,
        'key': key,
        'nonce': nonce,
        // 'aad': aadData, // Optional AAD can be added if needed
      });
      return result; // Native code should return: ciphertext + MAC tag
    } on PlatformException catch (e) {
      // Communication error or execution error on the native side
      print("PlatformChannel Error (encryptAesGcm): ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      // Other unexpected errors
      print("Unexpected Error (encryptAesGcm): $e");
      return null;
    }
  }

  /// Decrypts data encrypted with AES-GCM via Platform Channel.
  /// Passes ciphertextTag (combined ciphertext and MAC), key, and nonce.
  /// Expects decrypted plaintext to be returned as Uint8List.
  Future<Uint8List?> decryptAesGcm(
    Uint8List ciphertextTag, // Combined ciphertext and MAC
    Uint8List key,
    Uint8List nonce,
  ) async {
    if (key.length != 32) {
      print(
          "PC Error (AES Decrypt): Invalid key length (${key.length}), expected 32.");
      return null;
    }
    if (nonce.length != 12) {
      print(
          "PC Error (AES Decrypt): Invalid nonce length (${nonce.length}), expected 12.");
      return null;
    }
    // ciphertextTag must contain at least the MAC (16 bytes for GCM)
    if (ciphertextTag.length < 16) {
      print("PC Error (AES Decrypt): ciphertextTag data is too short.");
      return null;
    }

    try {
      // Invoking the native method 'decryptAesGcm'
      final Uint8List? result = await platform.invokeMethod('decryptAesGcm', {
        'ciphertextTag': ciphertextTag,
        'key': key,
        'nonce': nonce,
        // 'aad': aadData, // Must match AAD used during encryption if any
      });
      return result; // Native code should return decrypted plaintext
    } on PlatformException catch (e) {
      print("PlatformChannel Error (decryptAesGcm): ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      print("Unexpected Error (decryptAesGcm): $e");
      return null;
    }
  }

  // --- ChaCha20-Poly1305 ---

  /// Encrypts data using ChaCha20-Poly1305 via Platform Channel.
  Future<Uint8List?> encryptChaCha(
    Uint8List plainText,
    Uint8List key, // Raw key bytes (32 bytes)
    Uint8List nonce, // Raw nonce bytes (12 bytes)
  ) async {
    if (key.length != 32) {
      print(
          "PC Error (ChaCha Encrypt): Invalid key length (${key.length}), expected 32.");
      return null;
    }
    if (nonce.length != 12) {
      print(
          "PC Error (ChaCha Encrypt): Invalid nonce length (${nonce.length}), expected 12.");
      return null;
    }

    try {
      // Invoking the native method 'encryptChaChaPoly'
      final Uint8List? result = await platform.invokeMethod(
        'encryptChaChaPoly', // Method name must match native code
        {
          'plainText': plainText,
          'key': key,
          'nonce': nonce,
          // 'aad': aadData,
        },
      );
      return result; // Native code should return: ciphertext + MAC tag (16B)
    } on PlatformException catch (e) {
      print(
          "PlatformChannel Error (encryptChaChaPoly): ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      print("Unexpected Error (encryptChaChaPoly): $e");
      return null;
    }
  }

  /// Decrypts data encrypted with ChaCha20-Poly1305 via Platform Channel.
  Future<Uint8List?> decryptChaCha(
    Uint8List ciphertextTag, // Combined ciphertext and MAC
    Uint8List key,
    Uint8List nonce,
  ) async {
    if (key.length != 32) {
      print(
          "PC Error (ChaCha Decrypt): Invalid key length (${key.length}), expected 32.");
      return null;
    }
    if (nonce.length != 12) {
      print(
          "PC Error (ChaCha Decrypt): Invalid nonce length (${nonce.length}), expected 12.");
      return null;
    }
    // ciphertextTag must contain at least the MAC (16 bytes for Poly1305)
    if (ciphertextTag.length < 16) {
      print("PC Error (ChaCha Decrypt): ciphertextTag data is too short.");
      return null;
    }

    try {
      // Invoking the native method 'decryptChaChaPoly'
      final Uint8List? result = await platform.invokeMethod(
        'decryptChaChaPoly', // Method name must match native code
        {
          'ciphertextTag': ciphertextTag,
          'key': key,
          'nonce': nonce,
          // 'aad': aadData,
        },
      );
      return result; // Native code should return decrypted plaintext
    } on PlatformException catch (e) {
      print(
          "PlatformChannel Error (decryptChaChaPoly): ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      print("Unexpected Error (decryptChaChaPoly): $e");
      return null;
    }
  }
}
