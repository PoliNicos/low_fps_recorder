plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.low_fps_recorder"
    
    // FORZIAMO l'SDK 35 come richiesto dai plugin
    compileSdk = 35 
    
    // FORZIAMO l'NDK alla versione 27 richiesta da FFmpeg e Camera
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.low_fps_recorder"
        
        // FFmpeg e CameraX lavorano meglio con minSdk almeno a 24
        minSdk = 24 
        targetSdk = 35
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // Ottimizzazione per ridurre la dimensione dell'APK
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
