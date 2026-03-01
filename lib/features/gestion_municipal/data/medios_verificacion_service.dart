import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Tamaño máximo por foto antes de comprimir: 100 MB.
const int _maxPhotoBytes = 100 * 1024 * 1024;

/// Tamaño objetivo tras compresión: 40 MB.
const int _targetPhotoBytes = 40 * 1024 * 1024;

const String _mediosSubdir = 'control_seguimiento_medios';

/// Categorías de medios de verificación: memoria fotográfica (solo fotos), listas de asistencia (fotos+pdf), actas (solo pdf).
enum CategoriaMedio {
  memoriaFotografica,
  listasAsistencia,
  actas,
}

/// Servicio para guardar y resolver rutas de fotos y PDFs de medios de verificación.
class MediosVerificacionService {
  MediosVerificacionService();

  Future<String> _getBasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  String _subdirFotos(int registroId, CategoriaMedio cat) {
    switch (cat) {
      case CategoriaMedio.memoriaFotografica:
        return p.join(_mediosSubdir, registroId.toString(), 'memoria_fotografica');
      case CategoriaMedio.listasAsistencia:
        return p.join(_mediosSubdir, registroId.toString(), 'listas_asistencia', 'fotos');
      case CategoriaMedio.actas:
        throw ArgumentError('Actas solo permite PDF');
    }
  }

  String _subdirPdfs(int registroId, CategoriaMedio cat) {
    switch (cat) {
      case CategoriaMedio.memoriaFotografica:
        throw ArgumentError('Memoria fotográfica solo permite fotos');
      case CategoriaMedio.listasAsistencia:
        return p.join(_mediosSubdir, registroId.toString(), 'listas_asistencia', 'pdfs');
      case CategoriaMedio.actas:
        return p.join(_mediosSubdir, registroId.toString(), 'actas');
    }
  }

  /// Ruta absoluta de la carpeta de fotos para el registro y categoría (compatibilidad: fotos genéricos).
  Future<String> getFotosDirPath(int registroId, [CategoriaMedio? category]) async {
    final cat = category ?? CategoriaMedio.memoriaFotografica;
    final base = await _getBasePath();
    final dir = Directory(p.join(base, _subdirFotos(registroId, cat)));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// Ruta absoluta de la carpeta de PDFs para el registro y categoría (compatibilidad: pdfs genéricos).
  Future<String> getPdfsDirPath(int registroId, [CategoriaMedio? category]) async {
    final cat = category ?? CategoriaMedio.listasAsistencia;
    final base = await _getBasePath();
    final dir = Directory(p.join(base, _subdirPdfs(registroId, cat)));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// Convierte ruta relativa (guardada en el modelo) a ruta absoluta.
  /// Acepta rutas con "/" o "\\" y las normaliza al separador del sistema.
  Future<String> resolvePath(String relativePath) async {
    final base = await _getBasePath();
    final segments = relativePath.replaceAll(r'\', '/').split('/');
    var path = base;
    for (final seg in segments) {
      if (seg.isEmpty) continue;
      path = p.join(path, seg);
    }
    return path;
  }

  /// Guarda bytes en la ruta local correspondiente a [relativePath] (para descarga desde nube).
  /// Acepta rutas con "/" o "\\" y las normaliza al separador del sistema.
  Future<void> saveFileFromBytes(String relativePath, List<int> bytes) async {
    if (relativePath.isEmpty) return;
    final base = await _getBasePath();
    final segments = relativePath.replaceAll(r'\', '/').split('/');
    var fullPath = base;
    for (final seg in segments) {
      if (seg.isEmpty) continue;
      fullPath = p.join(fullPath, seg);
    }
    final file = File(fullPath);
    if (await file.exists()) return;
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  /// Guarda una foto: valida <= 100 MB, comprime a ~40 MB y guarda. Devuelve ruta relativa.
  /// [sourcePath] ruta del archivo original. [category] memoriaFotografica o listasAsistencia.
  Future<String> savePhoto(int registroId, String sourcePath, {CategoriaMedio category = CategoriaMedio.memoriaFotografica}) async {
    final file = File(sourcePath);
    if (!await file.exists()) throw Exception('Archivo no encontrado');
    final length = await file.length();
    if (length > _maxPhotoBytes) {
      throw Exception('La foto no puede superar 100 MB. Tamaño actual: ${(length / (1024 * 1024)).toStringAsFixed(1)} MB');
    }

    final fotosDir = await getFotosDirPath(registroId, category);
    final base = await _getBasePath();
    final ext = p.extension(sourcePath).toLowerCase();
    final name = 'photo_${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? ".jpg" : ext}';
    final destPath = p.join(fotosDir, name);

    List<int>? compressed = await FlutterImageCompress.compressWithFile(
      sourcePath,
      minWidth: 1920,
      minHeight: 1080,
      quality: 85,
      format: ext == '.png' ? CompressFormat.png : CompressFormat.jpeg,
    );

    if (compressed == null) {
      await file.copy(destPath);
    } else {
      final out = File(destPath);
      await out.writeAsBytes(compressed);
      int currentLength = compressed.length;
      int quality = 85;
      while (currentLength > _targetPhotoBytes && quality > 10) {
        quality -= 15;
        if (quality < 10) quality = 10;
        compressed = await FlutterImageCompress.compressWithFile(
          sourcePath,
          minWidth: 1920,
          minHeight: 1080,
          quality: quality,
          format: ext == '.png' ? CompressFormat.png : CompressFormat.jpeg,
        );
        if (compressed != null) {
          await out.writeAsBytes(compressed);
          currentLength = compressed.length;
        }
      }
    }

    return p.relative(destPath, from: base);
  }

  /// Guarda un PDF en la carpeta del registro. [category] listasAsistencia o actas.
  Future<String> savePdf(int registroId, String sourcePath, {CategoriaMedio category = CategoriaMedio.listasAsistencia}) async {
    final file = File(sourcePath);
    if (!await file.exists()) throw Exception('Archivo no encontrado');

    final pdfsDir = await getPdfsDirPath(registroId, category);
    final base = await _getBasePath();
    final name = p.basename(sourcePath);
    if (!name.toLowerCase().endsWith('.pdf')) {
      throw Exception('Solo se permiten archivos PDF');
    }
    final destPath = p.join(pdfsDir, '${DateTime.now().millisecondsSinceEpoch}_$name');
    await file.copy(destPath);
    return p.relative(destPath, from: base);
  }
}
