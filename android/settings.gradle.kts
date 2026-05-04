pluginManagement {
    // 1. WE MUST KEEP THIS: It tells Gradle where Flutter lives on your computer!
    val flutterSdkPath = {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPathString = properties.getProperty("flutter.sdk")
        assert(flutterSdkPathString != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPathString
    }()

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    
    // NOTE: 8.11.1 and 2.2.20 look like typos! 
    // I changed them to stable versions, but if your project requires different ones, change them back.
    id("com.android.application") version "8.9.1" apply false 
    id("com.google.gms.google-services") version "4.3.15" apply false
    id("org.jetbrains.kotlin.android") version "2.2.0" apply false 
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()

        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }

        // 2. MAPBOX REPOSITORY SETTINGS
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            credentials {
                username = "mapbox" // Always "mapbox"
                // This grabs the secret token from your gradle.properties file
                password = providers.gradleProperty("MAPBOX_DOWNLOADS_TOKEN").orNull
            }
            // 3. THIS IS REQUIRED BY MAPBOX TO LOG IN
            authentication {
                create<BasicAuthentication>("basic")
            }
        }
    }
}

rootProject.name = "recipe_app"
include(":app")