plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

configurations.all {
    exclude(group = "org.tensorflow", module = "tensorflow-lite-api")
    exclude(group = "org.tensorflow", module = "tensorflow-lite-gpu")
}

android {
    namespace = "com.example.patient_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.patient_app"
        
        // BUMPED: Satisfies tflite_flutter minSdk requirement
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    aaptOptions {
        noCompress("tflite", "lite")
    }

    buildTypes {
        release {
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
