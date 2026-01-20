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
