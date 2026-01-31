import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/contracts/file_download_service.dart';

/// Implementación móvil de [FileDownloadService]. Solo se usa en builds móvil/desktop.
class FileDownloadServiceMobile implements FileDownloadService {
  @override
  Future<void> downloadString(String filename, String content, {String mimeType = 'text/csv'}) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content, encoding: utf8);
  }

  @override
  Future<void> downloadBytes(String filename, List<int> bytes, {String mimeType = 'application/octet-stream'}) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
  }
}
