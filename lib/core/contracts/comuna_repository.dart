import '../../models/models.dart';

abstract class ComunaRepository {
  Future<List<Comuna>> getAllComunas();
  Future<Comuna?> getComunaByCodigoSitur(String codigoSitur);
  Future<List<ConsejoComunal>> getConsejosComunalesByComunaId(int comunaId);
  Future<void> guardarComuna(Comuna comuna);
  Future<void> actualizarComuna(Comuna comuna);
  Future<void> eliminarComuna(int id);
}
