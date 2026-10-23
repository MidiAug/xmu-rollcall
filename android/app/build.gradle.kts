plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// CI previews have their own app ID; production releases require a stable key.
val previewBuild = System.getenv("XMU_ANDROID_PREVIEW") == "true"
val requireSigning = System.getenv("XMU_ANDROID_REQUIRE_SIGNING") == "true"
val signingEnv = listOf(
    "XMU_ANDROID_KEYSTORE_PATH",
    "XMU_ANDROID_KEYSTORE_PASSWORD",
    "XMU_ANDROID_KEY_ALIAS",
    "XMU_ANDROID_KEY_PASSWORD",
).associateWith { System.getenv(it).orEmpty() }
val hasReleaseKey = signingEnv.values.all { it.isNotBlank() }
require(!requireSigning || !previewBuild) { "A preview cannot be a signed production release" }
require(previewBuild || signingEnv.values.none { it.isNotBlank() } || hasReleaseKey) {
    "Android signing configuration is incomplete"
}
require(!requireSigning || hasReleaseKey) { "A release signing key is required" }

android {
    namespace = "cn.edu.xmu.rollcall.xmu_rollcall"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "cn.edu.xmu.rollcall.xmu_rollcall"
        if (previewBuild) {
            applicationIdSuffix = ".preview"
            versionNameSuffix = "-preview"
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey && !previewBuild) {
            create("production") {
                storeFile = file(signingEnv.getValue("XMU_ANDROID_KEYSTORE_PATH"))
                storePassword = signingEnv.getValue("XMU_ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingEnv.getValue("XMU_ANDROID_KEY_ALIAS")
                keyPassword = signingEnv.getValue("XMU_ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Local development keeps its existing key; CI release forbids fallback.
            signingConfig = signingConfigs.getByName(
                if (hasReleaseKey && !previewBuild) "production" else "debug",
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
