/// Constantes globales de la aplicación

class AppConstants {
  // Tamaños de batch para operaciones de base de datos
  static const int batchSize = 500;
  static const int batchSizeRelations = 500;

  // Timeouts para operaciones de red (en segundos)
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration syncTimeout = Duration(minutes: 5);

  // Límites de paginación
  static const int defaultPageSize = 50;
  static const int maxPageSize = 500;

  // Intervalos de reporte de progreso
  static const int progressReportIntervalSmall = 50;
  static const int progressReportIntervalLarge = 100;

  // Umbrales para operaciones grandes
  static const int largeFileThreshold = 10000;

  // Porcentajes de progreso (0.0 a 1.0)
  static const double progressPercentageFileRead = 0.05;
  static const double progressPercentageReferencesLoaded = 0.10;
  static const double progressPercentageProcessingStart = 0.10;
  static const double progressPercentageProcessingEnd = 0.85;
  static const double progressPercentageSaving = 0.85;
  static const double progressPercentageSavingEnd = 0.95;
  static const double progressPercentageRelations = 0.95;
  static const double progressPercentageRelationsEnd = 0.98;

  // Valores por defecto
  static const int defaultUserIdLevel = 1;
  static final DateTime defaultBirthDate = DateTime(1990, 1, 1);
  static const String defaultMunicipality = 'García de Hevia';
  static const String defaultParish = 'LaFria';

  // Fecha base para conversión de fechas Excel (días desde 1900)
  static final DateTime excelBaseDate = DateTime(1899, 12, 30);

  // Formatos de fecha aceptados
  static const List<String> dateFormats = [
    'dd/MM/yyyy',
    'dd-MM-yyyy',
    'yyyy-MM-dd',
    'dd/MM/yy',
    'dd-MM-yy',
    'MM/dd/yyyy',
    'yyyy/MM/dd',
  ];
}

/// Excepciones personalizadas de la aplicación

/// Excepción para errores de autenticación
class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, [this.code]);

  @override
  String toString() => 'AuthException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Excepción para errores de sincronización
class SyncException implements Exception {
  final String message;
  final Exception? cause;

  SyncException(this.message, [this.cause]);

  @override
  String toString() {
    if (cause != null) {
      return 'SyncException: $message\nCausa: $cause';
    }
    return 'SyncException: $message';
  }
}

/// Excepción para errores de validación
class ValidationException implements Exception {
  final String message;
  final String? field;

  ValidationException(this.message, [this.field]);

  @override
  String toString() => 'ValidationException: $message${field != null ? ' (campo: $field)' : ''}';
}
