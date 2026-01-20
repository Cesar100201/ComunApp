import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../../../../models/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HabitanteRepository {
  final Isar _isar;

  HabitanteRepository(this._isar);
  // Función para guardar un habitante en la Base de Datos Local
  Future<void> guardarHabitante(Habitante habitante) async {
    // En Isar, escribir datos SIEMPRE se hace dentro de una transacción (writeTxn)
    await _isar.writeTxn(() async {
      await _isar.habitantes.put(habitante); 
    });
  }

  /// Obtiene todos los habitantes (evitar con muchos registros; preferir [obtenerPaginado]).
  Future<List<Habitante>> obtenerTodos() async {
    return await _isar.habitantes
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
  }

  /// Total de habitantes no eliminados (para paginación).
  Future<int> contar() async {
    return await _isar.habitantes
        .filter()
        .isDeletedEqualTo(false)
        .count();
  }

  /// Lista paginada por cédula ascendente. Ideal para listas grandes.
  Future<List<Habitante>> obtenerPaginado(int offset, int limit) async {
    return await _isar.habitantes
        .filter()
        .isDeletedEqualTo(false)
        .sortByCedula()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  /// Búsqueda por nombre, dirección o cédula exacta. Limita resultados en BD.
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

  Future<void> actualizarHabitante(Habitante habitante) async {
    await _isar.writeTxn(() async {
      habitante.isSynced = false; // Marcar como pendiente
      await _isar.habitantes.put(habitante);
    });
  }

  Future<void> eliminarHabitante(Id id) async {
    await _isar.writeTxn(() async {
      final habitante = await _isar.habitantes.get(id);
      if (habitante != null) {
        habitante.isDeleted = true;
        habitante.isSynced = false; // Marcar como pendiente para sincronizar eliminación
        await _isar.habitantes.put(habitante);
      }
    });
  }

  Future<Habitante?> getHabitanteByCedula(int cedula) async {
    return await _isar.habitantes.filter().cedulaEqualTo(cedula).findFirst();
  }

  Future<Map<String, dynamic>?> buscarEnNube(int cedula) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('habitantes')
          .doc(cedula.toString())
          .get();
      
      if (doc.exists) {
        return doc.data(); // Retorna los datos si existe
      }
    } catch (e) {
      debugPrint("Error en búsqueda remota: $e");
    }
    return null; // No existe o no hay internet
  }
}