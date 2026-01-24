import 'package:isar/isar.dart';
import '../../../../models/models.dart';

class VinculacionRepository {
  final Isar _isar;

  VinculacionRepository(this._isar);

  Future<void> guardarVinculacion(Vinculacion vinculacion) async {
    await _isar.writeTxn(() async {
      await _isar.vinculacions.put(vinculacion);
      if (vinculacion.persona.value != null) {
        await vinculacion.persona.save();
      }
      if (vinculacion.organizacion.value != null) {
        await vinculacion.organizacion.save();
      }
    });
  }

  Future<List<Vinculacion>> getVinculacionesPorHabitante(Id habitanteId) async {
    final vinculaciones = await _isar.vinculacions
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    
    // Filtrar por habitante después de cargar las relaciones
    final result = <Vinculacion>[];
    for (var v in vinculaciones) {
      await v.persona.load();
      if (v.persona.value?.id == habitanteId) {
        await v.organizacion.load();
        result.add(v);
      }
    }
    
    return result;
  }

  Future<void> actualizarVinculacion(Vinculacion vinculacion) async {
    await _isar.writeTxn(() async {
      vinculacion.isSynced = false;
      await _isar.vinculacions.put(vinculacion);
      if (vinculacion.persona.value != null) {
        await vinculacion.persona.save();
      }
      if (vinculacion.organizacion.value != null) {
        await vinculacion.organizacion.save();
      }
    });
  }

  Future<void> eliminarVinculacion(Id id) async {
    await _isar.writeTxn(() async {
      final vinculacion = await _isar.vinculacions.get(id);
      if (vinculacion != null) {
        vinculacion.isDeleted = true;
        vinculacion.isSynced = false;
        await _isar.vinculacions.put(vinculacion);
      }
    });
  }

  /// Obtiene todas las vinculaciones de una organización específica
  Future<List<Vinculacion>> getVinculacionesPorOrganizacion(Id organizacionId) async {
    final vinculaciones = await _isar.vinculacions
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    
    // Filtrar por organización después de cargar las relaciones
    final result = <Vinculacion>[];
    for (var v in vinculaciones) {
      await v.organizacion.load();
      if (v.organizacion.value?.id == organizacionId) {
        await v.persona.load();
        result.add(v);
      }
    }
    
    return result;
  }

  /// Obtiene todas las vinculaciones de un consejo comunal específico
  Future<List<Vinculacion>> getVinculacionesPorConsejoComunal(Id consejoComunalId) async {
    final vinculaciones = await _isar.vinculacions
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    
    // Filtrar por consejo comunal después de cargar las relaciones
    final result = <Vinculacion>[];
    for (var v in vinculaciones) {
      await v.consejoComunal.load();
      if (v.consejoComunal.value?.id == consejoComunalId) {
        await v.persona.load();
        result.add(v);
      }
    }
    
    return result;
  }
}
