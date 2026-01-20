plugins {
    id("com.android.application") apply false
    id("com.android.library") apply false
    id("org.jetbrains.kotlin.android") apply false
    id("com.google.gms.google-services") version "4.4.4" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    afterEvaluate {
        // 1. SOLUCIÓN AL ERROR DE NAMESPACE
        // Esto busca en el manifiesto el paquete si el namespace es nulo
        if (project.extensions.findByName("android") != null) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            
            // Si el namespace está vacío, intentamos obtenerlo del AndroidManifest
            if (android.namespace == null) {
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val xml = groovy.xml.XmlParser().parse(manifestFile)
                    val packageName = xml.attribute("package")?.toString()
                    if (packageName != null) {
                        android.namespace = packageName
                    }
                }
            }

            // 2. FORZAR SDK (Tu configuración actual mejorada)
            android.compileSdkVersion(36)
            
            android.defaultConfig {
                if (minSdkVersion == null) {
                    minSdkVersion(21) // Aseguramos un mínimo compatible
                }
                targetSdkVersion(36)
            }
        }
    }
}



subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}