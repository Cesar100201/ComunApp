import 'package:isar/isar.dart';
import '../../../../models/models.dart';

class ExtranjeroRepository {
  final Isar _isar;

  ExtranjeroRepository(this._isar);

  Future<void> guardarExtranjero(Extranjero extranjero) async {
    await _isar.writeTxn(() async {
      await _isar.extranjeros.put(extranjero);
    });
  }

  Future<List<Extranjero>> obtenerTodos() async {
    return await _isar.extranjeros
        .filter()
        .isDeletedEqualTo(false)
        .sortByNombreCompleto()
        .findAll();
  }

  /// Total de extranjeros no eliminados (para listado y paginación).
  Future<int> contar() async {
    return await _isar.extranjeros
        .filter()
        .isDeletedEqualTo(false)
        .count();
  }

  /// Lista paginada por nombre. Para listados grandes.
  Future<List<Extranjero>> obtenerPaginado(int offset, int limit) async {
    return await _isar.extranjeros
        .filter()
        .isDeletedEqualTo(false)
        .sortByNombreCompleto()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  /// Búsqueda por nombre, cédula colombiana, dirección, departamento o municipio.
  Future<List<Extranjero>> buscarPorTexto(String query, {int limit = 50}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final queryLower = q.toLowerCase();
    final cedulaExacta = int.tryParse(q);

    var builder = _isar.extranjeros
        .filter()
        .isDeletedEqualTo(false)
        .and()
        .group((g) {
          var chain = g
              .nombreCompletoContains(queryLower, caseSensitive: false)
              .or()
              .departamentoContains(queryLower, caseSensitive: false)
              .or()
              .municipioContains(queryLower, caseSensitive: false);
          if (cedulaExacta != null) {
            chain = chain.or().cedulaColombianaEqualTo(cedulaExacta);
          }
          return chain.or().direccionContains(queryLower, caseSensitive: false);
        });
    return await builder.sortByNombreCompleto().limit(limit).findAll();
  }

  Future<Extranjero?> getByCedulaColombiana(int cedula) async {
    return await _isar.extranjeros
        .filter()
        .cedulaColombianaEqualTo(cedula)
        .isDeletedEqualTo(false)
        .findFirst();
  }

  Future<void> eliminarExtranjero(Id id) async {
    await _isar.writeTxn(() async {
      final extranjero = await _isar.extranjeros.get(id);
      if (extranjero != null) {
        extranjero.isDeleted = true;
        extranjero.isSynced = false;
        await _isar.extranjeros.put(extranjero);
      }
    });
  }
}
