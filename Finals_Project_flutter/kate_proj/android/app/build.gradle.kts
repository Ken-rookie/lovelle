import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseProperties = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.exists()) {
        propertiesFile.inputStream().use { input ->
            load(input)
        }
    }
}
val releaseApplicationId = providers.gradleProperty("lovelleApplicationId").orNull
    ?: providers.environmentVariable("LOVELLE_APPLICATION_ID").orNull
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val releaseSigningKeys = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
)
val missingReleaseSigningKeys =
    releaseSigningKeys.filter { releaseProperties.getProperty(it).isNullOrBlank() }

if (releaseBuildRequested) {
    if (releaseApplicationId.isNullOrBlank() ||
        releaseApplicationId.startsWith("com.example")
    ) {
        throw GradleException(
            "Set -PlovelleApplicationId or LOVELLE_APPLICATION_ID to your " +
                "registered Android application ID before a release build.",
        )
    }
    if (missingReleaseSigningKeys.isNotEmpty()) {
        throw GradleException(
            "Configure android/key.properties with storeFile, storePassword, " +
                "keyAlias, and keyPassword before a release build.",
        )
    }
}

android {
    namespace = "com.example.kate_proj"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = releaseApplicationId ?: "com.example.kate_proj"
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

    signingConfigs {
        create("release") {
            releaseProperties.getProperty("storeFile")?.let {
                storeFile = file(it)
            }
            storePassword = releaseProperties.getProperty("storePassword")
            keyAlias = releaseProperties.getProperty("keyAlias")
            keyPassword = releaseProperties.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
