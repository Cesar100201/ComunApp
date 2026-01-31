import '../../models/models.dart';

/// Contrato del repositorio de habitantes. Implementado por Isar (móvil) o Firestore (web).
abstract class HabitanteRepository {
  Future<void> guardarHabitante(Habitante habitante);
  Future<List<Habitante>> obtenerTodos();
  Future<int> contar();
  Future<List<Habitante>> obtenerPaginado(int offset, int limit);
  Future<List<Habitante>> buscarPorTexto(String query, {int limit = 50});
  Future<void> actualizarHabitante(Habitante habitante);
  Future<void> eliminarHabitante(int id);
  Future<Habitante?> getHabitanteByCedula(int cedula);
  Future<Map<String, dynamic>?> buscarEnNube(int cedula);
}
