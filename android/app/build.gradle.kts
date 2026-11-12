import groovy.json.JsonSlurper
import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ───── العيادة: من ملف إعداداتها (clinics/<id>/config.json) ─────
// flutter يمرر قيم --dart-define-from-file هنا (dart-defines: كل قيمة base64 ومفصولة بفاصلة)،
// فالمعرّف والاسم والأيقونة ولون البداية تجي من ملف العيادة نفسه بدون أي خطوة إضافية.
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?).orEmpty()
        .split(",")
        .filter { it.isNotBlank() }
        .map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
        .filter { it.contains("=") }
        .associate { it.substringBefore("=") to it.substringAfter("=") }
val clinicFromFile: String? = dartDefines["CLINIC_ID"]

// نسخة المتجر (App Bundle) لازم تنبني بملف عيادة صريح، والتشغيل بدون ملف = عيادتي (demo) وقت التطوير
if (clinicFromFile == null && gradle.startParameter.taskNames.any { it.contains("bundle", ignoreCase = true) }) {
    throw GradleException("نسخة الإنتاج لازم تنبني بملف العيادة: python3 tool/clinic.py build <id> appbundle")
}
val clinicId = clinicFromFile ?: "demo"
val clinicDir = rootProject.projectDir.resolve("../clinics/$clinicId").canonicalFile
val clinicFile = clinicDir.resolve("config.json")
if (!clinicFile.exists()) throw GradleException("ما لقيت ملف العيادة: clinics/$clinicId/config.json")
@Suppress("UNCHECKED_CAST")
val clinic = JsonSlurper().parse(clinicFile, "UTF-8") as Map<String, String>
if (clinic["CLINIC_ID"] != clinicId) throw GradleException("CLINIC_ID في clinics/$clinicId لازم يكون $clinicId")
fun clinicValue(key: String): String = clinic[key] ?: throw GradleException("clinics/$clinicId ناقص: $key")

android {
    namespace = "com.clinicsapp.clinics_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // معرّف التطبيق واسمه ولون شاشة البداية من ملف العيادة
        applicationId = clinicValue("CLINIC_ANDROID_APP_ID")
        resValue("string", "app_name", clinicValue("CLINIC_APP_NAME").replace("'", "\\'"))
        resValue("color", "clinic_splash", "#" + clinicValue("CLINIC_SPLASH_COLOR").substring(2))
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures {
        resValues = true
    }

    // أيقونة العيادة (clinics/<id>/android/res): ما ينبني إلا أصول العيادة المختارة
    sourceSets.getByName("main").res.srcDir(clinicDir.resolve("android/res"))

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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
