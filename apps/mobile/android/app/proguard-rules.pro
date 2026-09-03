# ProGuard & R8 Configuration for Flujo Android Application

# Flutter Wrapper & Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flujo Native Database & Workers
-keep class com.flujo.app.database.** { *; }
-keep class com.flujo.app.worker.** { *; }
-keep class com.flujo.app.optimizer.** { *; }
-keep class com.flujo.app.FlujoNotificationListener { *; }

# WorkManager
-keep class androidx.work.** { *; }
-keepclassmembers class * extends androidx.work.Worker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keepclassmembers class * extends androidx.work.CoroutineWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# Strip debug and verbose logs in release builds for privacy and performance
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
}

# Keep line numbers for meaningful stack traces in production crashes
-keepattributes SourceFile,LineNumberTable
