import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';
import '../utils/constants.dart';

/// Servicio para manejar la autenticación de usuarios.
/// Soporta autenticación con email/contraseña y Google Sign-In.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Inicia sesión con correo electrónico y contraseña.
  /// 
  /// Retorna el [User] si la autenticación es exitosa.
  /// Lanza [AuthException] si hay un error de autenticación.
  /// 
  /// Parámetros:
  /// - [email]: Correo electrónico del usuario
  /// - [password]: Contraseña del usuario
  /// 
  /// Excepciones:
  /// - [AuthException]: Si las credenciales son inválidas o hay un error de red
  Future<User> loginConEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ).timeout(
        AppConstants.networkTimeout,
        onTimeout: () {
          throw AuthException('Tiempo de espera agotado. Verifique su conexión a internet.');
        },
      );

      if (result.user == null) {
        throw AuthException('No se pudo obtener la información del usuario.');
      }

      AppLogger.info('Usuario autenticado: ${result.user!.email}');
      return result.user!;
    } on FirebaseAuthException catch (e) {
      final errorMessage = _getAuthErrorMessage(e);
      AppLogger.error('Error en login', e);
      throw AuthException(errorMessage, e.code);
    } on AuthException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado en login', e, stackTrace);
      throw AuthException('Error inesperado al iniciar sesión. Intente nuevamente.');
    }
  }

  /// Registra un nuevo usuario con correo electrónico y contraseña.
  /// 
  /// Retorna el [User] si el registro es exitoso.
  /// Lanza [AuthException] si hay un error en el registro.
  /// 
  /// Parámetros:
  /// - [email]: Correo electrónico del nuevo usuario
  /// - [password]: Contraseña del nuevo usuario (mínimo 6 caracteres)
  /// 
  /// Excepciones:
  /// - [AuthException]: Si el email ya está en uso o hay un error de validación
  Future<User> registrarUsuario(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ).timeout(
        AppConstants.networkTimeout,
        onTimeout: () {
          throw AuthException('Tiempo de espera agotado. Verifique su conexión a internet.');
        },
      );

      if (result.user == null) {
        throw AuthException('No se pudo crear el usuario.');
      }

      AppLogger.info('Usuario registrado: ${result.user!.email}');
      return result.user!;
    } on FirebaseAuthException catch (e) {
      final errorMessage = _getAuthErrorMessage(e);
      AppLogger.error('Error en registro', e);
      throw AuthException(errorMessage, e.code);
    } on AuthException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado en registro', e, stackTrace);
      throw AuthException('Error inesperado al registrar usuario. Intente nuevamente.');
    }
  }

  /// Cierra la sesión del usuario actual.
  /// 
  /// No lanza excepciones, registra errores si ocurren.
  Future<void> salir() async {
    try {
      await _auth.signOut();
      AppLogger.info('Usuario cerró sesión');
    } catch (e, stackTrace) {
      AppLogger.error('Error al cerrar sesión', e, stackTrace);
      // No relanzamos el error para que el logout siempre pueda completarse
    }
  }

  /// Convierte códigos de error de Firebase Auth a mensajes amigables en español.
  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No existe una cuenta con este correo electrónico.';
      case 'wrong-password':
        return 'La contraseña es incorrecta.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con este correo electrónico.';
      case 'weak-password':
        return 'La contraseña es muy débil. Use al menos 6 caracteres.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Por favor, espere un momento.';
      case 'network-request-failed':
        return 'Error de conexión. Verifique su conexión a internet.';
      case 'operation-not-allowed':
        return 'Esta operación no está permitida.';
      default:
        return 'Error de autenticación: ${e.message ?? 'Error desconocido'}';
    }
  }
}