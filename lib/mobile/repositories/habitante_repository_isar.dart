import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/contracts/habitante_repository.dart';
import '../../models/models.dart';

/// Implementación Isar de [HabitanteRepository]. Solo se usa en builds móvil/desktop.
class HabitanteRepositoryIsar implements HabitanteRepository {
  final Isar _isar;

  HabitanteRepositoryIsar(this._isar);

  @override
  Future<void> guardarHabitante(Habitante habitante) async {
    await _isar.writeTxn(() async {
      await _isar.habitantes.put(habitante);
    });
  }

  @override
  Future<List<Habitante>> obtenerTodos() async {
    return await _isar.habitantes
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
  }

  @override
  Future<int> contar() async {
    return await _isar.habitantes
        .filter()
        .isDeletedEqualTo(false)
        .count();
  }

  @override
  Future<List<Habitante>> obtenerPaginado(int offset, int limit) async {
    return await _isar.habitantes
        .filter()
        .isDeletedEqualTo(false)
        .sortByCedula()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  @override
  Future<List<Habitante>> buscarPorTexto(String query, {int limit = 50}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final queryLower = q.toLowerCase();
    final cedulaExacta = int.tryParse(q);

    return await _isar.habitantes
        .filter()
        .isDeletedEqualTo(false)
        .and()
        .group((g) {
          var chain = g
              .nombreCompletoContains(queryLower, caseSensitive: false)
              .or()
              .direccionContains(queryLower, caseSensitive: false);
          if (cedulaExacta != null) {
            chain = chain.or().cedulaEqualTo(cedulaExacta);
          }
          return chain;
        })
        .limit(limit)
        .findAll();
  }

  @override
  Future<void> actualizarHabitante(Habitante habitante) async {
    await _isar.writeTxn(() async {
      habitante.isSynced = false;
      await _isar.habitantes.put(habitante);
    });
  }

  @override
  Future<void> eliminarHabitante(Id id) async {
    await _isar.writeTxn(() async {
      final habitante = await _isar.habitantes.get(id);
      if (habitante != null) {
        habitante.isDeleted = true;
        habitante.isSynced = false;
        await _isar.habitantes.put(habitante);
      }
    });
  }

  @override
  Future<Habitante?> getHabitanteByCedula(int cedula) async {
    return await _isar.habitantes.filter().cedulaEqualTo(cedula).findFirst();
  }

  @override
  Future<Map<String, dynamic>?> buscarEnNube(int cedula) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('habitantes')
          .doc(cedula.toString())
          .get();

      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      debugPrint('Error en búsqueda remota: $e');
    }
    return null;
  }
}
