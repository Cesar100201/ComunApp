# Configuración de Android para Notificaciones

Para habilitar las notificaciones, necesitas hacer los siguientes cambios en el archivo `android/app/build.gradle`:

## Paso 1: Habilitar Core Library Desugaring

En el bloque `android {`, agrega o actualiza:

```gradle
android {
    compileSdkVersion 34  // o la versión que uses
    
    defaultConfig {
        // ... tus configuraciones existentes ...
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
        coreLibraryDesugaringEnabled true  // <-- AGREGAR ESTA LÍNEA
    }
    
    // ... resto de configuraciones ...
}
```

## Paso 2: Agregar la dependencia de desugaring

En el bloque `dependencies {`, agrega:

```gradle
dependencies {
    // ... tus dependencias existentes ...
    
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'  // <-- AGREGAR ESTA LÍNEA
}
```

## Ejemplo completo del archivo build.gradle:

```gradle
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode')
if (flutterVersionCode == null) {
    flutterVersionCode = '1'
}

def flutterVersionName = localProperties.getProperty('flutter.versionName')
if (flutterVersionName == null) {
    flutterVersionName = '1.0'
}

android {
    namespace "ve.gob.alcaldialsfria.goblafria"
    compileSdkVersion 34
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
        coreLibraryDesugaringEnabled true  // <-- AGREGAR ESTA LÍNEA
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "ve.gob.alcaldialsfria.goblafria"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}

flutter {
    source '../..'
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'  // <-- AGREGAR ESTA LÍNEA
}
```

Después de hacer estos cambios, ejecuta:
```bash
flutter clean
flutter pub get
flutter run
```
