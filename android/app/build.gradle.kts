plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.hiperdiario"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"
        // ndkVersion = flutter.ndkVersion
        // Nota: Desativado temporariamente para evitar a instalação automática do NDK
        // em ambientes com pouco espaço no disco do usuário. Para projetos que realmente
        // necessitam de NDK/C++ (plugins nativos com código C/C++), reative esta linha
        // após garantir espaço suficiente ou mover o SDK/NDK para outra unidade.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Necessário para bibliotecas que usam APIs Java 8+ (ex.: flutter_local_notifications)
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.hiperdiario"
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

flutter {
    source = "../.."
}

dependencies {
    // Desugaring para suportar APIs Java 8+ em tempo de execução
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
