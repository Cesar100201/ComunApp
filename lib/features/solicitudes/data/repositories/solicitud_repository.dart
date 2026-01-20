import 'package:isar/isar.dart';
import '../../../../models/models.dart';

class SolicitudRepository {
  final Isar _isar;

  SolicitudRepository(this._isar);

  Future<List<Solicitud>> getAllSolicitudes() async {
    return await _isar.solicituds
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
  }

  Future<void> actualizarSolicitud(Solicitud solicitud) async {
    await _isar.writeTxn(() async {
      solicitud.isSynced = false; // Marcar como pendiente
      await _isar.solicituds.put(solicitud);
      await solicitud.comuna.save();
      await solicitud.consejoComunal.save();
      await solicitud.ubch.save();
      await solicitud.creador.save();
    });
  }

  Future<void> eliminarSolicitud(Id id) async {
    await _isar.writeTxn(() async {
      final solicitud = await _isar.solicituds.get(id);
      if (solicitud != null) {
        solicitud.isDeleted = true;
        solicitud.isSynced = false; // Marcar como pendiente para sincronizar eliminación
        await _isar.solicituds.put(solicitud);
      }
    });
  }

  Future<void> guardarSolicitud(Solicitud solicitud) async {
    await _isar.writeTxn(() async {
      await _isar.solicituds.put(solicitud);
      await solicitud.comuna.save();
      await solicitud.consejoComunal.save();
      await solicitud.ubch.save();
      await solicitud.creador.save();
    });
  }

  Future<Solicitud?> getSolicitudById(Id id) async {
    return await _isar.solicituds.get(id);
  }

  Future<void> deleteSolicitud(Id id) async {
    await _isar.writeTxn(() async {
      await _isar.solicituds.delete(id);
    });
  }
}