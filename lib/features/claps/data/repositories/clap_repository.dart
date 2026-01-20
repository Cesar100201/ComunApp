import 'package:isar/isar.dart';
import '../../../../database/db_helper.dart';
import '../../../../models/models.dart';

class ClapRepository {
  Future<void> guardarClap(Clap clap) async {
    final isar = await DbHelper().db;
    await isar.writeTxn(() async {
      await isar.claps.put(clap);
      if (clap.jefeComunidad.value != null) {
        await clap.jefeComunidad.save();
      }
    });
  }

  Future<List<Clap>> obtenerTodos() async {
    final isar = await DbHelper().db;
    return await isar.claps
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
  }

  Future<void> actualizarClap(Clap clap) async {
    final isar = await DbHelper().db;
    await isar.writeTxn(() async {
      clap.isSynced = false;
      await isar.claps.put(clap);
      if (clap.jefeComunidad.value != null) {
        await clap.jefeComunidad.save();
      }
    });
  }

  Future<void> eliminarClap(Id id) async {
    final isar = await DbHelper().db;
    await isar.writeTxn(() async {
      final clap = await isar.claps.get(id);
      if (clap != null) {
        clap.isDeleted = true;
        clap.isSynced = false;
        await isar.claps.put(clap);
      }
    });
  }

  Future<Clap?> buscarPorId(Id id) async {
    final isar = await DbHelper().db;
    return await isar.claps.get(id);
  }
}
