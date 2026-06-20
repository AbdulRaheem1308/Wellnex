# App Main Activity
-keep class com.joinwellnex.app.MainActivity { *; }

# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }

# Prevent R8 from stripping native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Suppress warnings/errors for missing Play Core classes (used by Flutter's deferred components)
-dontwarn com.google.android.play.core.**

