// lib/crypto/common.dart
import 'package:flutter/foundation.dart'
    show immutable; // For @immutable annotation

/// Defines the type of cryptographic implementation used in the benchmark.
/// This enum helps in selecting the appropriate service for encryption/decryption.
enum ImplementationType {
  /// Represents the pure Dart implementation using the `cryptography` package.
  dart,

  /// Represents the implementation that uses Platform Channels to communicate
  /// with native Android (Kotlin/Java) or iOS (Swift/Objective-C) code.
  platformChannel,

  /// Represents the implementation that uses Foreign Function Interface (FFI)
  /// to call native C/C++ code directly.
  ffi
}

/// Defines the type of cryptographic algorithm used in the benchmark.
/// This enum allows for easy selection of the algorithm to be tested.
enum AlgorithmType {
  /// Represents the AES-GCM (Advanced Encryption Standard - Galois/Counter Mode) algorithm.
  /// Typically used with a 256-bit key in this benchmark.
  aesGcm,

  /// Represents the ChaCha20-Poly1305 algorithm.
  /// An AEAD (Authenticated Encryption with Associated Data) stream cipher and MAC.
  chaChaPoly
}

/// A data class to store the result of a single benchmark test run.
///
/// It is marked as `@immutable` to indicate that its state should not change
/// after creation, which is a good practice for data-holding classes.
@immutable
class BenchmarkResult {
  /// The type of implementation used for this benchmark run.
  final ImplementationType implType;

  /// The cryptographic algorithm used for this benchmark run.
  final AlgorithmType algoType;

  /// The size of the data (in bytes) that was encrypted/decrypted.
  final int dataSize;

  /// The number of encryption/decryption iterations performed in this run.
  final int iterations;

  /// The average time taken for a single encryption operation.
  final Duration avgEncryptTime;

  /// The average time taken for a single decryption operation.
  final Duration avgDecryptTime;

  /// The sum of all encryption times.
  final Duration sumEncryptTime;

  /// The sum of all decryption times.
  final Duration sumDecryptTime;

  /// The memory usage (RSS) in bytes before the benchmark started.
  final int initialMemory;

  /// The peak memory usage (RSS) in bytes recorded during the benchmark.
  final int peakMemory;

  /// The final memory usage (RSS) in bytes after the benchmark finished.
  final int finalMemory;

  /// The average memory usage (RSS) in bytes per iteration.
  final int averageMemory;

  /// A calculated property for the change in memory usage.
  int get memoryDelta => peakMemory - initialMemory;

  /// Indicates whether all operations (encryption, decryption, verification)
  /// in this benchmark run completed successfully.
  final bool success;

  /// An optional error message if the benchmark run failed (`success` is false).
  final String? errorMessage;

  /// Creates a [BenchmarkResult] instance.
  ///
  /// By default, `success` is true.
  const BenchmarkResult({
    required this.implType,
    required this.algoType,
    required this.dataSize,
    required this.iterations,
    required this.avgEncryptTime,
    required this.avgDecryptTime,
    required this.sumEncryptTime,
    required this.sumDecryptTime,
    required this.initialMemory,
    required this.peakMemory,
    required this.finalMemory,
    required this.averageMemory,
    this.success = true,
    this.errorMessage,
  });

  /// A factory constructor to easily create a [BenchmarkResult] representing an error.
  ///
  /// Encryption and decryption times are set to [Duration.zero], and `success` is false.
  factory BenchmarkResult.error({
    required ImplementationType implType,
    required AlgorithmType algoType,
    required int dataSize,
    required int iterations,
    required String message,
  }) {
    return BenchmarkResult(
      implType: implType,
      algoType: algoType,
      dataSize: dataSize,
      iterations: iterations,
      avgEncryptTime: Duration.zero, // Times are zero in case of an error
      avgDecryptTime: Duration.zero,
      sumEncryptTime: Duration.zero,
      sumDecryptTime: Duration.zero,
      initialMemory: 0,
      peakMemory: 0,
      finalMemory: 0,
      averageMemory: 0,
      success: false, // Mark as failure
      errorMessage: message,
    );
  }

  /// Provides a string representation of the benchmark result.
  ///
  /// Includes a clear indication of success or failure, along with
  /// the parameters of the test and the measured average times.
  @override
  String toString() {
    if (!success) {
      // If the benchmark failed, include the error message.
      return 'ERROR Result($implType, $algoType, data: ${dataSize}B, iter: $iterations): ${errorMessage ?? "Unknown error"}';
    }
    // Formatting time to milliseconds with three decimal places for better readability.
    final encMs = (avgEncryptTime.inMicroseconds / 1000).toStringAsFixed(3);
    final decMs = (avgDecryptTime.inMicroseconds / 1000).toStringAsFixed(3);
    final sumMs = (sumEncryptTime.inMicroseconds / 1000 +
            sumDecryptTime.inMicroseconds / 1000)
        .toStringAsFixed(3);

    return '${implType.name},'
        '\n${algoType.name},'
        '\ndata: ${dataSize}B,'
        '\niter: $iterations'
        '\nEncrypt: ${encMs}ms,'
        '\nDecrypt: ${decMs}ms,'
        '\nSum: ${sumMs}ms'
        '\nInit mem: ${(initialMemory / 1048576).toStringAsFixed(3)}MB'
        '\nPeak mem: ${(peakMemory / 1048576).toStringAsFixed(3)}MB'
        '\nFinal mem: ${(finalMemory / 1048576).toStringAsFixed(3)}MB'
        '\nMax used mem: ${(memoryDelta / 1048576).toStringAsFixed(3)}MB,'
        '\nAverage mem: ${(averageMemory / 1048576).toStringAsFixed(3)}MB';
  }

  /// Formats the result as a CSV row for easy table import.
  /// Note: CPU metrics must be added manually from profiler data.
  String toCsvRow() {
    // Wall Times in ms
    final wallEncryptMs =
        (avgEncryptTime.inMicroseconds / 1000).toStringAsFixed(3);
    final wallDecryptMs =
        (avgDecryptTime.inMicroseconds / 1000).toStringAsFixed(3);
    final wallSumMs =
        ((avgEncryptTime.inMicroseconds + avgDecryptTime.inMicroseconds) / 1000)
            .toStringAsFixed(3);

    // RAM usages in MB
    final ramAvgMb = (averageMemory / (1024 * 1024)).toStringAsFixed(3);
    final ramPeakMb = (peakMemory / (1024 * 1024)).toStringAsFixed(3);

    // Returns a semicolon-separated string.
    // Leaves placeholders for CPU data to be filled in from profiler.
    return "$implType;$algoType;$dataSize;$iterations;$wallEncryptMs;$wallDecryptMs;$wallSumMs;[CPU_TIME_HERE];[CPU_PEAK_HERE];$ramAvgMb;$ramPeakMb\n";
  }
}
