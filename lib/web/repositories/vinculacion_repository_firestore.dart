import '../../core/contracts/vinculacion_repository.dart';
import '../../models/models.dart';

/// Implementación Firestore de [VinculacionRepository]. Solo se usa en builds web.
/// Retorna listas vacías por ahora; se puede extender con colección Firestore.
class VinculacionRepositoryFirestore implements VinculacionRepository {
  @override
  Future<List<Vinculacion>> getVinculacionesPorHabitante(int habitanteId) async {
    return [];
  }

  @override
  Future<void> guardarVinculacion(Vinculacion vinculacion) async {}

  @override
  Future<void> actualizarVinculacion(Vinculacion vinculacion) async {}

  @override
  Future<void> eliminarVinculacion(int id) async {}
}
