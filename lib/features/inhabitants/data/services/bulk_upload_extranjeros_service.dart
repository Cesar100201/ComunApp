import 'dart:io';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:isar/isar.dart';
import 'package:flutter/foundation.dart';
import '../../../../models/models.dart';
import '../../../../database/db_helper.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/constants.dart';

class BulkUploadResult {
  int totalRows = 0;
  int successCount = 0;
  int errorCount = 0;
  List<String> errors = [];

  bool get tieneErrores => errorCount > 0;
  double get porcentajeExito =>
      totalRows > 0 ? (successCount / totalRows) * 100 : 0;
}

class BulkUploadExtranjerosService {
  static const int _batchSize = AppConstants.batchSize;

  static bool esArchivoCSV(String filePath) {
    return filePath.toLowerCase().endsWith('.csv');
  }

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
        datosParseados = await compute(_parsearCSVEnIsolate, filePath);
      } else {
        datosParseados = await compute(_parsearExcelEnIsolate, filePath);
      }

      if (datosParseados.isEmpty) {
        result.errors.add('El archivo está vacío o no tiene datos válidos');
        if (onProgress != null) onProgress(0, 100, 'Error: Archivo vacío');
        return result;
      }

      result.totalRows = datosParseados.length;

      if (onProgress != null) {
        final progressValue = (result.totalRows * 0.1).round();
        onProgress(
          progressValue,
          result.totalRows,
          'Leídos: ${result.totalRows} registros',
        );
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final isar = await DbHelper().db;
      final loteBuffer = <Extranjero>[];
      final reportInterval = datosParseados.length > 5000 ? 500 : 100;

      for (var i = 0; i < datosParseados.length; i++) {
        final rowMap = datosParseados[i];

        try {
          final cedulaColStr =
              (_getValue(rowMap, [
                        'cedula colombiana',
                        'cedulacolombiana',
                        'cc',
                      ]) ??
                      '')
                  .replaceAll(RegExp(r'[^\d]'), '');

          if (cedulaColStr.isEmpty) {
            result.errorCount++;
            result.errors.add('Fila ${i + 2}: Cédula Colombiana es requerida');
            continue;
          }

          final cedulaCol = int.tryParse(cedulaColStr);
          if (cedulaCol == null) {
            result.errorCount++;
            result.errors.add('Fila ${i + 2}: Cédula Colombiana inválida');
            continue;
          }

          final nombreCompleto =
              _getValue(rowMap, [
                'nombre completo',
                'nombrecompleto',
                'nombre',
              ]) ??
              '';
          if (nombreCompleto.isEmpty) {
            result.errorCount++;
            result.errors.add('Fila ${i + 2}: Nombre completo es requerido');
            continue;
          }

          final telefono =
              _getValue(rowMap, ['telefono', 'teléfono', 'tel']) ??
              'No especificado';
          final departamento =
              _getValue(rowMap, ['departamento', 'dpto']) ?? 'No especificado';
          final municipio =
              _getValue(rowMap, ['municipio', 'mcpio']) ?? 'No especificado';

          final esNacionalizadoStr =
              _getValue(rowMap, [
                'es nacionalizado',
                'esnacionalizado',
                'nacionalizado',
              ]) ??
              'NO';
          final esNac =
              esNacionalizadoStr.toUpperCase().startsWith('S') ||
              esNacionalizadoStr.toUpperCase().startsWith('V') ||
              esNacionalizadoStr.toUpperCase().startsWith('Y');

          int? cedulaVen;
          if (esNac) {
            final cvStr =
                (_getValue(rowMap, [
                          'cedula venezolana',
                          'cedulavenezolana',
                          'cv',
                        ]) ??
                        '')
                    .replaceAll(RegExp(r'[^\d]'), '');
            cedulaVen = int.tryParse(cvStr);
          }

          final sisbenValor = _getValue(rowMap, ['sisben', 'sisbén']);
          String? nivelSisbenFinal;
          if (sisbenValor != null &&
              sisbenValor.trim().isNotEmpty &&
              sisbenValor.toUpperCase() != 'NO' &&
              sisbenValor.toUpperCase() != 'FALSO') {
            nivelSisbenFinal = sisbenValor.trim().toUpperCase();
          }

          final extranjero = Extranjero()
            ..cedulaColombiana = cedulaCol
            ..nombreCompleto = nombreCompleto.toUpperCase()
            ..telefono = telefono
            ..direccion = _getValue(rowMap, ['direccion', 'dirección'])
            ..email = _getValue(rowMap, ['email', 'correo'])
            ..departamento = departamento.toUpperCase()
            ..municipio = municipio.toUpperCase()
            ..esNacionalizado = esNac
            ..cedulaVenezolana = cedulaVen
            ..nivelSisben = nivelSisbenFinal
            ..isSynced = false
            ..isDeleted = false;

          loteBuffer.add(extranjero);
          result.successCount++;

          if ((i + 1) % reportInterval == 0 || i == datosParseados.length - 1) {
            if (onProgress != null) {
              final progreso = 0.1 + (0.7 * ((i + 1) / datosParseados.length));
              onProgress(
                (result.totalRows * progreso).round(),
                result.totalRows,
                'Procesando: ${i + 1}/${datosParseados.length}',
              );
            }
            await Future.delayed(const Duration(milliseconds: 5));
          }

          if (loteBuffer.length >= _batchSize) {
            await _guardarLoteOptimizado(isar, loteBuffer);
            loteBuffer.clear();
          }
        } catch (e) {
          result.errorCount++;
          result.errors.add('Fila ${i + 2}: Error interno - $e');
        }
      }

      if (loteBuffer.isNotEmpty) {
        await _guardarLoteOptimizado(isar, loteBuffer);
      }

      if (onProgress != null) {
        onProgress(
          result.totalRows,
          result.totalRows,
          '¡Proceso completado exitosamente!',
        );
      }
    } catch (e) {
      result.errors.add('Error crítico al procesar archivo: $e');
    }

    return result;
  }

  static List<Map<String, dynamic>> _parsearCSVEnIsolate(String filePath) {
    try {
      final file = File(filePath);
      final contenido = file.readAsStringSync();

      final primeraLinea = contenido.split('\n').first;
      String delimitador = ',';
      if (primeraLinea.contains(';') && !primeraLinea.contains(','))
        delimitador = ';';
      else if (primeraLinea.contains('\t'))
        delimitador = '\t';

      final csvConverter = CsvToListConverter(
        fieldDelimiter: delimitador,
        shouldParseNumbers: false,
        allowInvalid: true,
        eol: '\n',
      );

      final rows = csvConverter.convert(contenido);
      if (rows.isEmpty) return [];

      final headers = rows[0]
          .map((c) => c?.toString().trim().toLowerCase() ?? '')
          .toList();
      final datos = <Map<String, dynamic>>[];

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty ||
            !row.any((c) => c != null && c.toString().trim().isNotEmpty))
          continue;

        final rowMap = <String, dynamic>{};
        for (var j = 0; j < headers.length && j < row.length; j++) {
          if (headers[j].isNotEmpty) {
            rowMap[headers[j]] = row[j]?.toString().trim() ?? '';
          }
        }
        if (rowMap.isNotEmpty) datos.add(rowMap);
      }
      return datos;
    } catch (e) {
      return [];
    }
  }

  static List<Map<String, dynamic>> _parsearExcelEnIsolate(String filePath) {
    try {
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first];

      if (sheet == null || sheet.rows.isEmpty) return [];

      final headers = sheet.rows[0]
          .map((c) => c?.value?.toString().trim().toLowerCase() ?? '')
          .toList();
      final datos = <Map<String, dynamic>>[];

      for (var i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        final rowMap = <String, dynamic>{};
        for (var j = 0; j < headers.length && j < row.length; j++) {
          if (headers[j].isNotEmpty) {
            rowMap[headers[j]] = row[j]?.value?.toString().trim() ?? '';
          }
        }
        if (rowMap.isNotEmpty) datos.add(rowMap);
      }
      return datos;
    } catch (e) {
      return [];
    }
  }

  static Future<void> _guardarLoteOptimizado(
    Isar isar,
    List<Extranjero> lote,
  ) async {
    if (lote.isEmpty) return;

    try {
      final loteUnico = <int, Extranjero>{};
      for (var e in lote) {
        loteUnico[e.cedulaColombiana] = e;
      }
      final loteSinDuplicados = loteUnico.values.toList();

      final cedulas = loteSinDuplicados.map((e) => e.cedulaColombiana).toList();
      final existentesList = await isar.extranjeros.getAllByCedulaColombiana(
        cedulas,
      );

      final existentesMap = <int, Extranjero>{};
      for (var ex in existentesList) {
        if (ex != null) existentesMap[ex.cedulaColombiana] = ex;
      }

      final nuevos = <Extranjero>[];
      final actualizados = <Extranjero>[];

      for (var ex in loteSinDuplicados) {
        final existente = existentesMap[ex.cedulaColombiana];
        if (existente != null) {
          existente.nombreCompleto = ex.nombreCompleto;
          existente.telefono = ex.telefono;
          existente.direccion = ex.direccion;
          existente.email = ex.email;
          existente.departamento = ex.departamento;
          existente.municipio = ex.municipio;
          existente.esNacionalizado = ex.esNacionalizado;
          existente.cedulaVenezolana = ex.cedulaVenezolana;
          existente.nivelSisben = ex.nivelSisben;
          existente.isSynced = ex.isSynced;
          existente.isDeleted = false;
          actualizados.add(existente);
        } else {
          nuevos.add(ex);
        }
      }

      await isar.writeTxn(() async {
        final todos = [...nuevos, ...actualizados];
        if (todos.isNotEmpty) await isar.extranjeros.putAll(todos);
      });
    } catch (e) {
      AppLogger.error('Error guardando lote de extranjeros', e);
      for (var ex in lote) {
        try {
          await isar.writeTxn(() async {
            final exBd = await isar.extranjeros.getByCedulaColombiana(
              ex.cedulaColombiana,
            );
            if (exBd != null) {
              exBd.nombreCompleto = ex.nombreCompleto;
              exBd.telefono = ex.telefono;
              exBd.direccion = ex.direccion;
              exBd.email = ex.email;
              exBd.departamento = ex.departamento;
              exBd.municipio = ex.municipio;
              exBd.esNacionalizado = ex.esNacionalizado;
              exBd.cedulaVenezolana = ex.cedulaVenezolana;
              exBd.nivelSisben = ex.nivelSisben;
              exBd.isSynced = ex.isSynced;
              exBd.isDeleted = false;
              await isar.extranjeros.put(exBd);
            } else {
              await isar.extranjeros.put(ex);
            }
          });
        } catch (_) {}
      }
    }
  }

  static String? _getValue(Map<String, dynamic> row, List<String> keys) {
    for (var key in keys) {
      final keyLower = key.toLowerCase().trim();
      var value = row[keyLower];
      if (value == null || value.toString().trim().isEmpty) {
        value = row[keyLower.replaceAll(' ', '')];
      }
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }
}
