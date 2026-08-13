import java.io.InputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Play Games project ID, from Play Console > Play Games Services >
// Configuration. A long number and nothing else - not the package name, not an
// OAuth client ID.
//
// Set it in android/local.properties as:
//     playGamesAppId=1234567890123
//
// Read from there rather than written into the manifest because it is
// per-project configuration, not source. Empty until it is set, which leaves
// the Games SDK uninitialised on purpose: signing in then fails cleanly and
// the menu says so. That is much the better failure - a placeholder or
// malformed ID makes the Play Games SDK abort, and that takes the game down
// rather than just the sign-in button.
//
// Declared out here rather than inside defaultConfig: `apply` inside the
// Android DSL resolves to Gradle's own and will not compile.
val playGamesProperties = Properties()
val playGamesPropertiesFile = rootProject.file("local.properties")
if (playGamesPropertiesFile.exists()) {
    playGamesPropertiesFile.inputStream().use { stream: InputStream ->
        playGamesProperties.load(stream)
    }
}
val playGamesAppId: String =
    playGamesProperties.getProperty("playGamesAppId") ?: ""

android {
    namespace = "com.flexirun.game"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.flexirun.game"

        manifestPlaceholders["playGamesAppId"] = playGamesAppId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
