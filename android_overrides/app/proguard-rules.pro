# Keep class names intact: several plugins look classes up by name
# (JNI, reflection, Room-style "_Impl" lookups). Size cost is small.
-dontobfuscate
-keep class com.sudosoc.sudoquran.** { *; }
-keep class com.ryanheise.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-dontwarn com.google.android.play.core.**
