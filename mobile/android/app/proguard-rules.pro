# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# TensorFlow Lite
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**
-dontwarn org.tensorflow.lite.gpu.**

# OpenCV (se necessario in futuro)
-keep class org.opencv.** { *; }
-dontwarn org.opencv.**

# Ignora le classi mancanti di Play Core Tasks (causate dalla migrazione di Google)
-dontwarn com.google.android.play.core.tasks.**