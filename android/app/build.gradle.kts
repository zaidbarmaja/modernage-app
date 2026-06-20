plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.mohameed_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // مطلوب لـ flutter_local_notifications (إشعارات الدوام المجدولة).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // يجب أن يطابق package_name في google-services.json (تطبيق أندرويد في Firebase).
        applicationId = "modernage.online"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // firebase_auth requires a minimum SDK of 23.
        minSdk = maxOf(23, flutter.minSdkVersion)
        multiDexEnabled = true
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
    // مكتبة إعادة تأهيل واجهات Java 8+ (تاريخ/وقت) المطلوبة للإشعارات المجدولة.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
