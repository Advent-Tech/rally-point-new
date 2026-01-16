# Flutter ProGuard Rules

# Keep Flutter classes
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# Stripe SDK - Keep push provisioning classes (optional feature, may not be included)
-dontwarn com.stripe.android.pushProvisioning.**
-keep class com.stripe.android.pushProvisioning.** { *; }

# Stripe SDK general rules
-keep class com.stripe.android.** { *; }
-dontwarn com.stripe.android.**

# Keep Google Pay classes
-keep class com.google.android.gms.wallet.** { *; }
-dontwarn com.google.android.gms.wallet.**

# Keep Gson classes for serialization
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep model classes for JSON parsing
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# OkHttp & Okio - Required for HTTP tile fetching in flutter_map
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

-keep class okio.** { *; }

# Keep HTTP/Network classes
-keep class java.net.** { *; }
-keep class javax.net.ssl.** { *; }
-dontwarn java.nio.file.**
-dontwarn org.codehaus.mojo.animal_sniffer.**

# Keep flutter_map related classes
-dontwarn flutter_map.**

# Prevent stripping of network-related annotations
-keepattributes InnerClasses
-keepattributes EnclosingMethod
