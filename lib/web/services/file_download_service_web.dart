import 'dart:html' as html;
import 'dart:convert';
import '../../core/contracts/file_download_service.dart';

/// Implementación web de [FileDownloadService]. Solo se usa en builds web.
class FileDownloadServiceWeb implements FileDownloadService {
  @override
  Future<void> downloadString(String filename, String content, {String mimeType = 'text/csv'}) async {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement()
      ..href = url
      ..download = filename;
    anchor.click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Future<void> downloadBytes(String filename, List<int> bytes, {String mimeType = 'application/octet-stream'}) async {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement()
      ..href = url
      ..download = filename;
    anchor.click();
    html.Url.revokeObjectUrl(url);
  }
}
