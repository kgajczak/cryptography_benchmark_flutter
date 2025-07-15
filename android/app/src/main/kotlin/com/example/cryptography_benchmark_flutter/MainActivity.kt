package com.example.cryptography_benchmark_flutter

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import javax.crypto.spec.IvParameterSpec
import org.spongycastle.jce.provider.BouncyCastleProvider // Using SpongyCastle, a repackage of BouncyCastle for Android
import java.security.Security
import android.util.Log
import java.io.File // Added for file reading

class MainActivity: FlutterActivity() {
    // Channel name for communication between Flutter and native Android code
    private val CHANNEL = "com.example.cryptography_benchmark_flutter/crypto"
    // Logcat tag for this class
    private val TAG = "MainActivityCrypto"

    companion object {
        // Logcat tag for the companion object
        private const val COMPANION_TAG = "MainActivityCompanion"
        init { // This block is executed when the MainActivity class is loaded
            // Check if the SpongyCastle (BouncyCastle) provider is already registered
            if (Security.getProvider(BouncyCastleProvider.PROVIDER_NAME) == null) {
                try {
                    // Add SpongyCastle as a security provider if it's not already present.
                    // This makes its cryptographic algorithms available.
                    Security.addProvider(BouncyCastleProvider())
                    Log.i(COMPANION_TAG, "SpongyCastle provider added successfully.")
                } catch (e: Exception) {
                    Log.e(COMPANION_TAG, "Failed to add SpongyCastle provider", e)
                }
            } else {
                // Log if a provider with the name "BC" (BouncyCastleProvider.PROVIDER_NAME) is already there.
                Log.i(COMPANION_TAG, "A provider with name '${BouncyCastleProvider.PROVIDER_NAME}' (expected SpongyCastle) is already registered.")
            }
        }
    }

    // A new private function to get the process's CPU time.
    // It reads the /proc/self/stat file, which is a standard way on Linux-based
    // systems (like Android) to get process statistics.
    private fun getProcessCpuTime(): Long {
        try {
            // Read the statistics file for the current process.
            val stats = File("/proc/self/stat").readText().split(" ")
            // Extract user time (utime, field #14, index 13) and system time (stime, field #15, index 14).
            val utime = stats[13].toLong()
            val stime = stats[14].toLong()
            // Return the sum. The value is in "jiffies" (system clock ticks),
            // which is precise enough for calculating deltas.
            return utime + stime
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read CPU time from /proc/self/stat", e)
            return -1L // Return -1 on error.
        }
    }


    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine) // Standard call to the superclass

        try {
            val scProvider = Security.getProvider(BouncyCastleProvider.PROVIDER_NAME)
            if (scProvider != null) {
                Log.i("AlgoList", "--- Algorithms provided by SC/BC (${scProvider.getInfo()}) for Cipher service ---")
                val services = scProvider.services
                // Sort services by algorithm name for easier reading in logs
                val sortedServices = services.toList().sortedBy { it.algorithm }
                for (service in sortedServices) {
                    // We are interested in Cipher services
                    if ("Cipher" == service.type) {
                        // Filter for specific algorithms of interest for this benchmark
                        if (service.algorithm.contains("AES", ignoreCase = true) ||
                            service.algorithm.contains("ChaCha", ignoreCase = true) ||
                            service.algorithm.contains("Poly1305", ignoreCase = true) ||
                            service.algorithm.contains("CHACHA7539", ignoreCase = true) ) {
                            Log.i("AlgoList", "  Algorithm: ${service.algorithm}")
                        }
                    }
                }
                Log.i("AlgoList", "--- End of relevant SC/BC Algorithms ---")
            } else {
                Log.e("AlgoList", "SpongyCastle/BC provider is NULL during configureFlutterEngine!")
            }
        } catch (e: Exception) {
            Log.e("AlgoList", "Error listing SC/BC algorithms", e)
        }

        // Set up the MethodChannel to handle calls from Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            // call: Contains the method name and arguments from Flutter
            // channelResult: Used to send a response (success or error) back to Flutter
                call, channelResult ->
            when (call.method) { // Dispatch based on the method name called from Flutter
                // Handle the new 'getCpuTime' method call from Flutter.
                "getCpuTime" -> {
                    val cpuTime = getProcessCpuTime()
                    if (cpuTime != -1L) {
                        channelResult.success(cpuTime)
                    } else {
                        channelResult.error("UNAVAILABLE", "Could not retrieve CPU time.", null)
                    }
                }
                "encryptAesGcm" -> {
                    try {
                        // Cast arguments to the expected type (Map of String to ByteArray)
                        val args = call.arguments as? Map<String, ByteArray>
                        if (args == null) { channelResult.error("INVALID_ARGS", "Argumenty nie są mapą.", null); return@setMethodCallHandler }

                        // Extract plaintext, key, and nonce from arguments
                        // If any are missing, send an error back to Flutter and return
                        val plainText = args["plainText"] ?: run { channelResult.error("ARGUMENT_ERROR", "Brak 'plainText'.", null); return@setMethodCallHandler }
                        val key = args["key"] ?: run { channelResult.error("ARGUMENT_ERROR", "Brak 'key'.", null); return@setMethodCallHandler }
                        val nonce = args["nonce"] ?: run { channelResult.error("ARGUMENT_ERROR", "Brak 'nonce'.", null); return@setMethodCallHandler }

                        // Validate key and nonce lengths
                        // AES-256 (used here) requires a 32-byte (256-bit) key
                        if (key.size != 32) { channelResult.error("INVALID_KEY", "Nieprawidłowa długość klucza AES.", null); return@setMethodCallHandler }
                        // AES-GCM standard nonce length is 12 bytes (96 bits)
                        if (nonce.size != 12) { channelResult.error("INVALID_NONCE", "Nieprawidłowa długość nonce AES-GCM.", null); return@setMethodCallHandler }

                        // Create SecretKeySpec for AES from the raw key bytes
                        val secretKeySpec: SecretKey = SecretKeySpec(key, "AES")
                        // Create GCMParameterSpec: 128-bit authentication tag length, and the nonce
                        val gcmParameterSpec = GCMParameterSpec(128, nonce) // 128 is the tag length in bits
                        // Get Cipher instance for AES/GCM/NoPadding.
                        // This will use the highest priority provider that supports this algorithm (e.g., AndroidOpenSSLProvider or SpongyCastle).
                        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                        // Initialize cipher for encryption mode with the key and GCM parameters
                        cipher.init(Cipher.ENCRYPT_MODE, secretKeySpec, gcmParameterSpec)
                        // Perform encryption
                        val cipherTextWithMac = cipher.doFinal(plainText) // Output includes ciphertext and MAC tag
                        // Send encrypted data back to Flutter
                        channelResult.success(cipherTextWithMac)

                    } catch (e: IllegalArgumentException) { // Catch issues with arguments provided to crypto functions
                        Log.e(TAG, "encryptAesGcm args: ${e.message}", e)
                        channelResult.error("ARGUMENT_ERROR", e.message, null)
                    } catch (e: Exception) { // Catch any other exceptions during encryption
                        Log.e(TAG, "encryptAesGcm native: ${e.message}", e)
                        channelResult.error("ENCRYPT_ERROR", "AES-GCM: ${e.message}", e.stackTraceToString())
                    }
                }
                "decryptAesGcm" -> {
                    try {
                        val args = call.arguments as? Map<String, ByteArray>
                        if (args == null) { channelResult.error("INVALID_ARGS", "Argumenty nie są mapą.", null); return@setMethodCallHandler }

                        val ciphertextTag = args["ciphertextTag"] ?: run { channelResult.error("ARGUMENT_ERROR", "Brak 'ciphertextTag'.", null); return@setMethodCallHandler }
                        val key = args["key"] ?: run { channelResult.error("ARGUMENT_ERROR", "Brak 'key'.", null); return@setMethodCallHandler }
                        val nonce = args["nonce"] ?: run { channelResult.error("ARGUMENT_ERROR", "Brak 'nonce'.", null); return@setMethodCallHandler }

                        if (key.size != 32) { channelResult.error("INVALID_KEY", "Nieprawidłowa długość klucza AES.", null); return@setMethodCallHandler }
                        if (nonce.size != 12) { channelResult.error("INVALID_NONCE", "Nieprawidłowa długość nonce AES-GCM.", null); return@setMethodCallHandler }
                        // Ciphertext with tag must be at least as long as the tag (16 bytes for a 128-bit tag)
                        if (ciphertextTag.size < 16) { channelResult.error("INVALID_DATA", "Dane ciphertextTag za krótkie.", null); return@setMethodCallHandler }

                        val secretKeySpec: SecretKey = SecretKeySpec(key, "AES")
                        val gcmParameterSpec = GCMParameterSpec(128, nonce) // 128-bit auth tag
                        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                        // Initialize cipher for decryption mode
                        cipher.init(Cipher.DECRYPT_MODE, secretKeySpec, gcmParameterSpec)
                        // Perform decryption
                        val decryptedText = cipher.doFinal(ciphertextTag)
                        // Send decrypted data back to Flutter
                        channelResult.success(decryptedText)

                    } catch (e: IllegalArgumentException) {
                        Log.e(TAG, "decryptAesGcm args: ${e.message}", e)
                        channelResult.error("ARGUMENT_ERROR", e.message, null)
                    } catch (e: javax.crypto.AEADBadTagException) { // Specific exception for MAC tag mismatch in AEAD ciphers like GCM
                        Log.w(TAG, "decryptAesGcm tag: Niezgodność tagu MAC.", e)
                        channelResult.error("DECRYPT_TAG_ERROR", "AES-GCM: Niezgodność tagu MAC.", null)
                    } catch (e: Exception) {
                        Log.e(TAG, "decryptAesGcm native: ${e.message}", e)
                        channelResult.error("DECRYPT_ERROR", "AES-GCM: ${e.message}", e.stackTraceToString())
                    }
                }
                "encryptChaChaPoly" -> {
                    try {
                        val args = call.arguments as? Map<String, ByteArray>
                        if (args == null) { channelResult.error("INVALID_ARGS", "Argumenty nie są mapą.", null); return@setMethodCallHandler }

                        val plainText = args["plainText"] ?: run { channelResult.error("ARGUMENT_ERROR", "Brak 'plainText'.", null); return@setMethodCallHandler }
                        val key = args["key"] ?: run { channelResult.error("ARGUMENT_ERROR", "Brak 'key'.", null); return@setMethodCallHandler }
                        val nonce = args["nonce"] ?: run { channelResult.error("ARGUMENT_ERROR", "Brak 'nonce'.", null); return@setMethodCallHandler }

                        // ChaCha20 (RFC 7539/8439) uses a 32-byte (256-bit) key
                        if (key.size != 32) { channelResult.error("INVALID_KEY", "Nieprawidłowa długość klucza ChaCha20.", null); return@setMethodCallHandler }
                        // ChaCha20-Poly1305 (RFC 7539/8439) uses a 12-byte (96-bit) nonce
                        if (nonce.size != 12) { channelResult.error("INVALID_NONCE", "Nieprawidłowa długość nonce ChaCha20.", null); return@setMethodCallHandler }

                        // Create SecretKeySpec for ChaCha20
                        val secretKeySpec: SecretKey = SecretKeySpec(key, "ChaCha20") // "ChaCha20" is the algorithm name for the key material
                        // Create IvParameterSpec for the nonce (ChaCha20-Poly1305 uses IvParameterSpec)
                        val ivParameterSpec = IvParameterSpec(nonce)
                        // Get Cipher instance for "CHACHA7539" (ChaCha20-Poly1305 AEAD algorithm as per RFC7539)
                        // Explicitly request it from the SpongyCastle/BouncyCastle provider.
                        val cipher = Cipher.getInstance("CHACHA7539", BouncyCastleProvider.PROVIDER_NAME)
                        //val cipher = Cipher.getInstance("CHACHA")
                        // Initialize cipher for encryption mode
                        cipher.init(Cipher.ENCRYPT_MODE, secretKeySpec, ivParameterSpec)
                        // Perform encryption
                        val cipherTextWithMac = cipher.doFinal(plainText) // Output includes ciphertext and Poly1305 MAC tag
                        // Send encrypted data back to Flutter
                        channelResult.success(cipherTextWithMac)

                    } catch (e: IllegalArgumentException) {
                        Log.e(TAG, "encryptChaCha args: ${e.message}", e)
                        channelResult.error("ARGUMENT_ERROR", e.message, null)
                    } catch (e: java.security.NoSuchProviderException) { // SpongyCastle provider might not be found/registered
                        Log.e(TAG, "encryptChaCha SC/BC provider: ${e.message}", e)
                        channelResult.error("NO_SUCH_PROVIDER", "SC/BC nie znaleziony.", null)
                    } catch (e: java.security.NoSuchAlgorithmException) { // "CHACHA7539" algorithm might not be available from the provider
                        Log.e(TAG, "encryptChaCha SC/BC algo: ${e.message}", e)
                        channelResult.error("NO_SUCH_ALGORITHM", "CHACHA7539 (SC/BC) niedostępny.", null)
                    } catch (e: Exception) {
                        Log.e(TAG, "encryptChaCha SC/BC native: ${e.message}", e)
                        channelResult.error("ENCRYPT_ERROR", "ChaCha (SC/BC): ${e.message}", e.stackTraceToString())
                    }
                }
                "decryptChaChaPoly" -> {
                    try {
                        val args = call.arguments as? Map<String, ByteArray>
                        if (args == null) { channelResult.error("INVALID_ARGS", "Argumenty nie są mapą.", null); return@setMethodCallHandler }

                        val ciphertextTag = args["ciphertextTag"] ?: run { channelResult.error("ARGUMENT_ERROR", "Brak 'ciphertextTag'.", null); return@setMethodCallHandler }
                        val key = args["key"] ?: run { channelResult.error("ARGUMENT_ERROR", "Brak 'key'.", null); return@setMethodCallHandler }
                        val nonce = args["nonce"] ?: run { channelResult.error("ARGUMENT_ERROR", "Brak 'nonce'.", null); return@setMethodCallHandler }

                        if (key.size != 32) { channelResult.error("INVALID_KEY", "Nieprawidłowa długość klucza ChaCha20.", null); return@setMethodCallHandler }
                        if (nonce.size != 12) { channelResult.error("INVALID_NONCE", "Nieprawidłowa długość nonce ChaCha20.", null); return@setMethodCallHandler }
                        // Ciphertext with tag must be at least as long as the Poly1305 tag (16 bytes)
                        if (ciphertextTag.size < 16) { channelResult.error("INVALID_DATA", "Dane ciphertextTag za krótkie.", null); return@setMethodCallHandler }

                        val secretKeySpec: SecretKey = SecretKeySpec(key, "ChaCha20")
                        val ivParameterSpec = IvParameterSpec(nonce)
                        val cipher = Cipher.getInstance("CHACHA7539", BouncyCastleProvider.PROVIDER_NAME)
                        // Initialize cipher for decryption mode
                        cipher.init(Cipher.DECRYPT_MODE, secretKeySpec, ivParameterSpec)
                        // Perform decryption
                        val decryptedText = cipher.doFinal(ciphertextTag)
                        // Send decrypted data back to Flutter
                        channelResult.success(decryptedText)

                    } catch (e: IllegalArgumentException) {
                        Log.e(TAG, "decryptChaCha args: ${e.message}", e)
                        channelResult.error("ARGUMENT_ERROR", e.message, null)
                    } catch (e: java.security.NoSuchProviderException) {
                        Log.e(TAG, "decryptChaCha SC/BC provider: ${e.message}", e)
                        channelResult.error("NO_SUCH_PROVIDER", "SC/BC nie znaleziony.", null)
                    } catch (e: java.security.NoSuchAlgorithmException) {
                        Log.e(TAG, "decryptChaCha SC/BC algo: ${e.message}", e)
                        channelResult.error("NO_SUCH_ALGORITHM", "CHACHA7539 (SC/BC) niedostępny.", null)
                    } catch (e: javax.crypto.AEADBadTagException) { // Specific exception for MAC tag mismatch
                        Log.w(TAG, "decryptChaCha SC/BC tag: Niezgodność tagu MAC.", e)
                        channelResult.error("DECRYPT_TAG_ERROR", "ChaCha (SC/BC): Niezgodność tagu MAC.", null)
                    } catch (e: Exception) {
                        Log.e(TAG, "decryptChaCha SC/BC native: ${e.message}", e)
                        channelResult.error("DECRYPT_ERROR", "ChaCha (SC/BC): ${e.message}", e.stackTraceToString())
                    }
                }
                else -> { // Handle unknown method calls
                    channelResult.notImplemented()
                }
            }
        }
    }
}