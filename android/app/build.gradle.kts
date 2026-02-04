plugins {
    id("com.android.application")
    id("kotlin-android")
    // Il plugin di Flutter deve essere applicato dopo Android e Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Deve corrispondere al pacchetto definito nel tuo AndroidManifest.xml
    namespace = "com.example.low_fps_recorder"
    
    // Forziamo la compilazione con SDK 36 (richiesto dai plugin nel 2026)
    compileSdk = 36
    
    // Versione NDK specifica per FFmpegKit v6+
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.low_fps_recorder"
        
        // FFmpeg e CameraX richiedono almeno API 24 (Android 7.0)
        minSdk = 24
        targetSdk = 36
        
        versionCode = 1
        versionName = "1.0"

        // Necessario se l'app supera il limite di 64k metodi a causa di FFmpeg
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Usiamo la firma di debug per permettere il test immediato dell'APK
            signingConfig = signingConfigs.getByName("debug")
            
            // Ottimizzazioni per FFmpeg (evita che Proguard rompa le librerie native)
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // Risolve i conflitti di file duplicati tra le librerie native di FFmpeg e Flutter
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "**/libc++_shared.so"
        }
    }
}

flutter {
    source = "../.."
}

// Forza il repository Maven Central per le dipendenze di Arthenica (FFmpeg)
repositories {
    google()
    mavenCentral()
}