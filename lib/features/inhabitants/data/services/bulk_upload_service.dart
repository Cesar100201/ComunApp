import 'dart:io';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../../../../models/models.dart';
import '../../../../database/db_helper.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/constants.dart';

/// Servicio optimizado para carga masiva de habitantes desde Excel/CSV.
/// 
/// CSV es 10-50x más rápido que Excel para archivos grandes.
/// Usa isolates para parsear sin bloquear el hilo principal.
/// Procesa registros en lotes para mejor rendimiento con archivos grandes.
class BulkUploadService {
  static const int _batchSize = AppConstants.batchSize;
  
  /// Detecta si el archivo es CSV basado en la extensión
  static bool esArchivoCSV(String filePath) {
    return filePath.toLowerCase().endsWith('.csv');
  }
  
  /// Procesa un archivo Excel/CSV parseando en isolate y guardando en hilo principal
  /// CSV es significativamente más rápido para archivos grandes (10-50x)
  static Future<BulkUploadResult> procesarExcelEnSegundoPlano(
    String filePath,
    Function(int progreso, int total, String etiqueta)? onProgress,
  ) async {
    final result = BulkUploadResult();
    final esCSV = esArchivoCSV(filePath);
    
    try {
      // Notificar inicio del parseo
      if (onProgress != null) {
        final tipoArchivo = esCSV ? 'CSV' : 'Excel';
        onProgress(0, 100, 'Leyendo archivo $tipoArchivo...');
      }
      
      // Parsear en isolate según el tipo de archivo
      List<Map<String, dynamic>> datosParseados;
      
      if (esCSV) {
        // CSV es MUCHO más rápido (10-50x)
        AppLogger.info('Iniciando parseo de CSV en isolate (optimizado)...');
        datosParseados = await compute(_parsearCSVEnIsolate, filePath);
      } else {
        // Excel es más lento pero soporta formato nativo
        AppLogger.info('Iniciando parseo de Excel en isolate...');
        datosParseados = await compute(_parsearExcelEnIsolate, filePath);
      }
      AppLogger.info('Total de filas parseadas: ${datosParseados.length}');
      
      if (datosParseados.isEmpty) {
        result.errors.add('El archivo Excel está vacío o no tiene datos');
        if (onProgress != null) {
          onProgress(0, 100, 'Error: Archivo vacío');
        }
        return result;
      }

      result.totalRows = datosParseados.length;
      
      // Notificar que se encontraron datos
      if (onProgress != null) {
        final progressValue = (result.totalRows * AppConstants.progressPercentageFileRead).round();
        onProgress(progressValue, result.totalRows, 'Archivo leído: ${result.totalRows} registros encontrados');
        await Future.delayed(const Duration(milliseconds: 100));
        onProgress(progressValue, result.totalRows, 'Cargando referencias de base de datos...');
      }
      
      // Guardar en base de datos en el hilo principal (Isar requiere hilo principal)
      AppLogger.debug('Conectando a base de datos...');
      final isar = await DbHelper().db;
      AppLogger.debug('Conexión a BD establecida');
      
      // Cargar mapas de referencia en memoria
      AppLogger.debug('Cargando referencias de base de datos...');
      final consejosMap = <String, ConsejoComunal>{};
      final clapsMap = <String, Clap>{};
      
      final consejosComunales = await isar.consejoComunals.where().findAll();
      final claps = await isar.claps.where().findAll();
      
      AppLogger.debug('Consejos comunales cargados: ${consejosComunales.length}');
      AppLogger.debug('CLAPs cargados: ${claps.length}');
      
      for (var cc in consejosComunales) {
        consejosMap[cc.nombreConsejo.toLowerCase()] = cc;
      }
      for (var clap in claps) {
        clapsMap[clap.nombreClap.toLowerCase()] = clap;
      }

      // Notificar inicio del procesamiento
      if (onProgress != null) {
        final progressValue = (result.totalRows * AppConstants.progressPercentageProcessingStart).round();
        onProgress(progressValue, result.totalRows, 'Iniciando procesamiento de ${result.totalRows} registros...');
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Procesar y guardar en lotes
      AppLogger.info('Iniciando procesamiento de ${datosParseados.length} registros...');
      final loteBuffer = <Habitante>[];
      final cedulasJefesPendientes = <int, List<Habitante>>{};
      // Para archivos grandes, reportar más frecuentemente
      final int reportInterval = datosParseados.length > AppConstants.largeFileThreshold 
          ? AppConstants.progressReportIntervalLarge 
          : AppConstants.progressReportIntervalSmall;
      
      AppLogger.debug('Entrando al bucle principal...');
      for (var i = 0; i < datosParseados.length; i++) {
        if (i == 0) {
          AppLogger.debug('Procesando primera fila (índice 0)...');
        }
        final rowMap = datosParseados[i];
        
        try {
          // Validaciones básicas
          final cedulaStr = (_getValue(rowMap, ['cedula', 'ced', 'cédula']) ?? '')
              .replaceAll(RegExp(r'[^\d]'), '');
          
          if (cedulaStr.isEmpty) {
            result.errorCount++;
            result.errors.add('Fila ${i + 2}: Cédula es requerida');
            continue;
          }

          final cedula = int.tryParse(cedulaStr);
          if (cedula == null) {
            result.errorCount++;
            result.errors.add('Fila ${i + 2}: Cédula inválida: $cedulaStr');
            continue;
          }

          final nombreCompleto = _getValue(rowMap, ['nombre completo', 'nombrecompleto', 'nombre']) ?? '';
          if (nombreCompleto.isEmpty) {
            result.errorCount++;
            result.errors.add('Fila ${i + 2}: Nombre completo es requerido');
            continue;
          }

          // Crear habitante
          final habitante = Habitante()..cedula = cedula;
          habitante.nacionalidad = _parseNacionalidad(_getValue(rowMap, ['nacionalidad']));
          habitante.nombreCompleto = nombreCompleto.toUpperCase();
          habitante.telefono = _getValue(rowMap, ['telefono', 'teléfono']) ?? '';
          habitante.genero = _parseGenero(_getValue(rowMap, ['genero', 'género']));
          habitante.direccion = _construirDireccion(rowMap);
          habitante.estatusPolitico = _parseEstatusPolitico(_getValue(rowMap, ['estatus politico', 'estatuspolitico', 'estatus']));
          habitante.nivelVoto = _parseNivelVoto(_getValue(rowMap, ['nivel voto', 'nivelvoto', 'nivel']));
          habitante.nivelUsuario = AppConstants.defaultUserIdLevel;
          habitante.isSynced = false;
          habitante.isDeleted = false;
          habitante.fotoUrl = null;
          
          final fechaNac = _parseFecha(_getValue(rowMap, ['fecha nacimiento', 'fechanacimiento', 'fecha', 'fecha de nacimiento']));
          habitante.fechaNacimiento = fechaNac ?? AppConstants.defaultBirthDate;
          
          // Log reducido - solo cada 1000 registros para archivos grandes
          if (i % 1000 == 0 || i == 0) {
            AppLogger.debug('Procesando habitante ${i + 1}/${datosParseados.length}: ${habitante.cedula} - ${habitante.nombreCompleto}');
          }

          // Asignar consejo comunal
          final nombreCC = _getValue(rowMap, ['consejo comunal', 'consejocomunal'])?.toLowerCase();
          if (nombreCC != null && nombreCC.isNotEmpty) {
            final ccEncontrado = consejosMap[nombreCC];
            if (ccEncontrado != null) {
              habitante.consejoComunal.value = ccEncontrado;
            }
          }

          // Asignar CLAP
          final nombreClap = _getValue(rowMap, ['clap'])?.toLowerCase();
          if (nombreClap != null && nombreClap.isNotEmpty) {
            final clapEncontrado = clapsMap[nombreClap];
            if (clapEncontrado != null) {
              habitante.clap.value = clapEncontrado;
            }
          }

          // Cédula jefe de familia
          final cedulaJefeStr = (_getValue(rowMap, ['cedula jefe', 'cedulajefe']) ?? '')
              .replaceAll(RegExp(r'[^\d]'), '');
          if (cedulaJefeStr.isNotEmpty) {
            final cedulaJefe = int.tryParse(cedulaJefeStr);
            if (cedulaJefe != null) {
              cedulasJefesPendientes.putIfAbsent(cedulaJefe, () => []).add(habitante);
            }
          }

          loteBuffer.add(habitante);
          result.successCount++;

          // Reportar progreso durante procesamiento
          if ((i + 1) % reportInterval == 0 || i == datosParseados.length - 1) {
            if (onProgress != null) {
              // Calcular progreso real usando constantes
              final progresoProcesamiento = (i + 1) / datosParseados.length;
              final progresoReal = (result.totalRows * AppConstants.progressPercentageProcessingStart + 
                  result.totalRows * (AppConstants.progressPercentageProcessingEnd - AppConstants.progressPercentageProcessingStart) * progresoProcesamiento).round();
              onProgress(
                progresoReal, 
                result.totalRows, 
                'Procesando: ${i + 1}/${datosParseados.length} (${result.successCount} válidos, ${result.errorCount} errores)'
              );
            }
            // Para archivos grandes, reducir delays para mejor rendimiento
            if (datosParseados.length > AppConstants.largeFileThreshold) {
              await Future.delayed(const Duration(milliseconds: 1));
            } else {
              await Future.delayed(const Duration(milliseconds: 5));
            }
          }

          // Guardar en lotes grandes
          if (loteBuffer.length >= _batchSize) {
            if (onProgress != null) {
              // Progreso durante guardado
              final progresoGuardado = AppConstants.progressPercentageSaving + 
                  (AppConstants.progressPercentageSavingEnd - AppConstants.progressPercentageSaving) * (i + 1) / datosParseados.length;
              final progresoReal = (result.totalRows * progresoGuardado).round();
              onProgress(
                progresoReal, 
                result.totalRows, 
                'Guardando lote en base de datos (${loteBuffer.length} registros)...'
              );
            }
            await _guardarLoteOptimizado(isar, loteBuffer);
            loteBuffer.clear();
            
            // Reducir delays para archivos grandes
            if (datosParseados.length > AppConstants.largeFileThreshold) {
              // No hacer delay para archivos grandes - mejor rendimiento
            } else {
              await Future.delayed(const Duration(milliseconds: 10));
            }
          }
        } catch (e, stackTrace) {
          result.errorCount++;
          result.errors.add('Fila ${i + 2}: Error - $e');
          AppLogger.error('Error en fila ${i + 2}', e, stackTrace);
        }
      }

      AppLogger.info('Bucle principal completado. Guardados: ${result.successCount}, Errores: ${result.errorCount}');

      // Guardar lote final
      if (loteBuffer.isNotEmpty) {
        if (onProgress != null) {
          final progresoReal = (result.totalRows * AppConstants.progressPercentageRelations).round();
          onProgress(progresoReal, result.totalRows, 'Guardando lote final en base de datos...');
        }
        await _guardarLoteOptimizado(isar, loteBuffer);
      }

      // Procesar jefes de familia pendientes
      if (cedulasJefesPendientes.isNotEmpty) {
        if (onProgress != null) {
          final progresoReal = (result.totalRows * AppConstants.progressPercentageRelations).round();
          onProgress(progresoReal, result.totalRows, 'Procesando relaciones de jefes de familia...');
        }
        await _procesarJefesPendientes(isar, cedulasJefesPendientes, onProgress);
        
        if (onProgress != null) {
          final progresoReal = (result.totalRows * AppConstants.progressPercentageRelationsEnd).round();
          onProgress(progresoReal, result.totalRows, 'Relaciones procesadas');
        }
      }

      // Notificar finalización (100%)
      if (onProgress != null) {
        onProgress(result.totalRows, result.totalRows, '¡Proceso completado exitosamente!');
      }

    } catch (e, stackTrace) {
      AppLogger.error('ERROR CRÍTICO en procesarExcelEnSegundoPlano', e, stackTrace);
      result.errors.add('Error al procesar archivo: $e');
      if (onProgress != null) {
        onProgress(0, result.totalRows, 'Error en el procesamiento');
      }
    }

    AppLogger.info('Resultado final: ${result.totalRows} totales, ${result.successCount} exitosos, ${result.errorCount} errores');
    return result;
  }

  /// Parsea CSV en un isolate - MUCHO MÁS RÁPIDO que Excel (10-50x)
  /// Usa streaming para máximo rendimiento con archivos grandes
  static List<Map<String, dynamic>> _parsearCSVEnIsolate(String filePath) {
    try {
      final file = File(filePath);
      final contenido = file.readAsStringSync();
      
      // Detectar delimitador (coma, punto y coma, o tabulador)
      final primeraLinea = contenido.split('\n').first;
      String delimitador = ',';
      if (primeraLinea.contains(';') && !primeraLinea.contains(',')) {
        delimitador = ';';
      } else if (primeraLinea.contains('\t') && !primeraLinea.contains(',') && !primeraLinea.contains(';')) {
        delimitador = '\t';
      }
      
      // Parsear CSV con el delimitador detectado
      final csvConverter = CsvToListConverter(
        fieldDelimiter: delimitador,
        shouldParseNumbers: false, // Mantener como strings para consistencia
        allowInvalid: true,
        eol: '\n',
      );
      
      final rows = csvConverter.convert(contenido);
      
      if (rows.isEmpty) {
        return [];
      }
      
      // Primera fila son los headers
      final headers = rows[0]
          .map((cell) => cell?.toString().trim().toLowerCase() ?? '')
          .toList();
      
      if (kDebugMode) {
        debugPrint('Headers encontrados en CSV: ${headers.join(", ")}');
      }
      
      // Parsear todas las filas de datos (desde la fila 1)
      final datos = <Map<String, dynamic>>[];
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;
        
        // Verificar que la fila no esté completamente vacía
        final tieneContenido = row.any((cell) => 
            cell != null && cell.toString().trim().isNotEmpty);
        if (!tieneContenido) continue;
        
        final rowMap = <String, dynamic>{};
        for (var j = 0; j < headers.length && j < row.length; j++) {
          final value = row[j];
          final headerKey = headers[j];
          if (headerKey.isNotEmpty) {
            rowMap[headerKey] = value?.toString().trim() ?? '';
          }
        }
        
        if (rowMap.isNotEmpty) {
          datos.add(rowMap);
          if (datos.length == 1 && kDebugMode) {
            debugPrint('Primera fila CSV procesada: ${rowMap.keys.join(", ")}');
            debugPrint('Valores primera fila CSV: $rowMap');
          }
        }
      }
      
      if (kDebugMode) {
        debugPrint('CSV parseado: ${datos.length} filas en total');
      }
      
      return datos;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error parseando CSV: $e');
      }
      return [];
    }
  }

  /// Parsea el Excel en un isolate (solo lectura, sin acceso a BD)
  /// Nota: Excel es más lento que CSV para archivos grandes
  static List<Map<String, dynamic>> _parsearExcelEnIsolate(String filePath) {
    try {
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null || sheet.rows.isEmpty) {
        return [];
      }

      // Leer encabezados (primera fila)
      final headers = sheet.rows[0]
          .map((cell) => cell?.value?.toString().trim().toLowerCase() ?? '')
          .toList();
      
      // Log para debugging - mostrar headers encontrados
      if (kDebugMode) {
        debugPrint('Headers encontrados en Excel: ${headers.join(", ")}');
      }

      // Parsear todas las filas
      final datos = <Map<String, dynamic>>[];
      for (var i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        final rowMap = <String, dynamic>{};
        for (var j = 0; j < headers.length && j < row.length; j++) {
          final value = row[j]?.value;
          final headerKey = headers[j];
          if (headerKey.isNotEmpty) {
            rowMap[headerKey] = value?.toString().trim() ?? '';
          }
        }
        
        if (rowMap.isNotEmpty) {
          datos.add(rowMap);
          // Log para debugging - mostrar primera fila procesada
          if (datos.length == 1 && kDebugMode) {
            debugPrint('Primera fila procesada: ${rowMap.keys.join(", ")}');
            debugPrint('Valores primera fila: $rowMap');
          }
        }
      }
      
      return datos;
    } catch (e) {
      return [];
    }
  }

  /// Guarda un lote de habitantes de forma optimizada para archivos grandes
  /// Usa búsquedas en batch para mejorar rendimiento con 40,000+ registros
  static Future<void> _guardarLoteOptimizado(Isar isar, List<Habitante> lote) async {
    if (lote.isEmpty) return;
    
    try {
      // PASO 1: Eliminar duplicados DENTRO del lote (quedarse con el último registro)
      // Esto evita el error "Unique index violated" cuando el CSV tiene cédulas repetidas
      final loteUnico = <int, Habitante>{};
      for (var habitante in lote) {
        loteUnico[habitante.cedula] = habitante; // El último sobrescribe al anterior
      }
      final loteSinDuplicados = loteUnico.values.toList();
      
      // PASO 2: Buscar todos los habitantes existentes en BATCH
      // antes de la transacción, en lugar de una consulta por habitante
      final cedulas = loteSinDuplicados.map((h) => h.cedula).toList();
      final existentesList = await isar.habitantes.getAllByCedula(cedulas);
      
      // Crear mapa para acceso O(1) en lugar de O(n) con búsquedas repetidas
      final existentesMap = <int, Habitante>{};
      for (var existente in existentesList) {
        if (existente != null) {
          existentesMap[existente.cedula] = existente;
        }
      }
      
      // Separar en nuevos y existentes para procesamiento optimizado
      final nuevos = <Habitante>[];
      final actualizados = <Habitante>[];
      
      for (var habitante in loteSinDuplicados) {
        final existente = existentesMap[habitante.cedula];
        if (existente != null) {
          // Actualizar campos del existente
          existente.nombreCompleto = habitante.nombreCompleto;
          existente.nacionalidad = habitante.nacionalidad;
          existente.telefono = habitante.telefono;
          existente.genero = habitante.genero;
          existente.direccion = habitante.direccion;
          existente.estatusPolitico = habitante.estatusPolitico;
          existente.nivelVoto = habitante.nivelVoto;
          existente.fechaNacimiento = habitante.fechaNacimiento;
          existente.nivelUsuario = habitante.nivelUsuario;
          existente.isSynced = habitante.isSynced;
          existente.isDeleted = false;
          // No actualizar fotoUrl - preservar foto existente
          
          // Actualizar relaciones
          if (habitante.consejoComunal.value != null) {
            existente.consejoComunal.value = habitante.consejoComunal.value;
          }
          if (habitante.clap.value != null) {
            existente.clap.value = habitante.clap.value;
          }
          if (habitante.jefeDeFamilia.value != null) {
            existente.jefeDeFamilia.value = habitante.jefeDeFamilia.value;
          }
          
          actualizados.add(existente);
        } else {
          // Nuevo habitante
          habitante.isDeleted = false;
          habitante.fotoUrl = null; // Inicializar fotoUrl
          nuevos.add(habitante);
        }
      }
      
      // Guardar en una sola transacción optimizada
      await isar.writeTxn(() async {
        // Guardar todos los nuevos y actualizados con putAll (más eficiente)
        // IMPORTANTE: Los links se guardan automáticamente cuando haces put() del objeto principal
        // No necesitas llamar save() en los links dentro de una transacción activa
        final todosParaGuardar = <Habitante>[...nuevos, ...actualizados];
        if (todosParaGuardar.isNotEmpty) {
          // putAll guarda los objetos y sus links automáticamente
          await isar.habitantes.putAll(todosParaGuardar);
        }
      });
      
      // Log reducido - mostrar info del lote
      final duplicadosEnLote = lote.length - loteSinDuplicados.length;
      if (duplicadosEnLote > 0) {
        AppLogger.debug('Lote: ${loteSinDuplicados.length} habitantes (${nuevos.length} nuevos, ${actualizados.length} actualizados, $duplicadosEnLote duplicados ignorados)');
      } else if (lote.length == _batchSize || nuevos.isNotEmpty || actualizados.isNotEmpty) {
        AppLogger.debug('Lote: ${loteSinDuplicados.length} habitantes (${nuevos.length} nuevos, ${actualizados.length} actualizados)');
      }
    } catch (e) {
      // Log del error pero no lanzar excepción para no interrumpir el proceso completo
      AppLogger.error('Error al guardar lote de ${lote.length} habitantes', e);
      
      // Reintentar guardar uno por uno si falla el lote completo (fallback)
      int guardados = 0;
      int errores = 0;
      for (var habitante in lote) {
        try {
          await isar.writeTxn(() async {
            final existente = await isar.habitantes.getByCedula(habitante.cedula);
            if (existente != null) {
              // Actualizar existente
              existente.nombreCompleto = habitante.nombreCompleto;
              existente.nacionalidad = habitante.nacionalidad;
              existente.telefono = habitante.telefono;
              existente.genero = habitante.genero;
              existente.direccion = habitante.direccion;
              existente.estatusPolitico = habitante.estatusPolitico;
              existente.nivelVoto = habitante.nivelVoto;
              existente.fechaNacimiento = habitante.fechaNacimiento;
              existente.nivelUsuario = habitante.nivelUsuario;
              existente.isSynced = habitante.isSynced;
              existente.isDeleted = false;
              await isar.habitantes.put(existente);
            } else {
              habitante.isDeleted = false;
              habitante.fotoUrl = null;
              await isar.habitantes.put(habitante);
            }
          });
          guardados++;
        } catch (e2) {
          errores++;
          // Solo loguear errores múltiples o críticos
          if (errores <= 5) {
            AppLogger.warning('Error al guardar habitante cédula ${habitante.cedula}: $e2');
          }
        }
      }
      AppLogger.info('Reintento: $guardados/${lote.length} guardados, $errores errores');
    }
  }

  /// Procesa las relaciones de jefes de familia pendientes
  static Future<void> _procesarJefesPendientes(
    Isar isar,
    Map<int, List<Habitante>> cedulasJefesPendientes,
    Function(int progreso, int total, String etiqueta)? onProgress,
  ) async {
    final jefesMap = <int, Habitante>{};
    final cedulasFaltantes = cedulasJefesPendientes.keys.toList();
    
    if (cedulasFaltantes.isEmpty) return;
    
    // Buscar jefes en batch usando getAllByCedula
    final jefesList = await isar.habitantes.getAllByCedula(cedulasFaltantes);
    
    for (var jefe in jefesList) {
      if (jefe != null) {
        jefesMap[jefe.cedula] = jefe;
      }
    }
    
    final habitantesActualizar = <Habitante>[];
    for (var entry in cedulasJefesPendientes.entries) {
      final jefe = jefesMap[entry.key];
      if (jefe != null) {
        for (var h in entry.value) {
          h.jefeDeFamilia.value = jefe;
          habitantesActualizar.add(h);
        }
      }
    }
    
    if (habitantesActualizar.isNotEmpty) {
      final batchRel = AppConstants.batchSizeRelations;
      final totalRelaciones = habitantesActualizar.length;
      for (var i = 0; i < habitantesActualizar.length; i += batchRel) {
        final batch = habitantesActualizar.skip(i).take(batchRel).toList();
        await isar.writeTxn(() async {
          await isar.habitantes.putAll(batch);
          for (var h in batch) {
            if (h.jefeDeFamilia.value != null) {
              await h.jefeDeFamilia.save();
            }
          }
        });
        
        if (onProgress != null && i % (batchRel * 2) == 0) {
          onProgress(totalRelaciones, totalRelaciones, 'Actualizando relaciones: ${i + batch.length} de $totalRelaciones...');
        }
      }
    }
  }

  // Funciones auxiliares de parsing
  static String? _getValue(Map<String, dynamic> row, List<String> keys) {
    for (var key in keys) {
      // Los headers ya están en minúsculas, buscar con la key exacta
      final keyLower = key.toLowerCase().trim();
      var value = row[keyLower];
      
      // Si no se encuentra, buscar sin espacios
      if (value == null || value.toString().trim().isEmpty) {
        final keyNoSpaces = keyLower.replaceAll(' ', '');
        value = row[keyNoSpaces];
      }
      
      // Si aún no se encuentra, buscar en todas las keys del row (por si hay variaciones)
      if (value == null || value.toString().trim().isEmpty) {
        for (var rowKey in row.keys) {
          final rowKeyNormalized = rowKey.toLowerCase().trim().replaceAll(' ', '');
          final keyNormalized = keyLower.replaceAll(' ', '');
          if (rowKeyNormalized == keyNormalized || 
              rowKeyNormalized.contains(keyNormalized) ||
              keyNormalized.contains(rowKeyNormalized)) {
            value = row[rowKey];
            break;
          }
        }
      }
      
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }

  static Nacionalidad _parseNacionalidad(String? value) {
    if (value == null) return Nacionalidad.V;
    final normalized = value.trim().toUpperCase();
    if (normalized == 'E' || normalized == 'EXTRANJERO') {
      return Nacionalidad.E;
    }
    return Nacionalidad.V;
  }

  static Genero _parseGenero(String? value) {
    if (value == null) return Genero.Masculino;
    final normalized = value.trim().toUpperCase();
    if (normalized.contains('F') || normalized.contains('FEMENINO')) {
      return Genero.Femenino;
    }
    return Genero.Masculino;
  }

  static Parroquia _parseParroquia(String? value) {
    if (value == null || value.trim().isEmpty) return Parroquia.LaFria;
    final normalized = value.trim().toUpperCase().replaceAll(' ', '');
    if (normalized.contains('BOCA') || normalized.contains('GRITA')) {
      return Parroquia.BocaDeGrita;
    } else if (normalized.contains('JOSE') || normalized.contains('PAEZ') || normalized.contains('JOSÉ')) {
      return Parroquia.JoseAntonioPaez;
    } else if (normalized.contains('LAFRIA') || normalized.contains('LAFRIA') || normalized == 'LAFRIA') {
      return Parroquia.LaFria;
    }
    // Por defecto, si no se reconoce, retornar LaFria
    return Parroquia.LaFria;
  }

  static EstatusPolitico _parseEstatusPolitico(String? value) {
    if (value == null) return EstatusPolitico.Neutral;
    final normalized = value.trim().toUpperCase();
    if (normalized.contains('CHAVISTA') || normalized.contains('PSUV')) {
      return EstatusPolitico.Chavista;
    } else if (normalized.contains('OPOSITOR') && normalized.contains('SIMPATIZANTE')) {
      return EstatusPolitico.OpositorSimpatizante;
    } else if (normalized.contains('OPOSITOR') && normalized.contains('NACIONALISTA')) {
      return EstatusPolitico.OpositorNacionalista;
    } else if (normalized.contains('OPOSITOR')) {
      return EstatusPolitico.Opositor;
    }
    return EstatusPolitico.Neutral;
  }

  static NivelVoto _parseNivelVoto(String? value) {
    if (value == null) return NivelVoto.Blando;
    final normalized = value.trim().toUpperCase();
    if (normalized.contains('DURO')) {
      return NivelVoto.Duro;
    } else if (normalized.contains('OPOSITOR')) {
      return NivelVoto.Opositor;
    }
    return NivelVoto.Blando;
  }

  static DateTime? _parseFecha(String? value) {
    if (value == null || value.isEmpty) return null;
    
    try {
      // Si es un número (días desde 1900 - formato Excel)
      final numValue = double.tryParse(value);
      if (numValue != null && numValue > 0) {
        return AppConstants.excelBaseDate.add(Duration(days: numValue.toInt()));
      }

      // Intentar varios formatos de fecha
      for (var format in AppConstants.dateFormats) {
        try {
          final fecha = DateFormat(format).parse(value);
          // Validar que la fecha sea razonable (no futura, no muy antigua)
          final now = DateTime.now();
          if (fecha.isBefore(now) && fecha.isAfter(DateTime(1900))) {
            return fecha;
          }
        } catch (_) {}
      }
    } catch (_) {}
    
    return null;
  }

  static String _construirDireccion(Map<String, dynamic> row) {
    final partes = <String>[];
    bool tieneDireccion = false;
    
    final campos = [
      'estado',
      'municipio',
      'parroquia',
      'comuna',
      'consejo comunal',
      'consejocomunal',
      'comunidad',
      'calle',
      'numero casa',
      'numerocasa',
    ];
    
    for (var campo in campos) {
      final valor = _getValue(row, [campo]);
      if (valor != null && valor.isNotEmpty) {
        if (campo == 'parroquia') {
          final parroquia = _parseParroquia(valor);
          partes.add(parroquia.toString().split('.').last);
        } else if (campo == 'calle') {
          partes.add('Calle $valor');
        } else if (campo == 'numero casa' || campo == 'numerocasa') {
          partes.add('Casa $valor');
        } else {
          partes.add(valor);
        }
        tieneDireccion = true;
      }
    }
    
    return tieneDireccion ? partes.join(', ') : '';
  }
}

/// Resultado del procesamiento de carga masiva
class BulkUploadResult {
  int totalRows = 0;
  int successCount = 0;
  int errorCount = 0;
  List<String> errors = [];
  
  bool get tieneErrores => errorCount > 0;
  double get porcentajeExito => totalRows > 0 ? (successCount / totalRows) * 100 : 0;
}
