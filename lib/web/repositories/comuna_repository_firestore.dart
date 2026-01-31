import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/contracts/comuna_repository.dart';
import '../../models/models.dart';

/// Implementación Firestore de [ComunaRepository]. Solo se usa en builds web.
class ComunaRepositoryFirestore implements ComunaRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<List<Comuna>> getAllComunas() async {
    final snapshot = await _firestore.collection('comunas').get();
    return snapshot.docs.map((d) => _docToComuna(d)).toList();
  }

  @override
  Future<Comuna?> getComunaByCodigoSitur(String codigoSitur) async {
    final doc = await _firestore.collection('comunas').doc(codigoSitur).get();
    if (!doc.exists) return null;
    return _docToComuna(doc);
  }

  @override
  Future<List<ConsejoComunal>> getConsejosComunalesByComunaId(int comunaId) async {
    final snapshot = await _firestore
        .collection('consejosComunales')
        .where('comunaId', isEqualTo: comunaId)
        .get();
    return snapshot.docs.map((d) => _docToConsejo(d)).toList();
  }

  @override
  Future<void> guardarComuna(Comuna comuna) async {
    await _firestore.collection('comunas').doc(comuna.codigoSitur).set({
      'codigoSitur': comuna.codigoSitur,
      'rif': comuna.rif,
      'codigoComElectoral': comuna.codigoComElectoral,
      'nombreComuna': comuna.nombreComuna,
      'municipio': comuna.municipio,
      'parroquia': comuna.parroquia.name,
      'latitud': comuna.latitud,
      'longitud': comuna.longitud,
    });
  }

  @override
  Future<void> actualizarComuna(Comuna comuna) async {
    await guardarComuna(comuna);
  }

  @override
  Future<void> eliminarComuna(int id) async {
    final snapshot = await _firestore.collection('comunas').get();
    for (final d in snapshot.docs) {
      final c = _docToComuna(d);
      if (c.id == id) {
        await d.reference.delete();
        return;
      }
    }
  }

  static Comuna _docToComuna(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final c = Comuna();
    c.codigoSitur = data['codigoSitur'] as String? ?? doc.id;
    c.rif = data['rif'] as String?;
    c.codigoComElectoral = data['codigoComElectoral'] as String? ?? '';
    c.nombreComuna = data['nombreComuna'] as String? ?? '';
    c.municipio = data['municipio'] as String? ?? 'García de Hevia';
    c.parroquia = _parseParroquia(data['parroquia'] as String?);
    c.latitud = (data['latitud'] as num?)?.toDouble() ?? 0.0;
    c.longitud = (data['longitud'] as num?)?.toDouble() ?? 0.0;
    c.isSynced = true;
    c.isDeleted = false;
    return c;
  }

  static Parroquia _parseParroquia(String? v) {
    if (v == null) return Parroquia.LaFria;
    return Parroquia.values.firstWhere(
      (p) => p.name == v,
      orElse: () => Parroquia.LaFria,
    );
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
