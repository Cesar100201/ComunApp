import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../control_seguimiento_model.dart';

const String _fileName = 'control_seguimiento.json';

/// Repositorio para registros de Control y Seguimiento.
/// Persiste en un archivo JSON local (evita el error de schema en Isar).
class ControlSeguimientoRepository {
  ControlSeguimientoRepository();

  Future<String> _getFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_fileName';
  }

  Future<List<ControlSeguimiento>> _readFile() async {
    final path = await _getFilePath();
    final file = File(path);
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.trim().isEmpty) return [];
    final list = jsonDecode(content) as List<dynamic>;
    return list
        .map((e) => ControlSeguimiento.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeFile(List<ControlSeguimiento> list) async {
    final path = await _getFilePath();
    final file = File(path);
    final jsonList = list.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  Future<List<ControlSeguimiento>> getAll() async {
    final list = await _readFile();
    list.sort((a, b) => b.fecha.compareTo(a.fecha));
    return list;
  }

  /// Devuelve registros cuya fecha está dentro del rango [inicio, fin] (solo fecha, sin hora).
  Future<List<ControlSeguimiento>> getByRangoFechas(DateTime inicio, DateTime fin) async {
    final list = await _readFile();
    final inicioNorm = DateTime(inicio.year, inicio.month, inicio.day);
    final finNorm = DateTime(fin.year, fin.month, fin.day);
    final filtered = list.where((r) {
      final rDate = DateTime(r.fecha.year, r.fecha.month, r.fecha.day);
      return !rDate.isBefore(inicioNorm) && !rDate.isAfter(finNorm);
    }).toList();
    filtered.sort((a, b) => b.fecha.compareTo(a.fecha));
    return filtered;
  }

  Future<void> save(ControlSeguimiento registro) async {
    final list = await _readFile();
    if (registro.id == 0) {
      final maxId = list.isEmpty ? 0 : list.map((e) => e.id).fold(0, (a, b) => a > b ? a : b);
      registro.id = maxId + 1;
      list.add(registro);
    } else {
      final idx = list.indexWhere((e) => e.id == registro.id);
      if (idx >= 0) {
        list[idx] = registro;
      } else {
        list.add(registro);
      }
    }
    await _writeFile(list);
  }

  Future<ControlSeguimiento?> getById(int id) async {
    final list = await _readFile();
    try {
      return list.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(int id) async {
    final list = await _readFile();
    list.removeWhere((e) => e.id == id);
    await _writeFile(list);
  }

  /// Fusiona los registros descargados de la nube con los locales (por id).
  /// Los remotos reemplazan a los locales cuando coinciden; los solo locales se mantienen.
  Future<void> mergeFromRemote(List<ControlSeguimiento> remotos) async {
    final locales = await _readFile();
    final porId = <int, ControlSeguimiento>{};
    for (final r in locales) {
      porId[r.id] = r;
    }
    for (final r in remotos) {
      porId[r.id] = r;
    }
    final fusionado = porId.values.toList();
    fusionado.sort((a, b) => b.fecha.compareTo(a.fecha));
    await _writeFile(fusionado);
  }
}
