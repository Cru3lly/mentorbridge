// android/settings.gradle.kts
import java.util.Properties
import java.io.File

// 1) Load local.properties (the one Flutter generates in android/local.properties)
val localProps = Properties().apply {
    val propsFile = rootDir.resolve("local.properties")
    if (propsFile.exists()) {
        propsFile.inputStream().use { load(it) }
    }
}

// 2) Read flutter.sdk out of it (fail fast if someone forgot to flutter pub get)
val flutterSdkPath: String = localProps.getProperty("flutter.sdk")
    ?: throw GradleException("flutter.sdk not set in android/local.properties")

// Read flutter.sdk from local.properties
val localProperties = Properties()
val localPropertiesFile = File(rootDir, "local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}
val flutterSdkPathFromLocalProperties = localProperties.getProperty("flutter.sdk") ?: throw GradleException("flutter.sdk not set in local.properties")

pluginManagement {
    // 3) Tell Gradle to include Flutter's own tooling plugin
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
        // Flutter Engine AARs
        maven("https://storage.googleapis.com/download.flutter.io")
    }

    plugins {
        // loader must be declared here (but apply false so sub-projects opt in)
        id("dev.flutter.flutter-plugin-loader") version "1.0.0" apply false

        // Android/Kotlin/Google-Services
        id("com.android.application")       version "8.3.1" apply false
        id("org.jetbrains.kotlin.android")  version "1.9.22" apply false
        id("com.google.gms.google-services")version "4.4.1" apply false
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven("https://storage.googleapis.com/download.flutter.io")
    }
}

rootProject.name = "mentorbridge"
include(":app")
