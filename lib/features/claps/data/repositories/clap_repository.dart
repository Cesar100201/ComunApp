import 'package:isar/isar.dart';
import '../../../../models/models.dart';
import '../../../../core/contracts/clap_repository.dart' as contract;

class ClapRepository implements contract.ClapRepository {
  final Isar _isar;

  ClapRepository(this._isar);

  @override
  Future<void> guardarClap(Clap clap) async {
    await _isar.writeTxn(() async {
      await _isar.claps.put(clap);
      if (clap.jefeComunidad.value != null) {
        await clap.jefeComunidad.save();
      }
    });
  }

  @override
  Future<List<Clap>> obtenerTodos() async {
    return await _isar.claps
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
  }

  @override
  Future<void> actualizarClap(Clap clap) async {
    await _isar.writeTxn(() async {
      clap.isSynced = false;
      await _isar.claps.put(clap);
      if (clap.jefeComunidad.value != null) {
        await clap.jefeComunidad.save();
      }
    });
  }

  @override
  Future<void> eliminarClap(Id id) async {
    await _isar.writeTxn(() async {
      final clap = await _isar.claps.get(id);
      if (clap != null) {
        clap.isDeleted = true;
        clap.isSynced = false;
        await _isar.claps.put(clap);
      }
    });
  }

  @override
  Future<Clap?> buscarPorId(Id id) async {
    return await _isar.claps.get(id);
  }
}
