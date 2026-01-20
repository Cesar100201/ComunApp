import 'package:flutter/foundation.dart';

/// Utilidad para logging condicional basado en el modo de depuración.
/// Solo muestra logs cuando la app está en modo debug.
class AppLogger {
  /// Log informativo
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
      if (error != null) {
        debugPrint('[ERROR] $error');
        if (stackTrace != null) {
          debugPrint('[STACK] $stackTrace');
        }
      }
    }
  }

  /// Log de depuración (solo para desarrollo)
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
  }

  /// Log de advertencia
  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('[WARNING] $message');
    }
  }

  /// Log de error
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
      if (error != null) {
        debugPrint('  Exception: $error');
        if (stackTrace != null) {
          debugPrint('  StackTrace: $stackTrace');
        }
      }
    }
  }
}
