// ignore_for_file: avoid_print // For print logs during debugging

import 'dart:ffi'; // Core FFI types (Pointer, Int32, etc.)
import 'dart:io' show Platform; // For platform checking
import 'dart:typed_data';

import 'package:ffi/ffi.dart'; // For calloc (C memory allocation)

// --- FFI type definitions corresponding to signatures in native_crypto.h ---

// int encrypt_aes_gcm_256(...)
typedef EncryptAesGcmNative = Int32 Function(
    Pointer<Uint8> plaintext,
    IntPtr plaintextLen,
    Pointer<Uint8> key,
    Pointer<Uint8> nonce,
    IntPtr nonceLen,
    Pointer<Uint8> aad,
    IntPtr aadLen,
    Pointer<Uint8> outCiphertextTag);
typedef EncryptAesGcmDart = int Function(
    Pointer<Uint8> plaintext,
    int plaintextLen,
    Pointer<Uint8> key,
    Pointer<Uint8> nonce,
    int nonceLen,
    Pointer<Uint8> aad,
    int aadLen,
    Pointer<Uint8> outCiphertextTag);

// int decrypt_aes_gcm_256(...)
typedef DecryptAesGcmNative = Int32 Function(
    Pointer<Uint8> ciphertextTag,
    IntPtr ciphertextTagLen,
    Pointer<Uint8> key,
    Pointer<Uint8> nonce,
    IntPtr nonceLen,
    Pointer<Uint8> aad,
    IntPtr aadLen,
    Pointer<Uint8> outPlaintext);
typedef DecryptAesGcmDart = int Function(
    Pointer<Uint8> ciphertextTag,
    int ciphertextTagLen,
    Pointer<Uint8> key,
    Pointer<Uint8> nonce,
    int nonceLen,
    Pointer<Uint8> aad,
    int aadLen,
    Pointer<Uint8> outPlaintext);

// --- FFI type definitions for ChaCha20-Poly1305 ---
// int encrypt_chacha20_poly1305(...)
typedef EncryptChaChaNative = Int32 Function(
    Pointer<Uint8> plaintext,
    IntPtr plaintextLen,
    Pointer<Uint8> key,
    Pointer<Uint8> nonce,
    IntPtr nonceLen,
    Pointer<Uint8> aad,
    IntPtr aadLen,
    Pointer<Uint8> outCiphertextTag);
typedef EncryptChaChaDart = int Function(
    Pointer<Uint8> plaintext,
    int plaintextLen,
    Pointer<Uint8> key,
    Pointer<Uint8> nonce,
    int nonceLen,
    Pointer<Uint8> aad,
    int aadLen,
    Pointer<Uint8> outCiphertextTag);

// int decrypt_chacha20_poly1305(...)
typedef DecryptChaChaNative = Int32 Function(
    Pointer<Uint8> ciphertextTag,
    IntPtr ciphertextTagLen,
    Pointer<Uint8> key,
    Pointer<Uint8> nonce,
    IntPtr nonceLen,
    Pointer<Uint8> aad,
    IntPtr aadLen,
    Pointer<Uint8> outPlaintext);
typedef DecryptChaChaDart = int Function(
    Pointer<Uint8> ciphertextTag,
    int ciphertextTagLen,
    Pointer<Uint8> key,
    Pointer<Uint8> nonce,
    int nonceLen,
    Pointer<Uint8> aad,
    int aadLen,
    Pointer<Uint8> outPlaintext);

/// Cryptographic service for FFI (Foreign Function Interface) calls
/// to the native C library.
class FfiCryptoService {
  // Handles to the native functions
  late EncryptAesGcmDart _encryptAesGcm;
  late DecryptAesGcmDart _decryptAesGcm;
  late EncryptChaChaDart _encryptChaCha;
  late DecryptChaChaDart _decryptChaCha;

  /// Constructor that loads the native library and looks up functions.
  FfiCryptoService() {
    // Load the native library
    final DynamicLibrary nativeLib = _loadLibrary();

    // Look up C functions for AES-GCM
    _encryptAesGcm = nativeLib
        .lookup<NativeFunction<EncryptAesGcmNative>>("encrypt_aes_gcm_256")
        .asFunction<EncryptAesGcmDart>(); // Cast to a Dart function type

    _decryptAesGcm = nativeLib
        .lookup<NativeFunction<DecryptAesGcmNative>>("decrypt_aes_gcm_256")
        .asFunction<DecryptAesGcmDart>();

    // Look up C functions for ChaCha20-Poly1305
    _encryptChaCha = nativeLib
        .lookup<NativeFunction<EncryptChaChaNative>>(
            "encrypt_chacha20_poly1305")
        .asFunction<EncryptChaChaDart>();

    _decryptChaCha = nativeLib
        .lookup<NativeFunction<DecryptChaChaNative>>(
            "decrypt_chacha20_poly1305")
        .asFunction<DecryptChaChaDart>();
  }

  /// Helper to load the native library based on the platform.
  DynamicLibrary _loadLibrary() {
    if (Platform.isAndroid) {
      // On Android, Flutter automatically packages and locates .so libraries.
      // Provide its name as defined in CMakeLists.txt (without 'lib' prefix).
      try {
        return DynamicLibrary.open("libnative_crypto.so");
      } catch (e) {
        print("Error loading libnative_crypto.so: $e");
        // Re-throw to let the application know FFI is not working
        throw Exception("Could not load native crypto library for Android.");
      }
    } else if (Platform.isWindows) {
      // On Windows, the library will have a .dll extension.
      // Ensure 'native_crypto.dll' is in the search path
      // or provide the full path. Flutter for Windows usually places
      // DLLs next to the application executable.
      try {
        return DynamicLibrary.open("native_crypto.dll");
      } catch (e) {
        print("Error loading native_crypto.dll: $e");
        throw Exception("Could not load native crypto library for Windows.");
      }
    }
    // Add support for other platforms (iOS, macOS, Linux) if needed.
    throw UnsupportedError(
        "This FFI implementation currently only supports Android and Windows.");
  }

  /// Helper function to allocate C memory and copy data from a Uint8List.
  /// Returns a pointer that MUST be freed by calloc.free()!
  Pointer<Uint8> _allocatePointerFromList(Uint8List list) {
    final ptr = calloc.allocate<Uint8>(list.length);
    // Copy data from the Dart list to C memory
    ptr.asTypedList(list.length).setAll(0, list);
    return ptr;
  }

  /// Helper function to allocate an empty C buffer of a given size.
  /// Returns a pointer that MUST be freed by calloc.free()!
  Pointer<Uint8> _allocateBuffer(int size) {
    // calloc initializes memory to zeros, which is safer.
    // Check if size is negative (though Dart should catch this earlier).
    if (size < 0) throw ArgumentError("Buffer size cannot be negative");
    // If size is 0, allocating 1 byte is safer to get a valid pointer for free().
    // However, C functions might not expect zero-length buffers.
    // For this use case, if plaintext.length is 0, outBufferSize will be 16.
    // If decrypting only a tag (16B), outBufferSize could be 0.
    // C functions should handle 0-length output gracefully or return an error.
    return calloc.allocate<Uint8>(size > 0 ? size : 1);
  }

  // --- Wrappers for C functions (AES-GCM) ---

  /// Encrypts data using AES-GCM via FFI.
  Uint8List? encryptAesGcm(Uint8List plainText, Uint8List key, Uint8List nonce,
      {Uint8List? aad}) {
    // Dart-side validation (optional, C side also validates)
    if (key.length != 32 || nonce.length != 12) {
      print("FFI Error (AES Encrypt): Invalid key/nonce length.");
      return null;
    }

    // 1. Allocate C memory for input data
    final plainTextPtr = _allocatePointerFromList(plainText);
    final keyPtr = _allocatePointerFromList(key);
    final noncePtr = _allocatePointerFromList(nonce);
    Pointer<Uint8> aadPtr =
        nullptr; // Use a null pointer if aad is not provided
    int aadLen = 0;
    if (aad != null && aad.isNotEmpty) {
      aadPtr = _allocatePointerFromList(aad);
      aadLen = aad.length;
    }

    // 2. Allocate C memory for output data
    // Output buffer = ciphertext + tag (16 bytes for GCM)
    final outBufferSize = plainText.length + 16;
    final outPtr = _allocateBuffer(outBufferSize);

    Uint8List? resultData; // Resulting Dart byte list

    try {
      // 3. Call the C function via FFI
      final resultLen = _encryptAesGcm(
          plainTextPtr,
          plainText.length,
          keyPtr,
          noncePtr,
          nonce.length,
          aadPtr,
          aadLen,
          outPtr); // Pass the pointer to the output buffer

      // 4. Process the result
      if (resultLen >= 0) {
        // Success, copy the result from C memory to Uint8List
        // Copy only as many bytes as the C function returned
        resultData = Uint8List.fromList(outPtr.asTypedList(resultLen));
      } else {
        // Error reported by the C function (e.g., < 0)
        print(
            "FFI C function encrypt_aes_gcm_256 returned error code: $resultLen");
        resultData = null;
      }
    } catch (e) {
      // Error during the FFI call itself
      print("FFI call error (encryptAesGcm): $e");
      resultData = null;
    } finally {
      // 5. ALWAYS free the allocated C memory!
      calloc.free(plainTextPtr);
      calloc.free(keyPtr);
      calloc.free(noncePtr);
      if (aadPtr != nullptr) {
        calloc.free(aadPtr);
      }
      calloc.free(outPtr);
    }
    return resultData;
  }

  /// Decrypts data encrypted with AES-GCM via FFI.
  Uint8List? decryptAesGcm(
      Uint8List ciphertextTag, Uint8List key, Uint8List nonce,
      {Uint8List? aad}) {
    if (key.length != 32 || nonce.length != 12 || ciphertextTag.length < 16) {
      print("FFI Error (AES Decrypt): Invalid key/nonce/ciphertextTag length.");
      return null;
    }

    // 1. Allocate C memory for inputs
    final ciphertextTagPtr = _allocatePointerFromList(ciphertextTag);
    final keyPtr = _allocatePointerFromList(key);
    final noncePtr = _allocatePointerFromList(nonce);
    Pointer<Uint8> aadPtr = nullptr;
    int aadLen = 0;
    if (aad != null && aad.isNotEmpty) {
      aadPtr = _allocatePointerFromList(aad);
      aadLen = aad.length;
    }

    // 2. Allocate C memory for output (plaintext)
    // Max possible size = input size (ciphertext without tag)
    final outBufferSize = ciphertextTag.length - 16;
    // If outBufferSize is 0 (e.g., ciphertextTag only contains the tag), allocate a minimal buffer.
    // The C function should return 0 for empty plaintext or an error.
    final outPtr = _allocateBuffer(outBufferSize < 0 ? 0 : outBufferSize);

    Uint8List? resultData;

    try {
      // 3. Call the C function
      final resultLen = _decryptAesGcm(ciphertextTagPtr, ciphertextTag.length,
          keyPtr, noncePtr, nonce.length, aadPtr, aadLen, outPtr);

      // 4. Process the result
      if (resultLen >= 0) {
        // Success, copy the result
        // Ensure we don't read beyond the allocated buffer, though resultLen should be <= outBufferSize
        final safeResultLen =
            resultLen > outBufferSize ? outBufferSize : resultLen;
        resultData = Uint8List.fromList(outPtr.asTypedList(safeResultLen));
      } else {
        // Error from C (e.g., -2 for tag mismatch)
        print(
            "FFI C function decrypt_aes_gcm_256 returned error code: $resultLen");
        resultData = null;
      }
    } catch (e) {
      print("FFI call error (decryptAesGcm): $e");
      resultData = null;
    } finally {
      // 5. Free C memory
      calloc.free(ciphertextTagPtr);
      calloc.free(keyPtr);
      calloc.free(noncePtr);
      if (aadPtr != nullptr) {
        calloc.free(aadPtr);
      }
      calloc.free(outPtr);
    }
    return resultData;
  }

  // --- Wrappers for C functions (ChaCha20-Poly1305) ---
  Uint8List? encryptChaCha(Uint8List plainText, Uint8List key, Uint8List nonce,
      {Uint8List? aad}) {
    // ChaCha20 key: 32 bytes, Nonce: 12 bytes
    if (key.length != 32 || nonce.length != 12) {
      print("FFI Error (ChaCha Encrypt): Invalid key/nonce length.");
      return null;
    }

    // 1. Allocate C memory for inputs
    final plainTextPtr = _allocatePointerFromList(plainText);
    final keyPtr = _allocatePointerFromList(key);
    final noncePtr = _allocatePointerFromList(nonce);
    Pointer<Uint8> aadPtr = nullptr;
    int aadLen = 0;
    if (aad != null && aad.isNotEmpty) {
      aadPtr = _allocatePointerFromList(aad);
      aadLen = aad.length;
    }

    // 2. Allocate C memory for output
    // Output buffer = ciphertext + tag (16 bytes for Poly1305)
    final outBufferSize = plainText.length + 16;
    final outPtr = _allocateBuffer(outBufferSize);

    Uint8List? resultData;

    try {
      // 3. Call the C function
      final resultLen = _encryptChaCha(
          // Call the correct C function
          plainTextPtr,
          plainText.length,
          keyPtr,
          noncePtr,
          nonce.length,
          aadPtr,
          aadLen,
          outPtr);

      // 4. Process the result
      if (resultLen >= 0) {
        resultData = Uint8List.fromList(outPtr.asTypedList(resultLen));
      } else {
        print(
            "FFI C function encrypt_chacha20_poly1305 returned error code: $resultLen");
        resultData = null;
      }
    } catch (e) {
      print("FFI call error (encryptChaCha): $e");
      resultData = null;
    } finally {
      // 5. Free C memory
      calloc.free(plainTextPtr);
      calloc.free(keyPtr);
      calloc.free(noncePtr);
      if (aadPtr != nullptr) {
        calloc.free(aadPtr);
      }
      calloc.free(outPtr);
    }
    return resultData;
  }

  Uint8List? decryptChaCha(
      Uint8List ciphertextTag, Uint8List key, Uint8List nonce,
      {Uint8List? aad}) {
    if (key.length != 32 || nonce.length != 12 || ciphertextTag.length < 16) {
      print(
          "FFI Error (ChaCha Decrypt): Invalid key/nonce/ciphertextTag length.");
      return null;
    }

    // 1. Allocate C memory for inputs
    final ciphertextTagPtr = _allocatePointerFromList(ciphertextTag);
    final keyPtr = _allocatePointerFromList(key);
    final noncePtr = _allocatePointerFromList(nonce);
    Pointer<Uint8> aadPtr = nullptr;
    int aadLen = 0;
    if (aad != null && aad.isNotEmpty) {
      aadPtr = _allocatePointerFromList(aad);
      aadLen = aad.length;
    }

    // 2. Allocate C memory for output (plaintext)
    final outBufferSize = ciphertextTag.length - 16;
    final outPtr = _allocateBuffer(outBufferSize < 0 ? 0 : outBufferSize);
    Uint8List? resultData;

    try {
      // 3. Call the C function
      final resultLen = _decryptChaCha(
          // Call the correct C function
          ciphertextTagPtr,
          ciphertextTag.length,
          keyPtr,
          noncePtr,
          nonce.length,
          aadPtr,
          aadLen,
          outPtr);

      // 4. Process the result
      if (resultLen >= 0) {
        final safeResultLen =
            resultLen > outBufferSize ? outBufferSize : resultLen;
        resultData = Uint8List.fromList(outPtr.asTypedList(safeResultLen));
      } else {
        print(
            "FFI C function decrypt_chacha20_poly1305 returned error code: $resultLen");
        resultData = null;
      }
    } catch (e) {
      print("FFI call error (decryptChaCha): $e");
      resultData = null;
    } finally {
      // 5. Free C memory
      calloc.free(ciphertextTagPtr);
      calloc.free(keyPtr);
      calloc.free(noncePtr);
      if (aadPtr != nullptr) {
        calloc.free(aadPtr);
      }
      calloc.free(outPtr);
    }
    return resultData;
  }
}
