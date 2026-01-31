import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/contracts/clap_repository.dart';
import '../../models/models.dart';

/// Implementación Firestore de [ClapRepository]. Solo se usa en builds web.
class ClapRepositoryFirestore implements ClapRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<List<Clap>> obtenerTodos() async {
    final snapshot = await _firestore.collection('claps').get();
    return snapshot.docs.map((d) => _docToClap(d)).toList();
  }

  @override
  Future<Clap?> buscarPorId(int id) async {
    final snapshot = await _firestore.collection('claps').where('id', isEqualTo: id).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return _docToClap(snapshot.docs.first);
  }

  @override
  Future<void> guardarClap(Clap clap) async {
    await _firestore.collection('claps').doc(clap.id.toString()).set({
      'id': clap.id,
      'nombreClap': clap.nombreClap,
    });
  }

  @override
  Future<void> actualizarClap(Clap clap) async {
    await guardarClap(clap);
  }

  @override
  Future<void> eliminarClap(int id) async {
    final snapshot = await _firestore.collection('claps').where('id', isEqualTo: id).get();
    for (final d in snapshot.docs) {
      await d.reference.delete();
      return;
    }
  }

  static Clap _docToClap(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final c = Clap();
    c.id = (data['id'] as num?)?.toInt() ?? 0;
    c.nombreClap = data['nombreClap'] as String? ?? '';
    c.isSynced = true;
    c.isDeleted = false;
    return c;
  }
}
