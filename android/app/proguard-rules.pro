# Keep Flutter generated classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.** { *; }
-keep class com.google.** { *; }
-keep class androidx.** { *; }

# Keep Supabase / networking classes if needed
-keepattributes *Annotation*
-keep class com.supabase.** { *; }

# Keep generated app code if necessary
-keep class e_comerce_appliction.** { *; }

# Razorpay SDK rules
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-dontwarn com.google.android.gms.tasks.**
-keepattributes JavascriptInterface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

