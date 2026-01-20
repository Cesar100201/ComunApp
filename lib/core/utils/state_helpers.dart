import 'package:flutter/material.dart';

/// Extension para facilitar el manejo seguro de setState en operaciones async.
/// 
/// Uso:
/// ```dart
/// // En lugar de:
/// if (mounted) {
///   setState(() { _isLoading = false; });
/// }
/// 
/// // Puedes usar:
/// safeSetState(() { _isLoading = false; });
/// ```
extension SafeStateExtension<T extends StatefulWidget> on State<T> {
  /// Ejecuta setState solo si el widget está montado.
  /// 
  /// Previene errores de "setState called after dispose".
  void safeSetState(VoidCallback fn) {
    if (mounted) {
      // ignore: invalid_use_of_protected_member
      setState(fn);
    }
  }

  /// Ejecuta una función async y luego llama setState de forma segura.
  /// 
  /// Ejemplo:
  /// ```dart
  /// await safeAsyncSetState(() async {
  ///   _data = await fetchData();
  /// });
  /// ```
  Future<void> safeAsyncSetState(Future<void> Function() asyncFn) async {
    await asyncFn();
    if (mounted) {
      // ignore: invalid_use_of_protected_member
      setState(() {});
    }
  }
}

/// Mixin que provee métodos helper para manejo de estado seguro.
/// 
/// Agregar a tu State class:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> with SafeStateMixin {
///   void someAsyncMethod() async {
///     // ... async operations
///     setStateIfMounted(() { _isLoading = false; });
///   }
/// }
/// ```
mixin SafeStateMixin<T extends StatefulWidget> on State<T> {
  /// Ejecuta setState solo si el widget está montado.
  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      // ignore: invalid_use_of_protected_member
      setState(fn);
    }
  }

  /// Muestra un SnackBar solo si el widget está montado.
  void showSnackBarIfMounted(String message, {Color? backgroundColor, Duration? duration}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: duration ?? const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Navega a otra página solo si el widget está montado.
  Future<R?> pushIfMounted<R>(Widget page) async {
    if (!mounted) return null;
    return Navigator.push<R>(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  /// Pop de navegación solo si el widget está montado.
  void popIfMounted<R>([R? result]) {
    if (mounted) {
      Navigator.pop(context, result);
    }
  }
}

/// Clase helper para ejecutar funciones de forma condicional.
class ConditionalRunner {
  /// Ejecuta [action] solo si [condition] es verdadera.
  static void runIf(bool condition, VoidCallback action) {
    if (condition) action();
  }

  /// Ejecuta [action] solo si [condition] es verdadera, 
  /// de lo contrario ejecuta [otherwise].
  static void runIfElse(bool condition, VoidCallback action, VoidCallback otherwise) {
    condition ? action() : otherwise();
  }
}
