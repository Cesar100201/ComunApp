import 'package:isar/isar.dart';
import '../../../../models/models.dart';

class OrganizacionRepository {
  final Isar _isar;

  OrganizacionRepository(this._isar);

  Future<List<Organizacion>> getAllOrganizaciones() async {
    return await _isar.organizacions.where().findAll();
  }

  Future<List<Organizacion>> getOrganizacionesByType(TipoOrganizacion tipo) async {
    return await _isar.organizacions.filter().tipoEqualTo(tipo).findAll();
  }

  Future<void> guardarOrganizacion(Organizacion organizacion) async {
    await _isar.writeTxn(() async {
      await _isar.organizacions.put(organizacion);
    });
  }

  Future<Organizacion?> getOrganizacionById(Id id) async {
    return await _isar.organizacions.get(id);
  }

  Future<void> deleteOrganizacion(Id id) async {
    await _isar.writeTxn(() async {
      await _isar.organizacions.delete(id);
    });
  }
}