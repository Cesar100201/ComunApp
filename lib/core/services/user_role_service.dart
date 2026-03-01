import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import 'settings_service.dart';
import '../../database/db_helper.dart';
import '../../features/inhabitants/data/repositories/habitante_repository.dart';

/// Servicio para obtener el nivel de usuario (1=Invitado, 2=Generador, 3=Administrador)
/// y permisos derivados. Fuente de verdad: Firestore users/{uid}.nivel;
/// fallback: Habitante vinculado por cédula (nivelUsuario); si no hay nada → 1 (Invitado).
class UserRoleService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _usersCollection = 'users';
  static const String _nivelKey = 'nivel';

  /// Obtiene el nivel del usuario actual (1, 2 o 3).
  Future<int> getNivelUsuario() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return AppConstants.nivelInvitado;

    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        final nivel = data?[_nivelKey];
        if (nivel is int && nivel >= 1 && nivel <= 3) return nivel;
      }
    } catch (_) {
      // Sin conexión o error: usar fallback
    }

    final cedula = await SettingsService.getLinkedHabitanteCedula(uid);
    if (cedula != null) {
      try {
        final isar = await DbHelper().db;
        final repo = HabitanteRepository(isar);
        final h = await repo.getHabitanteByCedula(cedula);
        if (h != null &&
            !h.isDeleted &&
            h.nivelUsuario >= 1 &&
            h.nivelUsuario <= 3) {
          return h.nivelUsuario;
        }
      } catch (_) {}
    }

    return AppConstants.nivelInvitado;
  }

  bool _isAdmin(int nivel) => nivel == AppConstants.nivelAdministrador;
  bool _isGenerador(int nivel) => nivel == AppConstants.nivelGenerador;

  /// Solo administrador puede eliminar.
  bool canDelete(int nivel) => _isAdmin(nivel);

  /// Admin y generador acceden al módulo Registros; invitados no.
  bool canAccessRegistros(int nivel) => _isAdmin(nivel) || _isGenerador(nivel);

  /// Reportes en Gestión Municipal: solo admin y generador.
  bool canAccessReportes(int nivel) => _isAdmin(nivel) || _isGenerador(nivel);

  /// Seguimiento Municipal: solo admin y generador.
  bool canAccessSeguimientoMunicipal(int nivel) =>
      _isAdmin(nivel) || _isGenerador(nivel);

  /// Crear grupos en Formación: solo admin y generador.
  bool canCreateFormacionGroups(int nivel) =>
      _isAdmin(nivel) || _isGenerador(nivel);

  /// Invitados solo pueden solicitar sync profunda (no ejecutarla directamente).
  bool canRequestDeepSync(int nivel) => true;

  /// Solo admin puede aprobar solicitudes de sync profunda (ver notificaciones).
  bool canApproveDeepSync(int nivel) => _isAdmin(nivel);

  /// Ejecutar sync profunda directamente (sin solicitud): admin y generador.
  bool canRunDeepSyncDirectly(int nivel) =>
      _isAdmin(nivel) || _isGenerador(nivel);
}
