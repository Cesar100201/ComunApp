import 'dart:io';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:isar/isar.dart';
import 'package:flutter/foundation.dart';
import '../../../../models/models.dart';
import '../../../../database/db_helper.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/constants.dart';

/// Servicio optimizado para carga masiva de solicitudes desde Excel/CSV.
/// 
/// CSV es 10-50x más rápido que Excel para archivos grandes.
/// Usa isolates para parsear sin bloquear el hilo principal.
/// Procesa registros en lotes para mejor rendimiento con archivos grandes.
class BulkUploadSolicitudesService {
  static const int _batchSize = AppConstants.batchSize;
  
  /// Detecta si el archivo es CSV basado en la extensión
  static bool esArchivoCSV(String filePath) {
    return filePath.toLowerCase().endsWith('.csv');
  }
  
  /// Procesa un archivo Excel/CSV parseando en isolate y guardando en hilo principal
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
        AppLogger.info('Iniciando parseo de CSV en isolate (optimizado)...');
        datosParseados = await compute(_parsearCSVEnIsolate, filePath);
      } else {
        AppLogger.info('Iniciando parseo de Excel en isolate...');
        datosParseados = await compute(_parsearExcelEnIsolate, filePath);
      }
      AppLogger.info('Total de filas parseadas: ${datosParseados.length}');
      
      if (datosParseados.isEmpty) {
        result.errors.add('El archivo está vacío o no tiene datos');
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
      final comunasMap = <String, Comuna>{};
      final consejosMap = <String, ConsejoComunal>{};
      final ubchsMap = <String, Organizacion>{};
      final creadoresMap = <int, Habitante>{};
      
      final comunas = await isar.comunas.where().findAll();
      final consejosComunales = await isar.consejoComunals.where().findAll();
      final ubchs = await isar.organizacions.filter().tipoEqualTo(TipoOrganizacion.Politico).findAll();
      final habitantes = await isar.habitantes.where().findAll();
      
      AppLogger.debug('Comunas cargadas: ${comunas.length}');
      AppLogger.debug('Consejos comunales cargados: ${consejosComunales.length}');
      AppLogger.debug('UBCHs cargados: ${ubchs.length}');
      AppLogger.debug('Habitantes cargados: ${habitantes.length}');
      
      for (var comuna in comunas) {
        comunasMap[comuna.nombreComuna.toLowerCase()] = comuna;
      }
      for (var cc in consejosComunales) {
        consejosMap[cc.nombreConsejo.toLowerCase()] = cc;
      }
      for (var ubch in ubchs) {
        ubchsMap[ubch.nombreLargo.toLowerCase()] = ubch;
      }
      for (var habitante in habitantes) {
        creadoresMap[habitante.cedula] = habitante;
      }

      // Notificar inicio del procesamiento
      if (onProgress != null) {
        final progressValue = (result.totalRows * AppConstants.progressPercentageProcessingStart).round();
        onProgress(progressValue, result.totalRows, 'Iniciando procesamiento de ${result.totalRows} registros...');
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Procesar y guardar en lotes
      AppLogger.info('Iniciando procesamiento de ${datosParseados.length} registros...');
      final loteBuffer = <Solicitud>[];
      final int reportInterval = datosParseados.length > AppConstants.largeFileThreshold 
          ? AppConstants.progressReportIntervalLarge 
          : AppConstants.progressReportIntervalSmall;
      
      AppLogger.debug('Entrando al bucle principal...');
      for (var i = 0; i < datosParseados.length; i++) {
        final rowMap = datosParseados[i];
        
        try {
          // Validaciones básicas
          final comunaNombre = _getValue(rowMap, ['comuna', 'nombre comuna'])?.toLowerCase() ?? '';
          if (comunaNombre.isEmpty) {
            result.errorCount++;
            result.errors.add('Fila ${i + 2}: Comuna es requerida');
            continue;
          }

          final comuna = comunasMap[comunaNombre];
          if (comuna == null) {
            result.errorCount++;
            result.errors.add('Fila ${i + 2}: Comuna "$comunaNombre" no encontrada');
            continue;
          }

          final comunidad = _getValue(rowMap, ['comunidad', 'comunidad nombre']) ?? '';
          if (comunidad.isEmpty) {
            result.errorCount++;
            result.errors.add('Fila ${i + 2}: Comunidad es requerida');
            continue;
          }

          // Cédula del creador (opcional)
          final cedulaCreadorStr = (_getValue(rowMap, ['cedula creador', 'cedulacreador', 'creador cedula', 'creadorcedula']) ?? '')
              .replaceAll(RegExp(r'[^\d]'), '');
          
          Habitante? creador;
          if (cedulaCreadorStr.isNotEmpty) {
            final cedulaCreador = int.tryParse(cedulaCreadorStr);
            if (cedulaCreador != null) {
              creador = creadoresMap[cedulaCreador];
              if (creador == null) {
                // Solo advertir, no bloquear el proceso
                result.errors.add('Fila ${i + 2}: Creador con cédula $cedulaCreador no encontrado (se creará sin creador)');
              }
            }
          }

          // Crear solicitud
          final solicitud = Solicitud();
          solicitud.idSolicitud = 0; // Se asignará automáticamente
          solicitud.comuna.value = comuna;
          solicitud.comunidad = comunidad;
          solicitud.descripcion = _getValue(rowMap, ['descripcion', 'descripción']) ?? '';
          solicitud.tipoSolicitud = _parseTipoSolicitud(_getValue(rowMap, ['tipo solicitud', 'tiposolicitud', 'tipo']));
          solicitud.otrosTipoSolicitud = _getValue(rowMap, ['otros tipo solicitud', 'otrostiposolicitud']);
          solicitud.isSynced = false;
          solicitud.isDeleted = false;
          
          if (creador != null) {
            solicitud.creador.value = creador;
          }

          // Consejo Comunal (opcional)
          final consejoNombre = _getValue(rowMap, ['consejo comunal', 'consejocomunal', 'consejo'])?.toLowerCase();
          if (consejoNombre != null && consejoNombre.isNotEmpty) {
            final consejo = consejosMap[consejoNombre];
            if (consejo != null) {
              solicitud.consejoComunal.value = consejo;
            }
          }

          // UBCH (opcional)
          final ubchNombre = _getValue(rowMap, ['ubch', 'organizacion', 'organización'])?.toLowerCase();
          if (ubchNombre != null && ubchNombre.isNotEmpty) {
            final ubch = ubchsMap[ubchNombre];
            if (ubch != null) {
              solicitud.ubch.value = ubch;
            }
          }

          // Cantidad de lámparas y bombillos (solo para tipo Iluminacion)
          if (solicitud.tipoSolicitud == TipoSolicitud.Iluminacion) {
            final lamparasStr = _getValue(rowMap, ['cantidad lamparas', 'cantidadlamparas', 'lamparas']);
            final bombillosStr = _getValue(rowMap, ['cantidad bombillos', 'cantidadbombillos', 'bombillos']);
            
            solicitud.cantidadLamparas = lamparasStr != null && lamparasStr.isNotEmpty 
                ? int.tryParse(lamparasStr) 
                : null;
            solicitud.cantidadBombillos = bombillosStr != null && bombillosStr.isNotEmpty 
                ? int.tryParse(bombillosStr) 
                : null;
          }

          loteBuffer.add(solicitud);
          result.successCount++;

          // Reportar progreso durante procesamiento
          if ((i + 1) % reportInterval == 0 || i == datosParseados.length - 1) {
            if (onProgress != null) {
              final progresoProcesamiento = (i + 1) / datosParseados.length;
              final progresoReal = (result.totalRows * AppConstants.progressPercentageProcessingStart + 
                  result.totalRows * (AppConstants.progressPercentageProcessingEnd - AppConstants.progressPercentageProcessingStart) * progresoProcesamiento).round();
              onProgress(
                progresoReal, 
                result.totalRows, 
                'Procesando: ${i + 1}/${datosParseados.length} (${result.successCount} válidos, ${result.errorCount} errores)'
              );
            }
            if (datosParseados.length > AppConstants.largeFileThreshold) {
              await Future.delayed(const Duration(milliseconds: 1));
            } else {
              await Future.delayed(const Duration(milliseconds: 5));
            }
          }

          // Guardar en lotes grandes
          if (loteBuffer.length >= _batchSize) {
            if (onProgress != null) {
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
            
            if (datosParseados.length > AppConstants.largeFileThreshold) {
              // No hacer delay para archivos grandes
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
  static List<Map<String, dynamic>> _parsearCSVEnIsolate(String filePath) {
    try {
      final file = File(filePath);
      final contenido = file.readAsStringSync();
      
      // Detectar delimitador
      final primeraLinea = contenido.split('\n').first;
      String delimitador = ',';
      if (primeraLinea.contains(';') && !primeraLinea.contains(',')) {
        delimitador = ';';
      } else if (primeraLinea.contains('\t') && !primeraLinea.contains(',') && !primeraLinea.contains(';')) {
        delimitador = '\t';
      }
      
      final csvConverter = CsvToListConverter(
        fieldDelimiter: delimitador,
        shouldParseNumbers: false,
        allowInvalid: true,
        eol: '\n',
      );
      
      final rows = csvConverter.convert(contenido);
      
      if (rows.isEmpty) {
        return [];
      }
      
      final headers = rows[0]
          .map((cell) => cell?.toString().trim().toLowerCase() ?? '')
          .toList();
      
      if (kDebugMode) {
        debugPrint('Headers encontrados en CSV: ${headers.join(", ")}');
      }
      
      final datos = <Map<String, dynamic>>[];
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;
        
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
        }
      }
      
      return datos;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error parseando CSV: $e');
      }
      return [];
    }
  }

  /// Parsea el Excel en un isolate
  static List<Map<String, dynamic>> _parsearExcelEnIsolate(String filePath) {
    try {
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null || sheet.rows.isEmpty) {
        return [];
      }

      final headers = sheet.rows[0]
          .map((cell) => cell?.value?.toString().trim().toLowerCase() ?? '')
          .toList();
      
      if (kDebugMode) {
        debugPrint('Headers encontrados en Excel: ${headers.join(", ")}');
      }

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
        }
      }
      
      return datos;
    } catch (e) {
      return [];
    }
  }

  /// Guarda un lote de solicitudes de forma optimizada
  static Future<void> _guardarLoteOptimizado(Isar isar, List<Solicitud> lote) async {
    if (lote.isEmpty) return;
    
    try {
      await isar.writeTxn(() async {
        for (var solicitud in lote) {
          await isar.solicituds.put(solicitud);
          if (solicitud.comuna.value != null) await solicitud.comuna.save();
          if (solicitud.consejoComunal.value != null) await solicitud.consejoComunal.save();
          if (solicitud.ubch.value != null) await solicitud.ubch.save();
          if (solicitud.creador.value != null) await solicitud.creador.save();
        }
      });
      
      AppLogger.debug('Lote: ${lote.length} solicitudes guardadas');
    } catch (e) {
      AppLogger.error('Error al guardar lote de ${lote.length} solicitudes', e);
      
      // Reintentar guardar uno por uno si falla el lote completo
      for (var solicitud in lote) {
        try {
          await isar.writeTxn(() async {
            await isar.solicituds.put(solicitud);
            if (solicitud.comuna.value != null) await solicitud.comuna.save();
            if (solicitud.consejoComunal.value != null) await solicitud.consejoComunal.save();
            if (solicitud.ubch.value != null) await solicitud.ubch.save();
            if (solicitud.creador.value != null) await solicitud.creador.save();
          });
        } catch (e2) {
          AppLogger.warning('Error al guardar solicitud: $e2');
        }
      }
    }
  }

  // Funciones auxiliares de parsing
  static String? _getValue(Map<String, dynamic> row, List<String> keys) {
    for (var key in keys) {
      final keyLower = key.toLowerCase().trim();
      var value = row[keyLower];
      
      if (value == null || value.toString().trim().isEmpty) {
        final keyNoSpaces = keyLower.replaceAll(' ', '');
        value = row[keyNoSpaces];
      }
      
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

  static TipoSolicitud _parseTipoSolicitud(String? value) {
    if (value == null) return TipoSolicitud.Iluminacion;
    final normalized = value.trim().toUpperCase();
    if (normalized.contains('AGUA') || normalized.contains('WATER')) {
      return TipoSolicitud.Agua;
    } else if (normalized.contains('ELECTRICO') || normalized.contains('ELECTRIC')) {
      return TipoSolicitud.Electrico;
    } else if (normalized.contains('ILUMINACION') || normalized.contains('ILUMINACIÓN') || normalized.contains('LIGHT')) {
      return TipoSolicitud.Iluminacion;
    }
    return TipoSolicitud.Otros;
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
