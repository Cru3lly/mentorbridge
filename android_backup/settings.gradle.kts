pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        maven("https://storage.googleapis.com/download.flutter.io")
    }
    resolutionStrategy {
        eachPlugin {
            if (requested.id.id == "flutter") {
                // Plugin id = "flutter" => use this module
                useModule("io.flutter:flutter-gradle-plugin:1.0.0")
            }
        }
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        maven("https://storage.googleapis.com/download.flutter.io")
    }
}

rootProject.name = "mentorbridge"
include(":app")
