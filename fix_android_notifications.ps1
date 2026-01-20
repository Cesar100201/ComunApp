# Script para corregir la configuración de Android para notificaciones
# Ejecuta este script desde la raíz del proyecto: .\fix_android_notifications.ps1

$buildGradlePath = "android\app\build.gradle"

if (-not (Test-Path $buildGradlePath)) {
    Write-Host "Error: No se encuentra el archivo $buildGradlePath" -ForegroundColor Red
    exit 1
}

Write-Host "Leyendo archivo build.gradle..." -ForegroundColor Yellow
$content = Get-Content $buildGradlePath -Raw

# Crear backup
$backupPath = "$buildGradlePath.backup"
Copy-Item $buildGradlePath $backupPath
Write-Host "Backup creado en: $backupPath" -ForegroundColor Green

$modified = $false

# Verificar y agregar coreLibraryDesugaringEnabled en compileOptions
if ($content -match 'compileOptions\s*\{') {
    if ($content -notmatch 'coreLibraryDesugaringEnabled') {
        Write-Host "Agregando coreLibraryDesugaringEnabled..." -ForegroundColor Yellow
        # Buscar compileOptions y agregar coreLibraryDesugaringEnabled después de targetCompatibility
        $content = $content -replace '(compileOptions\s*\{[^}]*?targetCompatibility\s+JavaVersion\.VERSION_\d+_\d+)', "`$1`n        coreLibraryDesugaringEnabled true"
        
        # Si no hay targetCompatibility, agregar ambas líneas después de sourceCompatibility
        if ($content -notmatch 'coreLibraryDesugaringEnabled') {
            $content = $content -replace '(compileOptions\s*\{[^}]*?sourceCompatibility\s+JavaVersion\.VERSION_\d+_\d+)', "`$1`n        targetCompatibility JavaVersion.VERSION_1_8`n        coreLibraryDesugaringEnabled true"
        }
        $modified = $true
    } else {
        Write-Host "coreLibraryDesugaringEnabled ya está configurado" -ForegroundColor Green
    }
} else {
    Write-Host "Agregando bloque compileOptions completo..." -ForegroundColor Yellow
    # Buscar el bloque android { y agregar compileOptions después de compileSdkVersion o namespace
    if ($content -match '(android\s*\{[^\}]*?)(compileSdkVersion|namespace)') {
        $content = $content -replace '(android\s*\{[^\}]*?(?:compileSdkVersion|namespace)[^\}]*?)', "`$1`n`n    compileOptions {`n        sourceCompatibility JavaVersion.VERSION_1_8`n        targetCompatibility JavaVersion.VERSION_1_8`n        coreLibraryDesugaringEnabled true`n    }"
        $modified = $true
    }
}

# Verificar y agregar dependencia de desugaring
if ($content -notmatch "coreLibraryDesugaring\s+'com\.android\.tools:desugar_jdk_libs") {
    Write-Host "Agregando dependencia coreLibraryDesugaring..." -ForegroundColor Yellow
    
    # Buscar el bloque dependencies
    if ($content -match '(dependencies\s*\{)') {
        # Agregar después de dependencies {
        $content = $content -replace '(dependencies\s*\{)', "`$1`n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'"
        $modified = $true
    } else {
        # Si no existe dependencies, agregarlo antes del cierre del archivo o después de flutter {}
        if ($content -match '(flutter\s*\{[^\}]*\})') {
            $content = $content -replace '(flutter\s*\{[^\}]*\})', "`$1`n`ndependencies {`n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'`n}"
            $modified = $true
        }
    }
} else {
    Write-Host "Dependencia coreLibraryDesugaring ya está configurada" -ForegroundColor Green
}

if ($modified) {
    # Guardar cambios
    Set-Content -Path $buildGradlePath -Value $content -Encoding UTF8
    Write-Host "`n¡Archivo build.gradle actualizado exitosamente!" -ForegroundColor Green
    Write-Host "Cambios realizados:" -ForegroundColor Cyan
    Write-Host "  1. Habilitado coreLibraryDesugaringEnabled en compileOptions" -ForegroundColor White
    Write-Host "  2. Agregada dependencia coreLibraryDesugaring" -ForegroundColor White
    Write-Host "`nAhora ejecuta:" -ForegroundColor Yellow
    Write-Host "  flutter clean" -ForegroundColor White
    Write-Host "  flutter pub get" -ForegroundColor White
    Write-Host "  flutter run" -ForegroundColor White
} else {
    Write-Host "`nNo se requieren cambios. El archivo ya está configurado correctamente." -ForegroundColor Green
}
