import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/contracts/consejo_repository.dart';
import '../../models/models.dart';

/// Implementación Firestore de [ConsejoRepository]. Solo se usa en builds web.
class ConsejoRepositoryFirestore implements ConsejoRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<List<ConsejoComunal>> getAllConsejos() async {
    final snapshot = await _firestore.collection('consejosComunales').get();
    return snapshot.docs.map((d) => _docToConsejo(d)).toList();
  }

  @override
  Future<List<ConsejoComunal>> getAllConsejosComunales() async {
    return getAllConsejos();
  }

  @override
  Future<List<ConsejoComunal>> buscarPorTexto(String query, {int limit = 50}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final snapshot = await _firestore
        .collection('consejosComunales')
        .limit(limit * 2)
        .get();
    return snapshot.docs
        .map((d) => _docToConsejo(d))
        .where((c) =>
            c.nombreConsejo.toLowerCase().contains(q) ||
            c.codigoSitur.toLowerCase().contains(q))
        .take(limit)
        .toList();
  }

  @override
  Future<ConsejoComunal?> getConsejoComunalByCodigoSitur(String codigoSitur) async {
    final doc = await _firestore.collection('consejosComunales').doc(codigoSitur).get();
    if (!doc.exists) return null;
    return _docToConsejo(doc);
  }

  @override
  Future<void> guardarConsejo(ConsejoComunal consejo) async {
    await _firestore.collection('consejosComunales').doc(consejo.codigoSitur).set({
      'codigoSitur': consejo.codigoSitur,
      'rif': consejo.rif,
      'nombreConsejo': consejo.nombreConsejo,
      'comunidades': consejo.comunidades,
      'tipoZona': consejo.tipoZona.name,
      'latitud': consejo.latitud,
      'longitud': consejo.longitud,
    });
  }

  @override
  Future<void> actualizarConsejo(ConsejoComunal consejo) async {
    await guardarConsejo(consejo);
  }

  @override
  Future<void> eliminarConsejo(int id) async {
    final snapshot = await _firestore.collection('consejosComunales').get();
    for (final d in snapshot.docs) {
      final c = _docToConsejo(d);
      if (c.id == id) {
        await d.reference.delete();
        return;
      }
    }
  }

  static ConsejoComunal _docToConsejo(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final c = ConsejoComunal();
    c.codigoSitur = data['codigoSitur'] as String? ?? doc.id;
    c.rif = data['rif'] as String?;
    c.nombreConsejo = data['nombreConsejo'] as String? ?? '';
    c.comunidades = List<String>.from(data['comunidades'] as List? ?? []);
    c.tipoZona = TipoZona.values.firstWhere(
      (t) => t.name == (data['tipoZona'] as String?),
      orElse: () => TipoZona.Urbano,
    );
    c.latitud = (data['latitud'] as num?)?.toDouble() ?? 0.0;
    c.longitud = (data['longitud'] as num?)?.toDouble() ?? 0.0;
    c.isSynced = true;
    c.isDeleted = false;
    return c;
  }
}
