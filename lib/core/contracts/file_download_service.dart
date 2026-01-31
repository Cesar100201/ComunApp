/// Contrato para descargar/guardar archivos. Implementado por móvil (path_provider + File) o web (blob).
abstract class FileDownloadService {
  /// Descarga un archivo de texto (CSV, etc.) con el nombre indicado.
  Future<void> downloadString(String filename, String content, {String mimeType = 'text/csv'});

  /// Descarga un archivo binario con el nombre indicado.
  Future<void> downloadBytes(String filename, List<int> bytes, {String mimeType = 'application/octet-stream'});
}
