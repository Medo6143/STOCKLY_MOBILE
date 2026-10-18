# R8 rules for the release build (docs/release/android.md).
# The Flutter Gradle plugin adds Flutter's own rules; the ones below cover
# the plugins that reach Java/Kotlin code by name (JNI, reflection,
# WorkManager's worker factory) or reference optional classes.

# Flutter embedding and plugin registrant.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
# Deferred components are not used; the embedding references Play Core.
-dontwarn com.google.android.play.core.**

# drift / sqlite3: the native library is loaded through dart:ffi; keep the
# plugin class that registers it on older plugin versions.
-keep class eu.simonbinder.sqlite3_flutter_libs.** { *; }
-dontwarn eu.simonbinder.sqlite3_flutter_libs.**

# flutter_secure_storage: ciphers are chosen by name; Tink reads its
# protobuf-lite messages by reflection.
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.google.crypto.tink.** { *; }
-keepclassmembers class * extends com.google.crypto.tink.shaded.protobuf.GeneratedMessageLite {
    <fields>;
}
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn com.google.api.client.**
-dontwarn org.joda.time.**

# workmanager: WorkManager instantiates workers by class name.
-keep class dev.fluttercommunity.workmanager.** { *; }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# mobile_scanner: ML Kit barcode scanning (the plugin ships the same rules
# as consumer rules; repeated here so the release build does not depend on
# that).
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.libraries.barhopper.** { *; }
-keep class com.google.photos.** { *; }

# jni (used by path_provider_android): Dart calls Java through JNI by name.
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }
