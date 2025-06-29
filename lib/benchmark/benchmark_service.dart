// ignore_for_file: avoid_print

import 'dart:developer';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart' show SecretKey;
import 'package:flutter/foundation.dart';

import '../crypto/common.dart';
import '../crypto/dart_impl.dart';
import '../crypto/ffi_impl.dart';
import '../crypto/pc_impl.dart';

// --- Top-level functions for `compute` ---
// The `compute` function requires the function to be a top-level function or a static method.
// These wrappers allow us to run the crypto operations in a background isolate,
// preventing the UI from freezing during intensive computations.

/// A wrapper for the pure Dart cryptographic implementation.
/// This function is designed to be executed in a separate isolate via `compute()`.
///
/// It takes a map of arguments, instantiates the [DartCryptoService], and performs
/// either encryption or decryption based on the provided parameters.
Future<Uint8List?> _runDartCrypto(Map<String, dynamic> args) async {
  // Instantiate the service within the isolate.
  final service = DartCryptoService();
  // Unpack arguments from the map.
  final bool isEncrypt = args['isEncrypt'];
  final AlgorithmType algoType = args['algoType'];
  final Uint8List data = args['data'];
  final SecretKey key =
      args['key']; // `SecretKey` is from the `cryptography` package.

  // Conditionally call the appropriate encryption or decryption method.
  if (isEncrypt) {
    return (algoType == AlgorithmType.aesGcm)
        ? await service.encryptAesGcm(data, key)
        : await service.encryptChaCha(data, key);
  } else {
    return (algoType == AlgorithmType.aesGcm)
        ? await service.decryptAesGcm(data, key)
        : await service.decryptChaCha(data, key);
  }
}

/// A wrapper for the FFI (Foreign Function Interface) cryptographic implementation.
/// This function is designed to be executed in a separate isolate via `compute()`.
///
/// It takes a map of arguments, instantiates the [FfiCryptoService], and performs
/// either encryption or decryption by calling native code.
Uint8List? _runFfiCrypto(Map<String, dynamic> args) {
  // Instantiate the service within the isolate.
  final service = FfiCryptoService();
  // Unpack arguments from the map.
  final bool isEncrypt = args['isEncrypt'];
  final AlgorithmType algoType = args['algoType'];
  final Uint8List data = args['data'];
  final Uint8List key = args['key']; // Raw bytes for the key.
  final Uint8List nonce = args['nonce']; // Raw bytes for the nonce.

  // Conditionally call the appropriate encryption or decryption method.
  if (isEncrypt) {
    return (algoType == AlgorithmType.aesGcm)
        ? service.encryptAesGcm(data, key, nonce)
        : service.encryptChaCha(data, key, nonce);
  } else {
    return (algoType == AlgorithmType.aesGcm)
        ? service.decryptAesGcm(data, key, nonce)
        : service.decryptChaCha(data, key, nonce);
  }
}
// NOTE: A wrapper for Platform Channel (_runPcCrypto) was removed as it's not
// suitable for use with `compute`. Platform Channel calls are inherently asynchronous
// and must be initiated from the main isolate to communicate with the platform thread.

/// A service class responsible for setting up and running cryptographic benchmarks.
class BenchmarkService {
  // Instantiate the services for each implementation type.
  final PlatformChannelCryptoService _pcService =
      PlatformChannelCryptoService();

  // Keys used for the benchmarks. We generate them once to ensure consistency.
  late SecretKey _aesKeyDartImpl; // AES key for the pure Dart implementation.
  late SecretKey
      _chaKeyDartImpl; // ChaCha20 key for the pure Dart implementation.
  late Uint8List
      _aesKeyRawBytes; // Raw byte representation of the AES key for FFI/PlatformChannel.
  late Uint8List
      _chaKeyRawBytes; // Raw byte representation of the ChaCha20 key for FFI/PlatformChannel.

  /// Constructor for the [BenchmarkService].
  /// It immediately generates the cryptographic keys that will be used for all benchmark runs.
  BenchmarkService() {
    _generateKeysForBenchmark();
    print("BenchmarkService: Keys for benchmark have been generated.");
  }

  /// Generates and stores 256-bit (32-byte) keys for AES and ChaCha20.
  /// Uses a cryptographically secure random number generator.
  void _generateKeysForBenchmark() {
    final random = Random.secure();
    // Generate 32 random bytes for each key.
    _aesKeyRawBytes =
        Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
    _chaKeyRawBytes =
        Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));

    // Create `SecretKey` objects for the Dart `cryptography` package.
    _aesKeyDartImpl = SecretKey(_aesKeyRawBytes);
    _chaKeyDartImpl = SecretKey(_chaKeyRawBytes);
  }

  /// Generates a [Uint8List] of a specified size with random data.
  ///
  /// [sizeInBytes] The desired size of the data block.
  Uint8List _generateRandomData(int sizeInBytes) {
    final random = Random.secure();
    return Uint8List.fromList(
        List.generate(sizeInBytes, (_) => random.nextInt(256)));
  }

  /// Generates a 96-bit (12-byte) nonce (Initialization Vector).
  /// This size is standard for AES-GCM and ChaCha20-Poly1305.
  Uint8List _generateNonce() {
    final random = Random.secure();
    const int nonceSize = 12; // 12 bytes = 96 bits.
    return Uint8List.fromList(
        List.generate(nonceSize, (_) => random.nextInt(256)));
  }

  /// Runs a full benchmark cycle for a given configuration.
  ///
  /// This is the main method of the service. It performs the following steps:
  /// 1. Validates input parameters.
  /// 2. Generates random plaintext data.
  /// 3. Loops for the specified number of `iterations`.
  /// 4. In each iteration:
  ///    a. Generates a unique nonce.
  ///    b. Measures the time for encryption.
  ///    c. Measures the time for decryption.
  ///    d. Verifies that the decrypted data matches the original plaintext.
  /// 5. Calculates average and total times for encryption and decryption.
  /// 6. Returns a [BenchmarkResult] object with the performance data.
  Future<BenchmarkResult> runBenchmark({
    required ImplementationType implType,
    required AlgorithmType algoType,
    required int dataSize,
    required int iterations,
    Uint8List? testData, // Optional pre-generated data for testing.
  }) async {
    // Basic input validation.
    if (dataSize <= 0 || iterations <= 0) {
      return BenchmarkResult.error(
        implType: implType,
        algoType: algoType,
        dataSize: dataSize,
        iterations: iterations,
        message: "Data size and iterations must be positive.",
      );
    }

    // Measure memory before the test.
    await Future.delayed(const Duration(milliseconds: 50));
    final initialRss = ProcessInfo.currentRss;
    int peakRss = initialRss;
    int sumRss = 0;

    // Generate the data to be encrypted, or use the provided test data.
    final plainText = testData ?? _generateRandomData(dataSize);
    final List<Duration> encryptDurations = [];
    final List<Duration> decryptDurations = [];

    print(
        "Starting benchmark: $implType, $algoType, size: $dataSize B, iterations: $iterations. Initial RSS: ${(initialRss / (1024 * 1024)).toStringAsFixed(2)} MB");
    final debugLabel =
        "$implType, $algoType, size: $dataSize B, iterations: $iterations";

    try {
      // The main benchmark loop.
      for (int i = 0; i < iterations; i++) {
        // A new nonce must be used for every encryption with the same key.
        final nonce = _generateNonce();

        // --- Encryption Phase ---
        final stopwatchEncrypt = Stopwatch()..start();
        Uint8List? encryptedData;

        switch (implType) {
          case ImplementationType.dart:
            // Use `compute` to run the Dart crypto logic in a separate isolate.
            final task = TimelineTask();
            task.start(debugLabel);
            try {
              encryptedData = await compute(_runDartCrypto, {
                'isEncrypt': true,
                'algoType': algoType,
                'data': plainText,
                'key': algoType == AlgorithmType.aesGcm
                    ? _aesKeyDartImpl
                    : _chaKeyDartImpl,
              });
            } finally {
              task.finish();
            }
            break;
          case ImplementationType.platformChannel:
            // Platform Channel calls are made directly. They are already async and
            // handled by the Flutter engine to run on the appropriate native thread.
            final task = TimelineTask();
            task.start(debugLabel);
            try {
              encryptedData = (algoType == AlgorithmType.aesGcm)
                  ? await _pcService.encryptAesGcm(
                      plainText, _aesKeyRawBytes, nonce)
                  : await _pcService.encryptChaCha(
                      plainText, _chaKeyRawBytes, nonce);
            } finally {
              task.finish();
            }
            break;
          case ImplementationType.ffi:
            // Use `compute` to run the FFI crypto logic in a separate isolate.
            final task = TimelineTask();
            task.start(debugLabel);
            try {
              encryptedData = await compute(_runFfiCrypto, {
                'isEncrypt': true,
                'algoType': algoType,
                'data': plainText,
                'key': algoType == AlgorithmType.aesGcm
                    ? _aesKeyRawBytes
                    : _chaKeyRawBytes,
                'nonce': nonce,
              });
            } finally {
              task.finish();
            }
            break;
        }
        stopwatchEncrypt.stop();
        encryptDurations.add(stopwatchEncrypt.elapsed);

        // A null result indicates a failure in the encryption process.
        if (encryptedData == null) {
          throw Exception(
              "Encryption failed (returned null) during iteration ${i + 1}");
        }

        // --- Decryption Phase ---
        final stopwatchDecrypt = Stopwatch()..start();
        Uint8List? decryptedData;

        switch (implType) {
          case ImplementationType.dart:
            // Use `compute` for decryption in a separate isolate.
            final task = TimelineTask();
            task.start(debugLabel);
            try {
              decryptedData = await compute(_runDartCrypto, {
                'isEncrypt': false,
                'algoType': algoType,
                'data': encryptedData,
                'key': algoType == AlgorithmType.aesGcm
                    ? _aesKeyDartImpl
                    : _chaKeyDartImpl,
              });
            } finally {
              task.finish();
            }
            break;
          case ImplementationType.platformChannel:
            // Direct call for Platform Channel decryption.
            final task = TimelineTask();
            task.start(debugLabel);
            try {
              decryptedData = (algoType == AlgorithmType.aesGcm)
                  ? await _pcService.decryptAesGcm(
                      encryptedData, _aesKeyRawBytes, nonce)
                  : await _pcService.decryptChaCha(
                      encryptedData, _chaKeyRawBytes, nonce);
            } finally {
              task.finish();
            }
            break;
          case ImplementationType.ffi:
            // Use `compute` for FFI decryption in a separate isolate.
            decryptedData = await compute(_runFfiCrypto, {
              'isEncrypt': false,
              'algoType': algoType,
              'data': encryptedData,
              'key': algoType == AlgorithmType.aesGcm
                  ? _aesKeyRawBytes
                  : _chaKeyRawBytes,
              'nonce': nonce,
            });
            break;
        }
        stopwatchDecrypt.stop();
        decryptDurations.add(stopwatchDecrypt.elapsed);

        // A null result indicates a failure in the decryption process.
        if (decryptedData == null) {
          throw Exception(
              "Decryption failed (returned null) during iteration ${i + 1}");
        }
        // Verification step: ensure the decrypted data is identical to the original plaintext.
        if (!_compareLists(plainText, decryptedData)) {
          throw Exception(
              "Verification failed: Decrypted data does not match original plaintext during iteration ${i + 1}");
        }

        // Monitor peak memory usage inside the loop.
        final currentRss = ProcessInfo.currentRss;
        sumRss += currentRss;
        if (currentRss > peakRss) {
          peakRss = currentRss;
        }

        // For very long benchmarks, yield to the event loop every 100 iterations.
        // This gives the UI a chance to update and prevents the app from appearing frozen.
        if (i > 0 && i % 100 == 0) {
          await Future.delayed(Duration.zero);
        }
      }

      // Measure memory after the test.
      await Future.delayed(const Duration(milliseconds: 50));
      final finalRss = ProcessInfo.currentRss;

      // Calculate final statistics after all iterations are complete.
      final avgEncrypt = _calculateAverage(encryptDurations);
      final avgDecrypt = _calculateAverage(decryptDurations);
      final sumEncrypt = _calculateSum(encryptDurations);
      final sumDecrypt = _calculateSum(decryptDurations);

      print("Benchmark finished successfully for: $implType, $algoType.");

      // Return a successful result object.
      return BenchmarkResult(
        implType: implType,
        algoType: algoType,
        dataSize: dataSize,
        iterations: iterations,
        avgEncryptTime: avgEncrypt,
        avgDecryptTime: avgDecrypt,
        sumEncryptTime: sumEncrypt,
        sumDecryptTime: sumDecrypt,
        initialMemory: initialRss,
        peakMemory: peakRss,
        finalMemory: finalRss,
        averageMemory: sumRss ~/ iterations,
      );
    } catch (e, s) {
      // Catch any exception during the benchmark process, log it, and return an error result.
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

  /// Calculates the average duration from a list of [Duration] objects.
  Duration _calculateAverage(List<Duration> durations) {
    if (durations.isEmpty) return Duration.zero;
    // Sum up the total microseconds to avoid precision loss.
    final totalMicroseconds =
        durations.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
    // Integer division to get the average in microseconds.
    return Duration(microseconds: totalMicroseconds ~/ durations.length);
  }

  /// Calculates the sum of all durations in a list.
  Duration _calculateSum(List<Duration> durations) {
    if (durations.isEmpty) return Duration.zero;
    final totalMicroseconds =
        durations.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
    return Duration(microseconds: totalMicroseconds);
  }

  /// A constant-time comparison of two byte lists to prevent timing attacks.
  /// Although for this benchmark context it's not strictly necessary, it's a good practice.
  ///
  /// Note: The implementation here is a simple element-wise check, not truly constant-time.
  /// A true constant-time comparison would perform checks on all bytes regardless of where
  /// a mismatch is found to ensure the execution time is always the same.
  bool _compareLists(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
