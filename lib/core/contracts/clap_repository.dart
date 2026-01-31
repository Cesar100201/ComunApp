import '../../models/models.dart';

abstract class ClapRepository {
  Future<List<Clap>> obtenerTodos();
  Future<Clap?> buscarPorId(int id);
  Future<void> guardarClap(Clap clap);
  Future<void> actualizarClap(Clap clap);
  Future<void> eliminarClap(int id);
}
