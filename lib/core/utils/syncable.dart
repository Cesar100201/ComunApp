/// Interfaz para entidades sincronizables.
/// 
/// Todas las entidades que se sincronizan con Firebase deben implementar
/// esta interfaz para poder usar los helpers genéricos de sincronización.
abstract class Syncable {
  bool get isSynced;
  set isSynced(bool value);
  
  bool get isDeleted;
  set isDeleted(bool value);
}
