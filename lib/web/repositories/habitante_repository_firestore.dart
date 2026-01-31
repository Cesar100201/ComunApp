import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/contracts/habitante_repository.dart';
import '../../core/utils/constants.dart';
import '../../models/models.dart';

/// Implementación Firestore de [HabitanteRepository]. Solo se usa en builds web.
class HabitanteRepositoryFirestore implements HabitanteRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> guardarHabitante(Habitante habitante) async {
    final ref = _firestore.collection('habitantes').doc(habitante.cedula.toString());
    await ref.set(_habitanteToMap(habitante));
  }

  @override
  Future<List<Habitante>> obtenerTodos() async {
    final snapshot = await _firestore
        .collection('habitantes')
        .orderBy('cedula')
        .get()
        .timeout(AppConstants.syncTimeout);
    return snapshot.docs.map((d) => _docToHabitante(d)).whereType<Habitante>().toList();
  }

  @override
  Future<int> contar() async {
    final snapshot = await _firestore.collection('habitantes').count().get();
    return snapshot.count ?? 0;
  }

  @override
  Future<List<Habitante>> obtenerPaginado(int offset, int limit) async {
    var query = _firestore
        .collection('habitantes')
        .orderBy('cedula')
        .limit(offset + limit);

    final snapshot = await query.get().timeout(AppConstants.syncTimeout);
    final all = snapshot.docs.map((d) => _docToHabitante(d)).whereType<Habitante>().toList();
    if (offset >= all.length) return [];
    return all.skip(offset).take(limit).toList();
  }

  @override
  Future<List<Habitante>> buscarPorTexto(String query, {int limit = 50}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final snapshot = await _firestore
        .collection('habitantes')
        .orderBy('nombreCompleto')
        .limit(limit * 2)
        .get()
        .timeout(AppConstants.networkTimeout);
    final lower = q.toLowerCase();
    final cedulaExacta = int.tryParse(q);
    final list = snapshot.docs
        .map((d) => _docToHabitante(d))
        .whereType<Habitante>()
        .where((h) {
          if (cedulaExacta != null && h.cedula == cedulaExacta) return true;
          return h.nombreCompleto.toLowerCase().contains(lower) ||
              h.direccion.toLowerCase().contains(lower);
        })
        .take(limit)
        .toList();
    return list;
  }

  @override
  Future<void> actualizarHabitante(Habitante habitante) async {
    final ref = _firestore.collection('habitantes').doc(habitante.cedula.toString());
    await ref.update(_habitanteToMap(habitante));
  }

  @override
  Future<void> eliminarHabitante(int id) async {
    final snapshot = await _firestore
        .collection('habitantes')
        .where('id', isEqualTo: id)
        .limit(1)
        .get();
    for (final d in snapshot.docs) {
      await d.reference.delete();
      return;
    }
  }

  @override
  Future<Habitante?> getHabitanteByCedula(int cedula) async {
    final doc = await _firestore.collection('habitantes').doc(cedula.toString()).get();
    if (!doc.exists) return null;
    return _docToHabitante(doc);
  }

  @override
  Future<Map<String, dynamic>?> buscarEnNube(int cedula) async {
    final doc = await _firestore.collection('habitantes').doc(cedula.toString()).get();
    return doc.exists ? doc.data() : null;
  }

  static Habitante _docToHabitante(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final h = Habitante();
    h.cedula = (data['cedula'] as num?)?.toInt() ?? int.tryParse(doc.id) ?? 0;
    h.nacionalidad = Nacionalidad.values.firstWhere(
      (n) => n.name == (data['nacionalidad'] as String? ?? 'V'),
      orElse: () => Nacionalidad.V,
    );
    h.nombreCompleto = data['nombreCompleto'] as String? ?? '';
    h.telefono = data['telefono'] as String? ?? '';
    h.direccion = data['direccion'] as String? ?? '';
    h.fotoUrl = data['fotoUrl'] as String?;
    h.nivelUsuario = (data['nivelUsuario'] as num?)?.toInt() ?? 1;
    final fechaNacTimestamp = data['fechaNacimiento'] as Timestamp?;
    h.fechaNacimiento = fechaNacTimestamp?.toDate() ?? AppConstants.defaultBirthDate;
    h.genero = Genero.values.firstWhere(
      (g) => g.name == (data['genero'] as String? ?? 'Masculino'),
      orElse: () => Genero.Masculino,
    );
    h.estatusPolitico = EstatusPolitico.values.firstWhere(
      (e) => e.name == (data['estatusPolitico'] as String? ?? 'Neutral'),
      orElse: () => EstatusPolitico.Neutral,
    );
    h.nivelVoto = NivelVoto.values.firstWhere(
      (n) => n.name == (data['nivelVoto'] as String? ?? 'Blando'),
      orElse: () => NivelVoto.Blando,
    );
    h.id = (data['id'] as num?)?.toInt() ?? 0;
    h.isSynced = true;
    h.isDeleted = false;
    return h;
  }

  static Map<String, dynamic> _habitanteToMap(Habitante h) {
    return {
      'id': h.id,
      'cedula': h.cedula,
      'nacionalidad': h.nacionalidad.name,
      'nombreCompleto': h.nombreCompleto,
      'telefono': h.telefono,
      'fechaNacimiento': Timestamp.fromDate(h.fechaNacimiento),
      'genero': h.genero.name,
      'direccion': h.direccion,
      'estatusPolitico': h.estatusPolitico.name,
      'nivelVoto': h.nivelVoto.name,
      'nivelUsuario': h.nivelUsuario,
      'fotoUrl': h.fotoUrl,
      'ultimaActualizacion': FieldValue.serverTimestamp(),
    };
  }
}
