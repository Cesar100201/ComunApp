import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/utils/logger.dart';
import 'control_seguimiento_model.dart';
import 'medios_verificacion_service.dart';

/// Sube y descarga fotos y documentos de Control y Seguimiento desde/hacia Firebase Storage.
/// Las rutas en Storage usan siempre "/" (normalizado); localmente se respeta el separador del SO.
class ControlSeguimientoMediaSyncService {
  ControlSeguimientoMediaSyncService();

  final MediosVerificacionService _mediosService = MediosVerificacionService();

  /// Ruta para Firebase Storage: siempre barras normales.
  static String _storagePath(String relativePath) =>
      relativePath.replaceAll(r'\', '/');

  /// Recoge todas las rutas relativas de medios de un registro.
  static List<String> _allMediaPaths(ControlSeguimiento r) {
    final paths = <String>[];
    paths.addAll(r.memoriaFotografica);
    paths.addAll(r.listasAsistenciaFotos);
    paths.addAll(r.listasAsistenciaPdfs);
    paths.addAll(r.actasPdfs);
    return paths;
  }

  /// Sube a Firebase Storage los archivos locales de los registros que aún no estén en la nube.
  /// Devuelve la cantidad de archivos subidos.
  Future<int> uploadMediaForRegistros(List<ControlSeguimiento> registros) async {
    int count = 0;
    final storage = FirebaseStorage.instance.ref();

    for (final r in registros) {
      for (final relativePath in _allMediaPaths(r)) {
        if (relativePath.isEmpty) continue;
        try {
          final localPath = await _mediosService.resolvePath(relativePath);
          final file = File(localPath);
          if (!await file.exists()) continue;

          final ref = storage.child(_storagePath(relativePath));
          await ref.putFile(file);
          count++;
        } catch (e) {
          AppLogger.warning('Error subiendo medio $relativePath: $e');
          continue;
        }
      }
    }
    return count;
  }

  /// Descarga desde Firebase Storage los archivos que falten en local para los registros dados.
  /// Devuelve la cantidad de archivos descargados.
  Future<int> downloadMediaForRegistros(List<ControlSeguimiento> registros) async {
    int count = 0;
    final storage = FirebaseStorage.instance.ref();

    for (final r in registros) {
      for (final relativePath in _allMediaPaths(r)) {
        if (relativePath.isEmpty) continue;
        try {
          final localPath = await _mediosService.resolvePath(relativePath);
          final file = File(localPath);
          if (await file.exists()) continue;

          final ref = storage.child(_storagePath(relativePath));
          final data = await ref.getData();
          if (data == null || data.isEmpty) {
            AppLogger.warning('Medio vacío o no encontrado en Storage: $relativePath');
            continue;
          }

          await _mediosService.saveFileFromBytes(relativePath, data);
          count++;
        } catch (e) {
          AppLogger.warning('Error descargando medio $relativePath: $e');
          continue;
        }
      }
    }
    return count;
  }
}
