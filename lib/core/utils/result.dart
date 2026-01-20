/// Tipo Result para manejo funcional de errores.
/// 
/// Permite representar el resultado de una operación que puede
/// tener éxito (Success) o fallar (Failure) de forma type-safe.
/// 
/// Ejemplo de uso:
/// ```dart
/// Future<Result<User, AuthException>> login(String email, String password) async {
///   try {
///     final user = await _auth.signIn(email, password);
///     return Result.success(user);
///   } on AuthException catch (e) {
///     return Result.failure(e);
///   }
/// }
/// 
/// // Consumir el resultado:
/// final result = await login(email, password);
/// result.when(
///   success: (user) => print('Bienvenido ${user.email}'),
///   failure: (error) => print('Error: ${error.message}'),
/// );
/// ```
sealed class Result<T, E> {
  const Result._();

  /// Crea un resultado exitoso con el valor [data].
  const factory Result.success(T data) = Success<T, E>;

  /// Crea un resultado fallido con el error [error].
  const factory Result.failure(E error) = Failure<T, E>;

  /// Indica si el resultado es exitoso.
  bool get isSuccess => this is Success<T, E>;

  /// Indica si el resultado es un fallo.
  bool get isFailure => this is Failure<T, E>;

  /// Retorna el valor si es exitoso, o null si es un fallo.
  T? get valueOrNull => switch (this) {
    Success(value: final v) => v,
    Failure() => null,
  };

  /// Retorna el error si es un fallo, o null si es exitoso.
  E? get errorOrNull => switch (this) {
    Success() => null,
    Failure(error: final e) => e,
  };

  /// Ejecuta [onSuccess] si el resultado es exitoso, o [onFailure] si es un fallo.
  R when<R>({
    required R Function(T data) success,
    required R Function(E error) failure,
  }) => switch (this) {
    Success(value: final v) => success(v),
    Failure(error: final e) => failure(e),
  };

  /// Transforma el valor exitoso usando [transform].
  Result<R, E> map<R>(R Function(T data) transform) => switch (this) {
    Success(value: final v) => Result.success(transform(v)),
    Failure(error: final e) => Result.failure(e),
  };

  /// Transforma el error usando [transform].
  Result<T, R> mapError<R>(R Function(E error) transform) => switch (this) {
    Success(value: final v) => Result.success(v),
    Failure(error: final e) => Result.failure(transform(e)),
  };

  /// Encadena operaciones que retornan Result.
  Future<Result<R, E>> flatMap<R>(Future<Result<R, E>> Function(T data) transform) async {
    return switch (this) {
      Success(value: final v) => await transform(v),
      Failure(error: final e) => Result.failure(e),
    };
  }

  /// Retorna el valor si es exitoso, o ejecuta [orElse] si es un fallo.
  T getOrElse(T Function(E error) orElse) => switch (this) {
    Success(value: final v) => v,
    Failure(error: final e) => orElse(e),
  };

  /// Retorna el valor si es exitoso, o [defaultValue] si es un fallo.
  T getOrDefault(T defaultValue) => switch (this) {
    Success(value: final v) => v,
    Failure() => defaultValue,
  };

  /// Lanza el error si es un fallo, o retorna el valor si es exitoso.
  T getOrThrow() => switch (this) {
    Success(value: final v) => v,
    Failure(error: final e) => throw e as Object,
  };
}

/// Representa un resultado exitoso.
final class Success<T, E> extends Result<T, E> {
  /// El valor exitoso.
  final T value;

  const Success(this.value) : super._();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, E> && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

/// Representa un resultado fallido.
final class Failure<T, E> extends Result<T, E> {
  /// El error del fallo.
  final E error;

  const Failure(this.error) : super._();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T, E> && runtimeType == other.runtimeType && error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure($error)';
}

/// Extensiones para trabajar con Future<Result>.
extension FutureResultExtension<T, E> on Future<Result<T, E>> {
  /// Ejecuta [onSuccess] si el resultado es exitoso, o [onFailure] si es un fallo.
  Future<R> when<R>({
    required R Function(T data) success,
    required R Function(E error) failure,
  }) async {
    final result = await this;
    return result.when(success: success, failure: failure);
  }

  /// Transforma el valor exitoso usando [transform].
  Future<Result<R, E>> map<R>(R Function(T data) transform) async {
    final result = await this;
    return result.map(transform);
  }
}

/// Utilidades para crear Results desde operaciones async.
class ResultUtils {
  /// Ejecuta una operación async y captura excepciones como Failure.
  /// 
  /// Ejemplo:
  /// ```dart
  /// final result = await ResultUtils.tryAsync(
  ///   () => _api.fetchUser(id),
  ///   onError: (e) => ApiException('Error al obtener usuario: $e'),
  /// );
  /// ```
  static Future<Result<T, E>> tryAsync<T, E>(
    Future<T> Function() operation, {
    required E Function(Object error, StackTrace stackTrace) onError,
  }) async {
    try {
      final value = await operation();
      return Result.success(value);
    } catch (e, stackTrace) {
      return Result.failure(onError(e, stackTrace));
    }
  }

  /// Ejecuta una operación síncrona y captura excepciones como Failure.
  static Result<T, E> trySync<T, E>(
    T Function() operation, {
    required E Function(Object error, StackTrace stackTrace) onError,
  }) {
    try {
      final value = operation();
      return Result.success(value);
    } catch (e, stackTrace) {
      return Result.failure(onError(e, stackTrace));
    }
  }
}
