# Solución al Error de Notificaciones

## Error:
```
Dependency ':flutter_local_notifications' requires core library desugaring to be enabled
```

## Solución Rápida:

### Opción 1: Ejecutar el Script Automático (Recomendado)

Desde PowerShell en la raíz del proyecto, ejecuta:
```powershell
.\fix_android_notifications.ps1
```

Luego:
```bash
flutter clean
flutter pub get
flutter run
```

---

### Opción 2: Cambios Manuales en `android/app/build.gradle`

#### Paso 1: Busca el bloque `compileOptions` dentro de `android {`

Debe verse así:
```gradle
compileOptions {
    sourceCompatibility JavaVersion.VERSION_1_8
    targetCompatibility JavaVersion.VERSION_1_8
}
```

**Cámbialo a:**
```gradle
compileOptions {
    sourceCompatibility JavaVersion.VERSION_1_8
    targetCompatibility JavaVersion.VERSION_1_8
    coreLibraryDesugaringEnabled true  // <-- AGREGAR ESTA LÍNEA
}
```

#### Paso 2: Busca el bloque `dependencies {`

**Agrega esta línea dentro de `dependencies {`:**
```gradle
dependencies {
    // ... tus otras dependencias ...
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'  // <-- AGREGAR ESTA LÍNEA
}
```

#### Paso 3: Limpia y reconstruye

```bash
flutter clean
flutter pub get
flutter run
```

---

## Verificación

Después de hacer los cambios, verifica que el archivo contenga:
1. ✅ `coreLibraryDesugaringEnabled true` en `compileOptions`
2. ✅ `coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'` en `dependencies`

Si ambos están presentes, el error debería estar resuelto.
