import 'package:isar/isar.dart';
import '../../../../models/models.dart';

class ConsejoRepository {
  final Isar _isar;

  ConsejoRepository(this._isar);

  Future<void> guardarConsejo(ConsejoComunal consejo) async {
    await _isar.writeTxn(() async {
      await _isar.consejoComunals.put(consejo);
      if (consejo.comuna.value != null) {
        await consejo.comuna.save();
      }
    });
  }

  Future<List<ConsejoComunal>> getAllConsejosComunales() async {
    return await _isar.consejoComunals
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
  }

  /// Búsqueda por nombre, código SITUR, comuna o parroquia.
  Future<List<ConsejoComunal>> buscarPorTexto(String query, {int limit = 50}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final queryLower = q.toLowerCase();
    final parroquia = _parseParroquiaQuery(queryLower);

    return await _isar.consejoComunals
        .filter()
        .isDeletedEqualTo(false)
        .and()
        .group((g) {
          var chain = g
              .nombreConsejoContains(queryLower, caseSensitive: false)
              .or()
              .codigoSiturContains(queryLower, caseSensitive: false)
              .or()
              .comuna((q) => q.nombreComunaContains(queryLower, caseSensitive: false))
              .or()
              .comuna((q) => q.codigoSiturContains(queryLower, caseSensitive: false));
          if (parroquia != null) {
            chain = chain.or().comuna((q) => q.parroquiaEqualTo(parroquia));
          }
          return chain;
        })
        .limit(limit)
        .findAll();
  }

  Parroquia? _parseParroquiaQuery(String value) {
    final normalized = value.trim().toUpperCase().replaceAll(' ', '');
    if (normalized.isEmpty) return null;
    if (normalized.contains('BOCA') || normalized.contains('GRITA')) {
      return Parroquia.BocaDeGrita;
    }
    if (normalized.contains('JOSE') || normalized.contains('PAEZ') || normalized.contains('JOSÉ')) {
      return Parroquia.JoseAntonioPaez;
    }
    if (normalized.contains('LAFRIA') || normalized == 'LAFRIA') {
      return Parroquia.LaFria;
    }
    return null;
  }

  Future<void> actualizarConsejo(ConsejoComunal consejo) async {
    await _isar.writeTxn(() async {
      consejo.isSynced = false; // Marcar como pendiente
      await _isar.consejoComunals.put(consejo);
      if (consejo.comuna.value != null) {
        await consejo.comuna.save();
      }
    });
  }

  Future<void> eliminarConsejo(Id id) async {
    await _isar.writeTxn(() async {
      final consejo = await _isar.consejoComunals.get(id);
      if (consejo != null) {
        consejo.isDeleted = true;
        consejo.isSynced = false; // Marcar como pendiente para sincronizar eliminación
        await _isar.consejoComunals.put(consejo);
      }
    });
  }

  Future<ConsejoComunal?> getConsejoComunalByCodigoSitur(String codigoSitur) async {
    return await _isar.consejoComunals.filter().codigoSiturEqualTo(codigoSitur).findFirst();
  }
}
