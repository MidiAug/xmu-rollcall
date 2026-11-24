# Flutter embedding and generated plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_inappwebview
-keep class com.pichillilorenzo.flutter_inappwebview_android.** { *; }
-dontwarn com.pichillilorenzo.flutter_inappwebview_android.**

# mobile_scanner / ML Kit
-keep class com.google.mlkit.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn com.google.mlkit.**

# flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# flutter_secure_storage / Tink / Gson
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.google.crypto.tink.** { *; }
-keepattributes Signature,*Annotation*

# flutter_foreground_task
-keep class com.pravera.flutter_foreground_task.** { *; }

# geolocator
-keep class com.baseflow.geolocator.** { *; }

# Common optional annotation / logging / WebKit compile-time warnings
-dontwarn org.slf4j.**
-dontwarn javax.annotation.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn android.webkit.**
