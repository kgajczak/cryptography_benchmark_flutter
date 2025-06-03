import 'dart:math'; // For Random
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Cryptographic service implementing encryption/decryption
/// for AES-GCM and ChaCha20-Poly1305 using pure Dart
/// (utilizing the `package:cryptography`).
class DartCryptoService {
  // Initialize algorithms from the cryptography package
  // Using AES-GCM with a 256-bit key
  final AesGcm aesGcm = AesGcm.with256bits();
  // ChaCha20 with Poly1305 as AEAD (Authenticated Encryption with Associated Data)
  final Chacha20 chacha = Chacha20.poly1305Aead();

  /// Generates a new, random key for AES-GCM (256-bit).
  Future<SecretKey> generateAesKey() async {
    return await aesGcm.newSecretKey();
  }

  /// Generates a new, random key for ChaCha20-Poly1305 (256-bit).
  Future<SecretKey> generateChaChaKey() async {
    return await chacha.newSecretKey();
  }

  /// Generates a random nonce (initialization vector) of the specified length.
  /// IMPORTANT: Nonce must be unique for each encryption operation with the same key.
  Uint8List generateNonce(int length) {
    final random = Random.secure(); // Using a secure random number generator
    return Uint8List.fromList(
        List.generate(length, (_) => random.nextInt(256)));
  }

  // --- AES-GCM Implementation ---

  /// Encrypts data (plainText) using the AES-GCM algorithm.
  /// [plainText] - data to be encrypted.
  /// [secretKey] - key used for encryption.
  /// Returns a [Uint8List] containing the combined: nonce (12B) + encrypted data + MAC tag (16B).
  Future<Uint8List> encryptAesGcm(
      Uint8List plainText, SecretKey secretKey) async {
    // Generate a new, unique nonce for this encryption operation.
    // The standard and recommended nonce length for AES-GCM is 12 bytes (96 bits).
    final nonce = generateNonce(12);

    final secretBox = await aesGcm.encrypt(
      plainText,
      secretKey: secretKey,
      nonce: nonce,
      // associatedData: aad, // Optional authenticated data (AAD) can be added if needed
    );

    // Combine nonce, ciphertext, and MAC tag into a single byte array.
    // This format is often used for transmitting/storing encrypted data.
    // Nonce (12B) + Ciphertext + MAC (16B for GCM)
    return Uint8List.fromList(
        [...nonce, ...secretBox.cipherText, ...secretBox.mac.bytes]);
  }

  /// Decrypts data encrypted with the AES-GCM algorithm.
  /// [combinedData] - combined data: nonce + encrypted data + MAC tag.
  /// [secretKey] - key used for decryption (must be the same as used for encryption).
  /// Returns decrypted data as [Uint8List] or `null` in case of an error.
  Future<Uint8List?> decryptAesGcm(
      Uint8List combinedData, SecretKey secretKey) async {
    // Minimum expected length is nonce (12B) + MAC (16B for GCM).
    // If data is shorter, it's definitely incomplete.
    if (combinedData.length < 12 + 16) {
      // ignore: avoid_print
      print("Error (AES-GCM Decrypt): Combined data is too short.");
      return null;
    }
    try {
      // Extract components from the combined data
      final nonce = combinedData.sublist(0, 12);
      final macBytes = combinedData
          .sublist(combinedData.length - 16); // MAC tag is at the end
      final cipherText = combinedData.sublist(
          12, combinedData.length - 16); // The rest is ciphertext

      // Create a SecretBox object from the separated components
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));

      // Attempt to decrypt and verify the MAC tag
      final clearText = await aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
        // associatedData: aad, // Must match AAD used during encryption, if any
      );
      return Uint8List.fromList(clearText); // Return decrypted data
    } catch (e) {
      // ignore: avoid_print
      print("Decryption failed (AES-GCM): $e");
      return null; // Return null in case of an error (e.g., invalid MAC tag)
    }
  }

  // --- ChaCha20-Poly1305 Implementation ---

  /// Encrypts data (plainText) using the ChaCha20-Poly1305 algorithm.
  /// Returns a [Uint8List] containing the combined: nonce (12B) + encrypted data + MAC tag (16B).
  Future<Uint8List> encryptChaCha(
      Uint8List plainText, SecretKey secretKey) async {
    // The standard and recommended nonce length for ChaCha20-Poly1305 is 12 bytes.
    final nonce = generateNonce(12);

    final secretBox = await chacha.encrypt(
      plainText,
      secretKey: secretKey,
      nonce: nonce,
      // associatedData: aad, // Optional AAD can be added
    );

    // Nonce (12B) + Ciphertext + MAC (16B for Poly1305)
    return Uint8List.fromList(
        [...nonce, ...secretBox.cipherText, ...secretBox.mac.bytes]);
  }

  /// Decrypts data encrypted with the ChaCha20-Poly1305 algorithm.
  /// Expects combined data: nonce + encrypted data + MAC tag.
  Future<Uint8List?> decryptChaCha(
      Uint8List combinedData, SecretKey secretKey) async {
    // Minimum expected length is nonce (12B) + MAC (16B).
    if (combinedData.length < 12 + 16) {
      // ignore: avoid_print
      print("Error (ChaCha20-Poly1305 Decrypt): Combined data is too short.");
      return null;
    }
    try {
      // Extract components
      final nonce = combinedData.sublist(0, 12);
      final macBytes = combinedData
          .sublist(combinedData.length - 16); // MAC tag is at the end
      final cipherText = combinedData.sublist(
          12, combinedData.length - 16); // The rest is ciphertext

      // Create a SecretBox object
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));

      // Attempt to decrypt and verify the tag
      final clearText = await chacha.decrypt(
        secretBox,
        secretKey: secretKey,
        // associatedData: aad, // Must match AAD used during encryption
      );
      return Uint8List.fromList(clearText);
    } catch (e) {
      // ignore: avoid_print
      print("Decryption failed (ChaCha20-Poly1305): $e");
      return null;
    }
  }
}
