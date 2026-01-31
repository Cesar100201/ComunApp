import '../../models/models.dart';

abstract class VinculacionRepository {
  Future<List<Vinculacion>> getVinculacionesPorHabitante(int habitanteId);
  Future<void> guardarVinculacion(Vinculacion vinculacion);
  Future<void> actualizarVinculacion(Vinculacion vinculacion);
  Future<void> eliminarVinculacion(int id);
}
