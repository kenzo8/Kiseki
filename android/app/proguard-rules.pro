# Kiseki - ProGuard / R8 rules (used with minifyEnabled for app size)
# Keep Firebase, Google Sign In, Flutter plugins, and other reflection-based classes

-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses

# Flutter engine and plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google Play Services / Google Sign In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Gson / serialization (Firestore, etc.)
-keepattributes Signature
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Data models: add if Firestore deserializes into custom models, e.g.:
# -keep class com.kenzo.kien.models.** { *; }
