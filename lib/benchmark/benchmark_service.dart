// lib/benchmark/benchmark_service.dart
// ignore_for_file: avoid_print

import 'dart:math'; // Used for generating random numbers for keys and data.
import 'dart:typed_data'; // Used for handling byte arrays (Uint8List).

import 'package:cryptography/cryptography.dart'
    show
        SecretKey; // Used for representing cryptographic keys in the Dart implementation.

import '../crypto/common.dart'; // Contains common enums like ImplementationType and AlgorithmType.
import '../crypto/dart_impl.dart'; // Contains the Dart implementation of cryptographic operations.
import '../crypto/ffi_impl.dart'; // Contains the FFI (Foreign Function Interface) implementation of cryptographic operations.
import '../crypto/pc_impl.dart'; // Contains the Platform Channel implementation of cryptographic operations.

/// A service class for running cryptographic benchmarks.
///
/// This class handles the setup, execution, and result aggregation of benchmarks
/// for different cryptographic implementations (Dart, Platform Channel, FFI)
/// and algorithms (AES-GCM, ChaCha20-Poly1305).
class BenchmarkService {
  // Instances of the different crypto service implementations.
  final DartCryptoService _dartService = DartCryptoService();
  final PlatformChannelCryptoService _pcService =
      PlatformChannelCryptoService();
  final FfiCryptoService _ffiService = FfiCryptoService();

  // Keys used for benchmarking, specific to the Dart implementation's requirements.
  late SecretKey _aesKeyDartImpl;
  late SecretKey _chaKeyDartImpl;

  // Raw byte representations of the keys, used by FFI and Platform Channel implementations.
  late Uint8List _aesKeyRawBytes;
  late Uint8List _chaKeyRawBytes;

  /// Initializes the BenchmarkService by generating cryptographic keys.
  BenchmarkService() {
    _generateKeysForBenchmark();
    print("BenchmarkService: Keys for benchmark have been generated.");
  }

  /// Generates random 32-byte keys for AES and ChaCha20 algorithms.
  ///
  /// These keys are stored both as raw bytes and as `SecretKey` objects
  /// for compatibility with different crypto implementations.
  void _generateKeysForBenchmark() {
    final random = Random
        .secure(); // Use a cryptographically secure random number generator.
    // Generate a 32-byte (256-bit) AES key.
    _aesKeyRawBytes =
        Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
    // Generate a 32-byte (256-bit) ChaCha20 key.
    _chaKeyRawBytes =
        Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));

    // Wrap the raw key bytes in SecretKey objects for the Dart crypto library.
    _aesKeyDartImpl = SecretKey(_aesKeyRawBytes);
    _chaKeyDartImpl = SecretKey(_chaKeyRawBytes);
  }

  /// Generates a `Uint8List` of random bytes of the specified size.
  ///
  /// [sizeInBytes] The desired size of the random data in bytes.
  /// Returns a `Uint8List` filled with random bytes.
  Uint8List _generateRandomData(int sizeInBytes) {
    final random = Random.secure();
    return Uint8List.fromList(
        List.generate(sizeInBytes, (_) => random.nextInt(256)));
  }

  /// Generates a 12-byte random nonce (Number used ONCE).
  ///
  /// Nonces are crucial for the security of many cryptographic algorithms,
  /// ensuring that encrypting the same plaintext multiple times with the same key
  /// produces different ciphertexts.
  /// Returns a `Uint8List` representing the nonce.
  Uint8List _generateNonce() {
    final random = Random.secure();
    const int nonceSize =
        12; // Standard nonce size for AES-GCM and ChaCha20-Poly1305.
    return Uint8List.fromList(
        List.generate(nonceSize, (_) => random.nextInt(256)));
  }

  /// Runs a cryptographic benchmark with the specified parameters.
  ///
  /// [implType] The cryptographic implementation to use (Dart, FFI, Platform Channel).
  /// [algoType] The cryptographic algorithm to use (AES-GCM, ChaCha20).
  /// [dataSize] The size of the data to encrypt/decrypt in bytes.
  /// [iterations] The number of times to repeat the encryption/decryption operations.
  /// Returns a `Future<BenchmarkResult>` containing the results of the benchmark.
  Future<BenchmarkResult> runBenchmark({
    required ImplementationType implType,
    required AlgorithmType algoType,
    required int dataSize,
    required int iterations,
  }) async {
    // Validate input parameters.
    if (dataSize <= 0 || iterations <= 0) {
      return BenchmarkResult.error(
        implType: implType,
        algoType: algoType,
        dataSize: dataSize,
        iterations: iterations,
        message: "Data size and iterations must be positive.",
      );
    }

    // Generate random plaintext data for the benchmark.
    final plainText = _generateRandomData(dataSize);

    // Lists to store the duration of each encryption and decryption operation.
    final List<Duration> encryptDurations = [];
    final List<Duration> decryptDurations = [];

    print(
        "Starting benchmark: $implType, $algoType, size: $dataSize B, iterations: $iterations");

    try {
      // Loop for the specified number of iterations.
      for (int i = 0; i < iterations; i++) {
        Uint8List? encryptedData;
        // Generate a unique nonce for each encryption. This is critical for algorithms like AES-GCM and ChaCha20.
        final nonce = _generateNonce();
        final stopwatchEncrypt = Stopwatch()
          ..start(); // Start timing the encryption.

        // Perform encryption based on the selected implementation and algorithm.
        switch (implType) {
          case ImplementationType.dart:
            encryptedData = (algoType == AlgorithmType.aesGcm)
                ? await _dartService.encryptAesGcm(plainText, _aesKeyDartImpl)
                // Note: Dart's ChaCha20 implementation likely handles nonce internally or derives it.
                : await _dartService.encryptChaCha(plainText, _chaKeyDartImpl);
            break;
          case ImplementationType.platformChannel:
            encryptedData = (algoType == AlgorithmType.aesGcm)
                ? await _pcService.encryptAesGcm(
                    plainText, _aesKeyRawBytes, nonce)
                : await _pcService.encryptChaCha(
                    plainText, _chaKeyRawBytes, nonce);
            break;
          case ImplementationType.ffi:
            encryptedData = (algoType == AlgorithmType.aesGcm)
                ? _ffiService.encryptAesGcm(plainText, _aesKeyRawBytes, nonce)
                : _ffiService.encryptChaCha(plainText, _chaKeyRawBytes, nonce);
            break;
        }
        stopwatchEncrypt.stop(); // Stop timing.
        encryptDurations.add(stopwatchEncrypt.elapsed);

        // Ensure encryption produced data.
        if (encryptedData == null) {
          print("Encryption returned null! Iteration ${i + 1}");
          throw Exception(
              "Encryption failed (returned null) during iteration ${i + 1}");
        }

        Uint8List? decryptedData;
        final stopwatchDecrypt = Stopwatch()
          ..start(); // Start timing the decryption.

        // Perform decryption based on the selected implementation and algorithm.
        switch (implType) {
          case ImplementationType.dart:
            decryptedData = (algoType == AlgorithmType.aesGcm)
                ? await _dartService.decryptAesGcm(
                    encryptedData, _aesKeyDartImpl)
                : await _dartService.decryptChaCha(
                    encryptedData, _chaKeyDartImpl);
            break;
          case ImplementationType.platformChannel:
            decryptedData = (algoType == AlgorithmType.aesGcm)
                ? await _pcService.decryptAesGcm(
                    encryptedData, _aesKeyRawBytes, nonce)
                : await _pcService.decryptChaCha(
                    encryptedData, _chaKeyRawBytes, nonce);
            break;
          case ImplementationType.ffi:
            decryptedData = (algoType == AlgorithmType.aesGcm)
                ? _ffiService.decryptAesGcm(
                    encryptedData, _aesKeyRawBytes, nonce)
                : _ffiService.decryptChaCha(
                    encryptedData, _chaKeyRawBytes, nonce);
            break;
        }
        stopwatchDecrypt.stop(); // Stop timing.
        decryptDurations.add(stopwatchDecrypt.elapsed);

        // Ensure decryption produced data.
        if (decryptedData == null) {
          print("Decryption returned null! Iteration ${i + 1}");
          throw Exception(
              "Decryption failed (returned null) during iteration ${i + 1}");
        }
        // Verify that the decrypted data matches the original plaintext.
        if (!_compareLists(plainText, decryptedData)) {
          print("Verification failed! Iteration ${i + 1}");
          throw Exception("Verification failed during iteration ${i + 1}");
        }

        // Yield to the event loop every 100 iterations to prevent UI freezing.
        // This is important for benchmarks running a large number of iterations.
        if (i > 0 && i % 100 == 0) {
          await Future.delayed(Duration.zero);
        }
      } // End of iterations loop.

      // Calculate the average encryption and decryption times.
      final avgEncrypt = _calculateAverage(encryptDurations);
      final avgDecrypt = _calculateAverage(decryptDurations);

      print("Benchmark finished successfully for: $implType, $algoType.");
      return BenchmarkResult(
        implType: implType,
        algoType: algoType,
        dataSize: dataSize,
        iterations: iterations,
        avgEncryptTime: avgEncrypt,
        avgDecryptTime: avgDecrypt,
        success: true,
      );
    } catch (e, s) {
      // Catch any exceptions during the benchmark.
      print("Benchmark failed for: $implType, $algoType. Error: $e");
      print("Stack trace: $s");
      return BenchmarkResult.error(
        implType: implType,
        algoType: algoType,
        dataSize: dataSize,
        iterations: iterations,
        message: e.toString(),
      );
    }
  }

  /// Calculates the average duration from a list of durations.
  ///
  /// [durations] A list of `Duration` objects.
  /// Returns the average `Duration`. Returns `Duration.zero` if the list is empty.
  Duration _calculateAverage(List<Duration> durations) {
    if (durations.isEmpty) return Duration.zero;
    // Sum all durations in microseconds to maintain precision.
    final totalMicroseconds =
        durations.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
    // Calculate the average and return as a Duration object.
    return Duration(microseconds: totalMicroseconds ~/ durations.length);
  }

  /// Compares two `Uint8List` objects for equality.
  ///
  /// [a] The first `Uint8List`.
  /// [b] The second `Uint8List`.
  /// Returns `true` if the lists are identical (same length and same byte values at each position),
  /// `false` otherwise.
  bool _compareLists(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
