import 'dart:io';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:isar/isar.dart';
import 'package:flutter/foundation.dart';
import '../../../../models/models.dart';
import '../../../../database/db_helper.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/constants.dart';

/// Servicio optimizado para carga masiva de comunas desde Excel/CSV.
///
/// CSV es 10-50x más rápido que Excel para archivos grandes.
/// Usa isolates para parsear sin bloquear el hilo principal.
/// Procesa registros en lotes para mejor rendimiento con archivos grandes.
class BulkUploadComunasService {
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
      if (onProgress != null) {
        final tipoArchivo = esCSV ? 'CSV' : 'Excel';
        onProgress(0, 100, 'Leyendo archivo $tipoArchivo...');
      }

      List<Map<String, dynamic>> datosParseados;
      if (esCSV) {
        AppLogger.info('Iniciando parseo de CSV en isolate (comunas)...');
        datosParseados = await compute(_parsearCSVEnIsolate, filePath);
      } else {
        AppLogger.info('Iniciando parseo de Excel en isolate (comunas)...');
        datosParseados = await compute(_parsearExcelEnIsolate, filePath);
      }
      AppLogger.info('Total de filas parseadas (comunas): ${datosParseados.length}');

      if (datosParseados.isEmpty) {
        result.errors.add('El archivo está vacío o no tiene datos');
        if (onProgress != null) {
          onProgress(0, 100, 'Error: Archivo vacío');
        }
        return result;
      }

      result.totalRows = datosParseados.length;

      if (onProgress != null) {
        final progressValue = (result.totalRows * AppConstants.progressPercentageFileRead).round();
        onProgress(progressValue, result.totalRows, 'Archivo leído: ${result.totalRows} registros encontrados');
        await Future.delayed(const Duration(milliseconds: 100));
        onProgress(progressValue, result.totalRows, 'Conectando a base de datos...');
      }

      final isar = await DbHelper().db;

      if (onProgress != null) {
        final progressValue = (result.totalRows * AppConstants.progressPercentageProcessingStart).round();
        onProgress(progressValue, result.totalRows, 'Iniciando procesamiento de ${result.totalRows} registros...');
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final loteBuffer = <Comuna>[];
      final int reportInterval = datosParseados.length > AppConstants.largeFileThreshold
          ? AppConstants.progressReportIntervalLarge
          : AppConstants.progressReportIntervalSmall;

      for (var i = 0; i < datosParseados.length; i++) {
        final rowMap = datosParseados[i];

        try {
          final codigoSitur = (_getValue(rowMap, ['codigo situr', 'codigositur', 'situr', 'codigo']) ?? '').trim();
          if (codigoSitur.isEmpty) {
            result.errorCount++;
            result.errors.add('Fila ${i + 2}: Código SITUR es requerido');
            continue;
          }

          final codigoComElectoral = (_getValue(rowMap, [
                'codigo comunal electoral',
                'codigocomunalelectoral',
                'codigo comunal',
                'codigocomunal'
              ]) ??
              '')
              .trim();
          if (codigoComElectoral.isEmpty) {
            result.errorCount++;
            result.errors.add('Fila ${i + 2}: Código Comunal Electoral es requerido');
            continue;
          }

          final nombreComuna = (_getValue(rowMap, ['nombre comuna', 'nombrecomuna', 'comuna']) ?? '').trim();
          if (nombreComuna.isEmpty) {
            result.errorCount++;
            result.errors.add('Fila ${i + 2}: Nombre de la comuna es requerido');
            continue;
          }

          final rif = (_getValue(rowMap, ['rif']) ?? '').trim();
          final municipio = (_getValue(rowMap, ['municipio']) ?? '').trim();
          final parroquiaValue = _getValue(rowMap, ['parroquia', 'parish']);
          final parroquia = _parseParroquia(parroquiaValue);

          final latitudValue = _getValue(rowMap, ['latitud', 'latitude', 'lat']);
          final longitudValue = _getValue(rowMap, ['longitud', 'longitude', 'lng', 'long']);
          final latLong = _parseLatLong(latitudValue, longitudValue);
          if (latLong == null) {
            result.errorCount++;
            result.errors.add('Fila ${i + 2}: Latitud y longitud inválidas');
            continue;
          }

          final comuna = Comuna()
            ..codigoSitur = codigoSitur
            ..rif = rif.isEmpty ? null : rif
            ..codigoComElectoral = codigoComElectoral
            ..nombreComuna = nombreComuna
            ..municipio = municipio.isEmpty ? AppConstants.defaultMunicipality : municipio
            ..parroquia = parroquia
            ..latitud = latLong.item1
            ..longitud = latLong.item2
            ..isSynced = false
            ..isDeleted = false;

          loteBuffer.add(comuna);
          result.successCount++;

          if ((i + 1) % reportInterval == 0 || i == datosParseados.length - 1) {
            if (onProgress != null) {
              final progresoProcesamiento = (i + 1) / datosParseados.length;
              final progresoReal = (result.totalRows * AppConstants.progressPercentageProcessingStart +
                      result.totalRows *
                          (AppConstants.progressPercentageProcessingEnd -
                              AppConstants.progressPercentageProcessingStart) *
                          progresoProcesamiento)
                  .round();
              onProgress(
                progresoReal,
                result.totalRows,
                'Procesando: ${i + 1}/${datosParseados.length} (${result.successCount} válidos, ${result.errorCount} errores)',
              );
            }
            if (datosParseados.length > AppConstants.largeFileThreshold) {
              await Future.delayed(const Duration(milliseconds: 1));
            } else {
              await Future.delayed(const Duration(milliseconds: 5));
            }
          }

          if (loteBuffer.length >= _batchSize) {
            if (onProgress != null) {
              final progresoGuardado = AppConstants.progressPercentageSaving +
                  (AppConstants.progressPercentageSavingEnd - AppConstants.progressPercentageSaving) *
                      (i + 1) /
                      datosParseados.length;
              final progresoReal = (result.totalRows * progresoGuardado).round();
              onProgress(
                progresoReal,
                result.totalRows,
                'Guardando lote en base de datos (${loteBuffer.length} registros)...',
              );
            }
            await _guardarLoteOptimizado(isar, loteBuffer);
            loteBuffer.clear();
          }
        } catch (e, stackTrace) {
          result.errorCount++;
          result.errors.add('Fila ${i + 2}: Error - $e');
          AppLogger.error('Error en fila ${i + 2} (comunas)', e, stackTrace);
        }
      }

      if (loteBuffer.isNotEmpty) {
        if (onProgress != null) {
          final progresoReal = (result.totalRows * AppConstants.progressPercentageSavingEnd).round();
          onProgress(progresoReal, result.totalRows, 'Guardando lote final en base de datos...');
        }
        await _guardarLoteOptimizado(isar, loteBuffer);
      }

      if (onProgress != null) {
        onProgress(result.totalRows, result.totalRows, '¡Proceso completado exitosamente!');
      }
    } catch (e, stackTrace) {
      AppLogger.error('ERROR CRÍTICO en procesarExcelEnSegundoPlano (comunas)', e, stackTrace);
      result.errors.add('Error al procesar archivo: $e');
      if (onProgress != null) {
        onProgress(0, result.totalRows, 'Error en el procesamiento');
      }
    }

    return result;
  }

  static List<Map<String, dynamic>> _parsearCSVEnIsolate(String filePath) {
    try {
      final file = File(filePath);
      final contenido = file.readAsStringSync();

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

      final headers = rows[0].map((cell) => cell?.toString().trim().toLowerCase() ?? '').toList();
      if (kDebugMode) {
        debugPrint('Headers encontrados en CSV (comunas): ${headers.join(", ")}');
      }

      final datos = <Map<String, dynamic>>[];
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        final tieneContenido = row.any((cell) => cell != null && cell.toString().trim().isNotEmpty);
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
    } catch (_) {
      return [];
    }
  }

  static List<Map<String, dynamic>> _parsearExcelEnIsolate(String filePath) {
    try {
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null || sheet.rows.isEmpty) {
        return [];
      }

      final headers = sheet.rows[0].map((cell) => cell?.value?.toString().trim().toLowerCase() ?? '').toList();
      if (kDebugMode) {
        debugPrint('Headers encontrados en Excel (comunas): ${headers.join(", ")}');
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
    } catch (_) {
      return [];
    }
  }

  static Future<void> _guardarLoteOptimizado(Isar isar, List<Comuna> lote) async {
    if (lote.isEmpty) return;

    try {
      final loteUnico = <String, Comuna>{};
      for (var comuna in lote) {
        loteUnico[comuna.codigoSitur] = comuna;
      }
      final loteSinDuplicados = loteUnico.values.toList();

      final codigos = loteSinDuplicados.map((c) => c.codigoSitur).toList();
      final existentesList = await isar.comunas.getAllByCodigoSitur(codigos);

      final existentesMap = <String, Comuna>{};
      for (var existente in existentesList) {
        if (existente != null) {
          existentesMap[existente.codigoSitur] = existente;
        }
      }

      final nuevos = <Comuna>[];
      final actualizados = <Comuna>[];
      for (var comuna in loteSinDuplicados) {
        final existente = existentesMap[comuna.codigoSitur];
        if (existente != null) {
          existente.rif = comuna.rif;
          existente.codigoComElectoral = comuna.codigoComElectoral;
          existente.nombreComuna = comuna.nombreComuna;
          existente.municipio = comuna.municipio;
          existente.parroquia = comuna.parroquia;
          existente.latitud = comuna.latitud;
          existente.longitud = comuna.longitud;
          existente.isSynced = false;
          existente.isDeleted = false;
          actualizados.add(existente);
        } else {
          comuna.isDeleted = false;
          comuna.isSynced = false;
          nuevos.add(comuna);
        }
      }

      await isar.writeTxn(() async {
        final todosParaGuardar = <Comuna>[...nuevos, ...actualizados];
        if (todosParaGuardar.isNotEmpty) {
          await isar.comunas.putAll(todosParaGuardar);
        }
      });
    } catch (e) {
      AppLogger.error('Error al guardar lote de ${lote.length} comunas', e);
      for (var comuna in lote) {
        try {
          await isar.writeTxn(() async {
            final existente = await isar.comunas.getByCodigoSitur(comuna.codigoSitur);
            if (existente != null) {
              existente.rif = comuna.rif;
              existente.codigoComElectoral = comuna.codigoComElectoral;
              existente.nombreComuna = comuna.nombreComuna;
              existente.municipio = comuna.municipio;
              existente.parroquia = comuna.parroquia;
              existente.latitud = comuna.latitud;
              existente.longitud = comuna.longitud;
              existente.isSynced = false;
              existente.isDeleted = false;
              await isar.comunas.put(existente);
            } else {
              comuna.isDeleted = false;
              comuna.isSynced = false;
              await isar.comunas.put(comuna);
            }
          });
        } catch (e2) {
          AppLogger.warning('Error al guardar comuna ${comuna.codigoSitur}: $e2');
        }
      }
    }
  }

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

  static Parroquia _parseParroquia(String? value) {
    if (value == null || value.trim().isEmpty) return Parroquia.LaFria;
    final normalized = value.trim().toUpperCase().replaceAll(' ', '');
    if (normalized.contains('BOCA') || normalized.contains('GRITA')) {
      return Parroquia.BocaDeGrita;
    } else if (normalized.contains('JOSE') || normalized.contains('PAEZ') || normalized.contains('JOSÉ')) {
      return Parroquia.JoseAntonioPaez;
    } else if (normalized.contains('LAFRIA') || normalized == 'LAFRIA') {
      return Parroquia.LaFria;
    }
    return Parroquia.LaFria;
  }

  static ({double item1, double item2})? _parseLatLong(String? lat, String? lng) {
    final latTrim = lat?.trim() ?? '';
    final lngTrim = lng?.trim() ?? '';
    if (latTrim.isEmpty && lngTrim.isEmpty) {
      return (item1: 0.0, item2: 0.0);
    }
    if (latTrim.isEmpty || lngTrim.isEmpty) {
      return null;
    }
    final latValue = double.tryParse(latTrim.replaceAll(',', '.'));
    final lngValue = double.tryParse(lngTrim.replaceAll(',', '.'));
    if (latValue == null || lngValue == null) {
      return null;
    }
    return (item1: latValue, item2: lngValue);
  }
}

class BulkUploadResult {
  int totalRows = 0;
  int successCount = 0;
  int errorCount = 0;
  List<String> errors = [];

  bool get tieneErrores => errorCount > 0;
  double get porcentajeExito => totalRows > 0 ? (successCount / totalRows) * 100 : 0;
}
