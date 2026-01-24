import 'package:isar/isar.dart';
import '../core/utils/syncable.dart';

part 'models.g.dart';

// ==========================================
// ENUMS (Listas Fijas)
// ==========================================

enum Nacionalidad { V, E }
enum Genero { Masculino, Femenino }
enum EstatusPolitico { Chavista, Opositor, Neutral, OpositorSimpatizante, OpositorNacionalista }
enum NivelVoto { Duro, Blando, Opositor }
enum TipoOrganizacion { Politico, Institucional, Social, Cultural, Deportiva }
enum Ambito { Comunal, Parroquial, Municipal, Regional, Nacional }
enum Parroquia { LaFria, BocaDeGrita, JoseAntonioPaez }
enum TipoZona { Rural, Urbano, Mixto }
enum EstatusObra { PorIniciar, EnEjecucion, Paralizada, Culminada }
enum TipoSolicitud { Agua, Electrico, Iluminacion, Otros }
enum EstatusReporte { Completo, Parcial }

// ==========================================
// MODELOS EMBEBIDOS
// ==========================================

@embedded
class Cargo {
  late String nombreCargo;
  late bool esUnico; // Si es true, solo una persona puede ocupar este cargo
}

// ==========================================
// COLECCIONES (TABLAS)
// ==========================================

@collection
class Habitante implements Syncable {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late int cedula;

  @Enumerated(EnumType.name)
  late Nacionalidad nacionalidad;

  late String nombreCompleto;
  late String telefono;
  late DateTime fechaNacimiento;
  
  @Enumerated(EnumType.name)
  late Genero genero;

  late String direccion;
  late String? fotoUrl; // URL de Firebase Storage

  @Enumerated(EnumType.name)
  late EstatusPolitico estatusPolitico;

  @Enumerated(EnumType.name)
  late NivelVoto nivelVoto;

  late int nivelUsuario; // 1=Admin, 2=Catastro, etc.

  // --- RELACIONES ---
  final consejoComunal = IsarLink<ConsejoComunal>();
  final clap = IsarLink<Clap>();

  // NUEVO: Núcleo Familiar (Apunta al Jefe de Hogar)
  // Si este campo está vacío, asumimos que él es su propio jefe o vive solo.
  final jefeDeFamilia = IsarLink<Habitante>(); 
  
  @Index()
  bool isSynced = false;
  
  @Index()
  bool isDeleted = false;
}

@collection
class Organizacion implements Syncable {
  Id id = Isar.autoIncrement;
  late String nombreLargo;
  late String? abreviacion;
  @Enumerated(EnumType.name)
  late TipoOrganizacion tipo;
  late List<Cargo> cargos = []; // Lista de cargos disponibles en esta organización
  
  @Index()
  bool isSynced = false;
  
  @Index()
  bool isDeleted = false;
}

@collection
class Vinculacion implements Syncable {
  Id id = Isar.autoIncrement;
  late String cargo;
  @Enumerated(EnumType.name)
  late Ambito ambito;
  late bool activo;
  final persona = IsarLink<Habitante>();
  final organizacion = IsarLink<Organizacion>();
  final consejoComunal = IsarLink<ConsejoComunal>(); // Vinculación a consejo comunal (opcional)
  
  @Index()
  bool isSynced = false;
  
  @Index()
  bool isDeleted = false;
}

@collection
class ConsejoComunal implements Syncable {
  Id id = Isar.autoIncrement;
  @Index(unique: true)
  late String codigoSitur;
  late String? rif;
  late String nombreConsejo;
  late List<String> comunidades;
  @Enumerated(EnumType.name)
  late TipoZona tipoZona = TipoZona.Urbano;
  late double latitud;
  late double longitud;
  late List<Cargo> cargos = []; // Lista de cargos de la estructura organizativa del consejo
  final comuna = IsarLink<Comuna>();
  
  @Index()
  bool isSynced = false;
  
  @Index()
  bool isDeleted = false;
}

@collection
class Comuna implements Syncable {
  Id id = Isar.autoIncrement;
  @Index(unique: true)
  late String codigoSitur;
  late String? rif;
  late String codigoComElectoral;
  late String nombreComuna;
  late String municipio = "García de Hevia";
  @Enumerated(EnumType.name)
  late Parroquia parroquia;
  late double latitud;
  late double longitud;
  
  @Index()
  bool isSynced = false;
  
  @Index()
  bool isDeleted = false;
}

@collection
class Proyecto implements Syncable {
  Id id = Isar.autoIncrement;
  late String nombreProyecto;
  late String tipoObra;
  late double montoAprobado;
  @Enumerated(EnumType.name)
  late EstatusObra estatus;
  late int transformacion; // 1 al 7
  final consejoBeneficiario = IsarLink<ConsejoComunal>();
  final consejoEjecutor = IsarLink<ConsejoComunal>(); 
  
  @Index()
  bool isSynced = false;
  
  @Index()
  bool isDeleted = false;
}

@collection
class SeguimientoObra implements Syncable {
  Id id = Isar.autoIncrement;
  late DateTime fechaReporte;
  late int porcentajeAvance;
  late String? comentario;
  late String? evidenciaFotoUrl;
  final proyecto = IsarLink<Proyecto>();
  final inspector = IsarLink<Habitante>();
  
  @Index()
  bool isSynced = false;
  
  @Index()
  bool isDeleted = false;
}

@collection
class Clap implements Syncable {
  Id id = Isar.autoIncrement;
  late String nombreClap;
  final jefeComunidad = IsarLink<Habitante>();
  
  @Index()
  bool isSynced = false;
  
  @Index()
  bool isDeleted = false;
}

@collection
class Solicitud implements Syncable {
  Id id = Isar.autoIncrement;

  late int idSolicitud;

  final comuna = IsarLink<Comuna>();
  final consejoComunal = IsarLink<ConsejoComunal>();
  late String comunidad;

  final ubch = IsarLink<Organizacion>();

  final creador = IsarLink<Habitante>();
  @Enumerated(EnumType.name)
  late TipoSolicitud tipoSolicitud;
  late String? otrosTipoSolicitud;
  late String descripcion;
  int? cantidadLamparas;
  int? cantidadBombillos;

  @Index()
  late bool isSynced = false;
  
  @Index()
  bool isDeleted = false;
}

// NUEVA TABLA: BITÁCORA (Auditoría de Seguridad)
@collection
class Bitacora implements Syncable {
  Id id = Isar.autoIncrement;

  late DateTime fechaHora;
  
  late String accion; // Ej: "Crear Proyecto", "Eliminar Usuario"
  late String tablaAfectada; // Ej: "Habitante", "Proyecto"
  late String detalles; // Descripción breve: "Cambió estatus a Opositor"

  // ¿Quién hizo la acción?
  final usuarioResponsable = IsarLink<Habitante>();
  
  @Index()
  bool isSynced = false;
  
  @Index()
  bool isDeleted = false;
}

// TABLA: REPORTES DE SOLUCIÓN
@collection
class Reporte implements Syncable {
  Id id = Isar.autoIncrement;

  late DateTime fechaReporte;
  
  @Enumerated(EnumType.name)
  late EstatusReporte estatusReporte; // Completo o Parcial
  
  late int? luminariasEntregadas;
  
  late String descripcion; // Descripción detallada de lo que se hizo y no se hizo
  
  // Fotos del reporte (URLs de Firebase Storage o rutas locales)
  late List<String> fotosUrls = [];
  
  // Relación con la solicitud reportada
  final solicitud = IsarLink<Solicitud>();
  
  // Organizaciones vinculadas que participaron en la solución
  final organizacionesVinculadas = IsarLinks<Organizacion>();
  
  // Usuario que creó el reporte
  final creador = IsarLink<Habitante>();
  
  @Index()
  bool isSynced = false;
  
  @Index()
  bool isDeleted = false;
}