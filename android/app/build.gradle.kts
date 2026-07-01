import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase
    id("com.google.gms.google-services")
}

// تحميل بيانات توقيع الإصدار من android/key.properties (سرّي ومستبعَد من Git).
// إن لم يوجد الملف (مثل بيئات التطوير) يعود التوقيع إلى مفاتيح debug تلقائيًا.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "modernage.online"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // مطلوب لمكتبة flutter_local_notifications (واجهات Java 8 للتاريخ/الوقت).
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

    signingConfigs {
        // تهيئة توقيع الإصدار من key.properties فقط عند توفّره.
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // التوقيع بمفتاح الإصدار الحقيقي عند توفّره، وإلا مفاتيح debug للتطوير
            // المحلي (Google Play يرفض الرفع بمفاتيح debug).
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
