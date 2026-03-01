List<String>? _listFromJson(dynamic value) {
  if (value == null) return null;
  final list = value as List<dynamic>;
  return list.map((e) => e as String).toList();
}

int _intFromJson(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

int? _intOrNullFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

DateTime _dateTimeFromJson(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is String) return DateTime.parse(value);
  if (value is DateTime) return value;
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.now();
}

DateTime? _dateTimeOrNullFromJson(dynamic value) {
  if (value == null) return null;
  if (value is String) return DateTime.parse(value);
  if (value is DateTime) return value;
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

/// Modelo local para registros de Control y Seguimiento.
/// Se persiste en un archivo JSON (no en Isar) para evitar conflictos de schema.
class ControlSeguimiento {
  int id;
  String categoria;
  DateTime fecha;
  /// Nombre corto de la actividad (string corto).
  String nombreActividad;
  String objetivo;
  String acciones;
  String mediosVerificacion;
  /// Rutas relativas. Por categoría: memoria fotográfica (solo fotos), listas de asistencia (fotos+pdf), actas (solo pdf).
  List<String> mediosVerificacionFotos;
  List<String> mediosVerificacionPdfs;
  List<String> memoriaFotografica;
  List<String> listasAsistenciaFotos;
  List<String> listasAsistenciaPdfs;
  List<String> actasPdfs;
  String producto;
  String estatus;
  /// Transformación (7T) seleccionadas, separadas por "; " (puede ser vacío).
  String transformacion7T;
  /// Plan de Gobierno 2025-2029 seleccionadas, separadas por "; " (puede ser vacío).
  String planGobierno2025;
  /// Cédula del habitante vinculado al perfil que hizo el registro (oculto en el formulario).
  int? cedulaCreador;
  /// Rango de la semana a la que pertenece la fecha seleccionada (oculto): inicio (domingo) y fin (sábado).
  DateTime? semanaInicio;
  DateTime? semanaFin;

  ControlSeguimiento({
    required this.id,
    required this.categoria,
    required this.fecha,
    this.nombreActividad = '',
    required this.objetivo,
    required this.acciones,
    required this.mediosVerificacion,
    this.mediosVerificacionFotos = const [],
    this.mediosVerificacionPdfs = const [],
    this.memoriaFotografica = const [],
    this.listasAsistenciaFotos = const [],
    this.listasAsistenciaPdfs = const [],
    this.actasPdfs = const [],
    required this.producto,
    required this.estatus,
    this.transformacion7T = '',
    this.planGobierno2025 = '',
    this.cedulaCreador,
    this.semanaInicio,
    this.semanaFin,
  });

  /// Calcula el rango de la semana (domingo a sábado) que contiene [fecha].
  static (DateTime inicio, DateTime fin) rangoSemanaPara(DateTime fecha) {
    final soloFecha = DateTime(fecha.year, fecha.month, fecha.day);
    // Dart: weekday 1 = lunes, 7 = domingo. Semana = domingo a sábado.
    final diasDesdeDomingo = soloFecha.weekday % 7; // 0 para domingo, 1 para lunes...
    final inicio = soloFecha.subtract(Duration(days: diasDesdeDomingo));
    final fin = inicio.add(const Duration(days: 6));
    return (inicio, fin);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoria': categoria,
        'fecha': fecha.toIso8601String(),
        'nombreActividad': nombreActividad,
        'objetivo': objetivo,
        'acciones': acciones,
        'mediosVerificacion': mediosVerificacion,
        'mediosVerificacionFotos': mediosVerificacionFotos,
        'mediosVerificacionPdfs': mediosVerificacionPdfs,
        'memoriaFotografica': memoriaFotografica,
        'listasAsistenciaFotos': listasAsistenciaFotos,
        'listasAsistenciaPdfs': listasAsistenciaPdfs,
        'actasPdfs': actasPdfs,
        'producto': producto,
        'estatus': estatus,
        'transformacion7T': transformacion7T,
        'planGobierno2025': planGobierno2025,
        'cedulaCreador': cedulaCreador,
        'semanaInicio': semanaInicio?.toIso8601String(),
        'semanaFin': semanaFin?.toIso8601String(),
      };

  factory ControlSeguimiento.fromJson(Map<String, dynamic> json) {
    return ControlSeguimiento(
      id: _intFromJson(json['id']),
      categoria: json['categoria'] as String? ?? '',
      fecha: _dateTimeFromJson(json['fecha']),
      nombreActividad: json['nombreActividad'] as String? ?? '',
      objetivo: json['objetivo'] as String? ?? '',
      acciones: json['acciones'] as String? ?? '',
      mediosVerificacion: json['mediosVerificacion'] as String? ?? '',
      mediosVerificacionFotos: (json['mediosVerificacionFotos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      mediosVerificacionPdfs: (json['mediosVerificacionPdfs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      memoriaFotografica: _listFromJson(json['memoriaFotografica']) ?? _listFromJson(json['mediosVerificacionFotos']) ?? [],
      listasAsistenciaFotos: _listFromJson(json['listasAsistenciaFotos']) ?? [],
      listasAsistenciaPdfs: _listFromJson(json['listasAsistenciaPdfs']) ?? _listFromJson(json['mediosVerificacionPdfs']) ?? [],
      actasPdfs: _listFromJson(json['actasPdfs']) ?? [],
      producto: json['producto'] as String? ?? '',
      estatus: json['estatus'] as String? ?? '',
      transformacion7T: json['transformacion7T'] as String? ?? '',
      planGobierno2025: json['planGobierno2025'] as String? ?? '',
      cedulaCreador: _intOrNullFromJson(json['cedulaCreador']),
      semanaInicio: _dateTimeOrNullFromJson(json['semanaInicio']),
      semanaFin: _dateTimeOrNullFromJson(json['semanaFin']),
    );
  }
}
