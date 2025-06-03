# Keep SpongyCastle classes (adjust if using regular BouncyCastle)
-keep class org.spongycastle.** { *; }
-keep interface org.spongycastle.** { *; }
-dontwarn org.spongycastle.**

# Keep your MainActivity and any other classes called via JNI or reflection
-keep class com.example.cryptography_benchmark_flutter.MainActivity { *; }
