import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../core/utils/logger.dart';

/// Helper para gestionar la base de datos local Isar.
/// 
/// Implementa el patrón Singleton para asegurar una única instancia.
/// Maneja la inicialización y operaciones de auditoría.
class DbHelper {
  /// Instancia única del singleton
  static final DbHelper _instance = DbHelper._internal();
  
  /// Factory constructor que retorna la instancia única
  factory DbHelper() => _instance;
  
  /// Constructor privado para el singleton
  DbHelper._internal();

  /// Instancia de la base de datos Isar (async)
  late Future<Isar> db;

  /// Inicializa la base de datos local.
  /// 
  /// Abre o crea la instancia de Isar con todos los schemas necesarios.
  /// Si ya existe una instancia, la reutiliza.
  /// 
  /// Lanza excepciones si no se puede acceder al directorio de documentos
  /// o si hay problemas al abrir la base de datos.
  Future<void> init() async {
    try {
      db = _openDB();
      // Asegurar que la BD está lista esperando el Future
      await db;
      AppLogger.info('Base de datos Isar inicializada correctamente');
    } catch (e, stackTrace) {
      AppLogger.error('Error al inicializar base de datos', e, stackTrace);
      rethrow;
    }
  }

  /// Abre o obtiene la instancia de Isar.
  /// 
  /// Si no existe ninguna instancia, crea una nueva con todos los schemas.
  /// Si ya existe, retorna la instancia existente.
  Future<Isar> _openDB() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      
      if (Isar.instanceNames.isEmpty) {
        return await Isar.open(
          [
            HabitanteSchema,
            OrganizacionSchema,
            VinculacionSchema,
            ConsejoComunalSchema,
            ComunaSchema,
            ProyectoSchema,
            SeguimientoObraSchema,
            ClapSchema,
            SolicitudSchema,
            BitacoraSchema,
          ],
          directory: dir.path,
          inspector: true,
        );
      }
      
      // Si ya existe una instancia, obtenerla directamente
      final instance = Isar.getInstance();
      if (instance == null) {
        throw Exception('No se pudo obtener la instancia de Isar');
      }
      return instance;
    } catch (e, stackTrace) {
      AppLogger.error('Error al abrir base de datos Isar', e, stackTrace);
      rethrow;
    }
  }

  /// Registra una acción en la bitácora de auditoría.
  /// 
  /// Crea un registro de auditoría con la información de la acción realizada.
  /// 
  /// Parámetros:
  /// - [accion]: Descripción de la acción realizada (ej: "CREAR", "MODIFICAR", "ELIMINAR")
  /// - [tabla]: Nombre de la tabla afectada
  /// - [detalles]: Información adicional sobre la acción
  /// - [idUsuario]: ID del usuario responsable (opcional)
  /// 
  /// Si [idUsuario] es proporcionado, busca el habitante correspondiente
  /// y lo asocia al registro de auditoría.
  Future<void> registrarBitacora(
    String accion,
    String tabla,
    String detalles,
    int? idUsuario,
  ) async {
    try {
      final isar = await db;
      
      final nuevoRegistro = Bitacora()
        ..fechaHora = DateTime.now()
        ..accion = accion
        ..tablaAfectada = tabla
        ..detalles = detalles;
        
      if (idUsuario != null) {
        final usuario = await isar.habitantes.get(idUsuario);
        if (usuario != null) {
          nuevoRegistro.usuarioResponsable.value = usuario;
        } else {
          AppLogger.warning('Usuario con ID $idUsuario no encontrado para bitácora');
        }
      }

      await isar.writeTxn(() async {
        await isar.bitacoras.put(nuevoRegistro);
        if (idUsuario != null && nuevoRegistro.usuarioResponsable.value != null) {
          await nuevoRegistro.usuarioResponsable.save();
        }
      });

      AppLogger.debug('Bitácora registrada: $accion en $tabla');
    } catch (e, stackTrace) {
      AppLogger.error('Error al registrar bitácora', e, stackTrace);
      // No relanzamos el error para que las operaciones principales no fallen
      // por problemas de auditoría
    }
  }
}