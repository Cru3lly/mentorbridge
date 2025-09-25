buildscript {
    val kotlin_version by extra("1.9.25")
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.5.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}



rootProject.layout.buildDirectory = file("../build")
subprojects {
    project.layout.buildDirectory = file("${rootProject.layout.buildDirectory.get()}/${project.name}")
}

tasks.register("clean", Delete::class) {
    delete(rootProject.layout.buildDirectory)
}
