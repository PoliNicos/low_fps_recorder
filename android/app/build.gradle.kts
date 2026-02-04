plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.low_fps_recorder"
    compileSdk = 34 // Usiamo 34 per stabilità con FFmpeg 5.1

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.low_fps_recorder"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            // Escludiamo i conflitti delle librerie native
            excludes += "**/libc++_shared.so"
            pickFirst("lib/**/libavcodec.so")
            pickFirst("lib/**/libavdevice.so")
            pickFirst("lib/**/libavfilter.so")
            pickFirst("lib/**/libavformat.so")
            pickFirst("lib/**/libavutil.so")
            pickFirst("lib/**/libswresample.so")
            pickFirst("lib/**/libswscale.so")
        }
    }
}

flutter {
    source = "../.."
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}