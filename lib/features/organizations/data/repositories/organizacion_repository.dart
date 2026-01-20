import 'package:isar/isar.dart';
import '../../../../database/db_helper.dart';
import '../../../../models/models.dart';

class OrganizacionRepository {
  Future<void> guardarOrganizacion(Organizacion organizacion) async {
    final isar = await DbHelper().db;
    await isar.writeTxn(() async {
      await isar.organizacions.put(organizacion);
    });
  }

  Future<List<Organizacion>> obtenerTodas() async {
    final isar = await DbHelper().db;
    return await isar.organizacions
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
  }

  Future<void> actualizarOrganizacion(Organizacion organizacion) async {
    final isar = await DbHelper().db;
    await isar.writeTxn(() async {
      organizacion.isSynced = false; // Marcar como pendiente
      await isar.organizacions.put(organizacion);
    });
  }

  Future<void> eliminarOrganizacion(Id id) async {
    final isar = await DbHelper().db;
    await isar.writeTxn(() async {
      final organizacion = await isar.organizacions.get(id);
      if (organizacion != null) {
        organizacion.isDeleted = true;
        organizacion.isSynced = false; // Marcar como pendiente para sincronizar eliminación
        await isar.organizacions.put(organizacion);
      }
    });
  }

  Future<Organizacion?> buscarPorId(Id id) async {
    final isar = await DbHelper().db;
    return await isar.organizacions.get(id);
  }

  Future<List<Organizacion>> getOrganizacionesByType(TipoOrganizacion tipo) async {
    final isar = await DbHelper().db;
    return await isar.organizacions
        .filter()
        .isDeletedEqualTo(false)
        .tipoEqualTo(tipo)
        .findAll();
  }
}
