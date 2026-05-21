import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.lowercase().contains("release")
}

if (!keystorePropertiesFile.exists() && releaseBuildRequested) {
    throw GradleException("Release signing requires android/key.properties. Create it from android/key.properties.example.")
}

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

fun requiredSigningProperty(name: String): String {
    val value = keystoreProperties[name] as String?
    if (value.isNullOrBlank() && releaseBuildRequested) {
        throw GradleException("Missing '$name' in android/key.properties for release signing.")
    }
    return value.orEmpty()
}

android {
    namespace = "com.som.kamateilii"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.som.kamateilii"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = requiredSigningProperty("storeFile")
            if (storeFilePath.isNotBlank()) {
                val resolvedStoreFile = file(storeFilePath)
                if (!resolvedStoreFile.exists() && releaseBuildRequested) {
                    throw GradleException("Release signing storeFile does not exist: $storeFilePath")
                }
                storeFile = resolvedStoreFile
            }
            storePassword = requiredSigningProperty("storePassword")
            keyAlias = requiredSigningProperty("keyAlias")
            keyPassword = requiredSigningProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
