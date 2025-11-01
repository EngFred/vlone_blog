# ----------------------------
# Flutter embedding & plugins
# ----------------------------
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }

# Keep GeneratedPluginRegistrant (older projects)
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Keep classes used by MethodChannels / reflection in plugins
-keepclassmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}
-keepclassmembers class * {
    public static *** from*(...);
}

# Keep annotations so libraries that check @Keep still work
-keepattributes *Annotation*

# ----------------------------
# Gson / Serialization
# ----------------------------
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.** { *; }

# ----------------------------
# OkHttp / Okio
# ----------------------------
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# ----------------------------
# WorkManager
# ----------------------------
-keep class androidx.work.impl.foreground.SystemForegroundDispatcher { *; }
-keep class androidx.work.** { *; }

# ----------------------------
# FFmpeg / native code
# ----------------------------
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.arthenica.ffmpeg.** { *; }

# ----------------------------
# AndroidX / Services / Manifest
# ----------------------------
-keepclassmembers class * extends android.app.Service {
    <init>(...);
}

# ----------------------------
# Flutter plugin registrars (reflection)
# ----------------------------
-keepclassmembers class * {
    public void onMethodCall(...);
    public void onAttachedToEngine(...);
    public void onDetachedFromEngine(...);
}

# ----------------------------
# Parcelable creators
# ----------------------------
-keepclassmembers class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator CREATOR;
}

# ----------------------------
# Flutter engine entry points
# ----------------------------
-keep class io.flutter.embedding.engine.FlutterEngine { *; }
-keep class io.flutter.embedding.engine.dart.DartExecutor { *; }

# ----------------------------
# Keep all plugins (safe broad rule)
# ----------------------------
-keep class com.* { *; }
-keep class org.* { *; }

# ----------------------------
# Kotlin metadata (reflection)
# ----------------------------
-keep class kotlin.Metadata { *; }

# ----------------------------
# Play Core / Deferred Components (Flutter embedding references)
# Prevent R8 missing class errors
# ----------------------------
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
