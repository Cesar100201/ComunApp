import 'package:isar/isar.dart';
import '../../../../models/models.dart';

class ReporteRepository {
  final Isar _isar;

  ReporteRepository(this._isar);

  Future<List<Reporte>> getAllReportes() async {
    return await _isar.reportes
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
  }

  Future<void> guardarReporte(Reporte reporte) async {
    await _isar.writeTxn(() async {
      await _isar.reportes.put(reporte);
      await reporte.solicitud.save();
      await reporte.organizacionesVinculadas.save();
      await reporte.creador.save();
    });
  }

  Future<void> actualizarReporte(Reporte reporte) async {
    await _isar.writeTxn(() async {
      reporte.isSynced = false; // Marcar como pendiente
      await _isar.reportes.put(reporte);
      await reporte.solicitud.save();
      await reporte.organizacionesVinculadas.save();
      await reporte.creador.save();
    });
  }

  Future<void> eliminarReporte(Id id) async {
    await _isar.writeTxn(() async {
      final reporte = await _isar.reportes.get(id);
      if (reporte != null) {
        reporte.isDeleted = true;
        reporte.isSynced = false; // Marcar como pendiente para sincronizar eliminación
        await _isar.reportes.put(reporte);
      }
    });
  }

  Future<Reporte?> getReporteById(Id id) async {
    return await _isar.reportes.get(id);
  }

  Future<Reporte?> getReporteBySolicitudId(Id solicitudId) async {
    return await _isar.reportes
        .filter()
        .isDeletedEqualTo(false)
        .findFirst();
  }

  Future<List<Reporte>> getReportesBySolicitud(Id solicitudId) async {
    final reportes = await getAllReportes();
    final result = <Reporte>[];
    
    for (var reporte in reportes) {
      await reporte.solicitud.load();
      if (reporte.solicitud.value?.id == solicitudId) {
        result.add(reporte);
      }
    }
    
    return result;
  }
}
