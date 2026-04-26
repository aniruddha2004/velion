# ProGuard rules for release builds
# Keep class names for reflection
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class com.example.personal_news_assistant.** { *; }

# Keep Hive
-keep class com.example.personal_news_assistant.models.** { *; }

# General Android
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
