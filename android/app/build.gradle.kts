import java.util.Properties 

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 1. Load the key.properties file safely.
val properties = Properties()
val propertiesFile = rootProject.file("key.properties")
if (propertiesFile.exists()) {
    propertiesFile.inputStream().use { properties.load(it) }
}

android {
    namespace = "com.example.vlone_blog_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // 2. Define the signing configurations
    signingConfigs {
        create("release") {
            storeFile = file(properties.getProperty("storeFile") ?: "")
            storePassword = properties.getProperty("storePassword")
            keyAlias = properties.getProperty("keyAlias")
            keyPassword = properties.getProperty("keyPassword")
        }
    }

    defaultConfig {
        applicationId = "com.example.vlone_blog_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // ✅ Use debug signing config temporarily for testing
            signingConfig = signingConfigs.getByName("debug")

            // Commented out release signing config
            // signingConfig = signingConfigs.getByName("release")

            // isMinifyEnabled = false
            // isShrinkResources = false
        }
        // Debug build type remains unchanged
    }
}

flutter {
    source = "../.."
}
