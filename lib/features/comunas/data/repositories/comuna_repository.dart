import 'package:isar/isar.dart';
import '../../../../models/models.dart';

class ComunaRepository {
  final Isar _isar;

  ComunaRepository(this._isar);

  Future<void> guardarComuna(Comuna comuna) async {
    await _isar.writeTxn(() async {
      await _isar.comunas.put(comuna);
    });
  }

  Future<List<Comuna>> getAllComunas() async {
    return await _isar.comunas
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
  }

  Future<void> actualizarComuna(Comuna comuna) async {
    await _isar.writeTxn(() async {
      comuna.isSynced = false; // Marcar como pendiente
      await _isar.comunas.put(comuna);
    });
  }

  Future<void> eliminarComuna(Id id) async {
    await _isar.writeTxn(() async {
      final comuna = await _isar.comunas.get(id);
      if (comuna != null) {
        comuna.isDeleted = true;
        comuna.isSynced = false; // Marcar como pendiente para sincronizar eliminación
        await _isar.comunas.put(comuna);
      }
    });
  }

  Future<Comuna?> getComunaByCodigoSitur(String codigoSitur) async {
    return await _isar.comunas.filter().codigoSiturEqualTo(codigoSitur).findFirst();
  }

  Future<List<ConsejoComunal>> getConsejosComunalesByComunaId(Id comunaId) async {
    return await _isar.consejoComunals.filter().comuna((q) => q.idEqualTo(comunaId)).findAll();
  }
}
