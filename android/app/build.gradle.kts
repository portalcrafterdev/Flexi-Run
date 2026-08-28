plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The Play Games project ID used to be read out of local.properties and
// substituted into the manifest. It now lives in res/values/games-ids.xml,
// which is the file Play Console exports and which also carries the twelve
// achievement IDs - one source instead of two that could disagree, and a
// string resource rather than a manifest literal, which the Games SDK
// requires: the ID is all digits and a bare numeric value is read as an
// integer, taking the SDK down on launch.

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

            // R8 runs on release builds whether or not this is spelled out, and
            // it strips anything it cannot see a reference to. Several of our
            // dependencies find their classes by name at runtime, which R8
            // cannot follow - without proguard-rules.pro the app died on launch
            // with "Failed to create an instance of androidx.work.impl.WorkDatabase"
            // before drawing a frame.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
