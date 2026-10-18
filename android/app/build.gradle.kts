import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * Release signing (docs/release/android.md). Read from `android/key.properties`
 * (git-ignored, see `key.properties.example`) when it exists, else from the
 * `STOCKLY_UPLOAD_*` environment variables (CI secrets). Never falls back to
 * debug signing: without a complete set the release build fails.
 */
data class UploadSigning(
    val storeFile: String?,
    val storePassword: String?,
    val keyAlias: String?,
    val keyPassword: String?,
    val source: String,
) {
    val missing: List<String>
        get() = listOf(
            "storeFile" to storeFile,
            "storePassword" to storePassword,
            "keyAlias" to keyAlias,
            "keyPassword" to keyPassword,
        ).filter { it.second.isNullOrBlank() }.map { it.first }
}

val keyPropertiesFile = rootProject.file("key.properties")
val uploadSigning: UploadSigning =
    if (keyPropertiesFile.exists()) {
        val properties = Properties()
        keyPropertiesFile.inputStream().use { properties.load(it) }
        UploadSigning(
            storeFile = properties.getProperty("storeFile")
                ?.takeIf { it.isNotBlank() }
                ?.let { rootProject.file(it).absolutePath },
            storePassword = properties.getProperty("storePassword"),
            keyAlias = properties.getProperty("keyAlias"),
            keyPassword = properties.getProperty("keyPassword"),
            source = "android/key.properties",
        )
    } else {
        UploadSigning(
            storeFile = System.getenv("STOCKLY_UPLOAD_STORE_FILE"),
            storePassword = System.getenv("STOCKLY_UPLOAD_STORE_PASSWORD"),
            keyAlias = System.getenv("STOCKLY_UPLOAD_KEY_ALIAS"),
            keyPassword = System.getenv("STOCKLY_UPLOAD_KEY_PASSWORD"),
            source = "the STOCKLY_UPLOAD_* environment variables",
        )
    }
val hasUploadSigning = uploadSigning.missing.isEmpty()

/** The `--dart-define` values Flutter passes to Gradle (base64, comma-separated). */
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.filter { it.isNotBlank() }
        ?.map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
        ?.mapNotNull { entry ->
            val separator = entry.indexOf('=')
            if (separator <= 0) null else entry.substring(0, separator) to entry.substring(separator + 1)
        }
        ?.toMap()
        ?: emptyMap()

/** Why a release build must stop; empty when it may go on. */
fun releaseProblems(): List<String> {
    val problems = mutableListOf<String>()
    if (!hasUploadSigning) {
        problems += if (keyPropertiesFile.exists()) {
            "Release signing is incomplete in ${uploadSigning.source}: missing " +
                uploadSigning.missing.joinToString(", ") + "."
        } else {
            "Release signing is not configured: create android/key.properties " +
                "(copy android/key.properties.example) or set STOCKLY_UPLOAD_STORE_FILE, " +
                "STOCKLY_UPLOAD_STORE_PASSWORD, STOCKLY_UPLOAD_KEY_ALIAS and " +
                "STOCKLY_UPLOAD_KEY_PASSWORD. The release build never uses debug signing."
        }
    } else if (!file(uploadSigning.storeFile!!).exists()) {
        problems += "Release keystore not found: ${uploadSigning.storeFile} (from ${uploadSigning.source})."
    }
    val baseUrl = dartDefines["STOCKLY_API_BASE_URL"]
    if (baseUrl.isNullOrBlank()) {
        problems += "Release builds need --dart-define=STOCKLY_API_BASE_URL=https://<api host>."
    } else if (!baseUrl.startsWith("https://")) {
        problems += "STOCKLY_API_BASE_URL must start with https:// in a release build (got $baseUrl)."
    }
    if (dartDefines["STOCKLY_BACKEND"] == "fake") {
        problems += "Release builds must not use --dart-define=STOCKLY_BACKEND=fake."
    }
    return problems
}

android {
    namespace = "com.stockly.stockly"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.stockly.stockly"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Version name and code come from `version:` in pubspec.yaml.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadSigning) {
            create("upload") {
                storeFile = file(uploadSigning.storeFile!!)
                storePassword = uploadSigning.storePassword
                keyAlias = uploadSigning.keyAlias
                keyPassword = uploadSigning.keyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasUploadSigning) {
                signingConfig = signingConfigs.getByName("upload")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// The release guard: stops before anything is compiled or signed.
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        val problems = releaseProblems()
        if (problems.isNotEmpty()) {
            throw GradleException(
                "Stockly release build stopped (docs/release/android.md):\n" +
                    problems.joinToString("\n") { "  - $it" },
            )
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
