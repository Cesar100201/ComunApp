import '../../models/models.dart';

abstract class ConsejoRepository {
  Future<List<ConsejoComunal>> getAllConsejos();
  Future<List<ConsejoComunal>> getAllConsejosComunales();
  Future<List<ConsejoComunal>> buscarPorTexto(String query, {int limit = 50});
  Future<ConsejoComunal?> getConsejoComunalByCodigoSitur(String codigoSitur);
  Future<void> guardarConsejo(ConsejoComunal consejo);
  Future<void> actualizarConsejo(ConsejoComunal consejo);
  Future<void> eliminarConsejo(int id);
}
