import 'package:cloud_firestore/cloud_firestore.dart' hide Query;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:isar/isar.dart' hide Query;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore show Query;
import '../../database/db_helper.dart';
import '../../models/models.dart';
import '../utils/logger.dart';
import '../utils/constants.dart';
import 'sync_helpers.dart';

/// Servicio de sincronización bidireccional entre Isar (local) y Firebase (nube).
/// 
/// Maneja la sincronización de todas las colecciones del sistema:
/// - Comunas, Consejos Comunales, Organizaciones, CLAPs
/// - Habitantes, Proyectos, Solicitudes, Bitácora
/// 
/// Usa [SyncHelper] para operaciones genéricas y reduce código duplicado.
class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SyncHelper _syncHelper = SyncHelper();

  // ============================================================================
  // CONFIGURACIONES DE SINCRONIZACIÓN
  // ============================================================================

  /// Configuración para sincronizar Comunas.
  SyncConfig<Comuna> get _comunaConfig => SyncConfig<Comuna>(
    firebaseCollection: 'comunas',
    getDocumentId: (c) => c.codigoSitur,
    toFirebaseMap: (c) => {
      'codigoSitur': c.codigoSitur,
      'rif': c.rif ?? '',
      'codigoComElectoral': c.codigoComElectoral,
      'nombreComuna': c.nombreComuna,
      'municipio': c.municipio,
      'parroquia': c.parroquia.name,
      'latitud': c.latitud,
      'longitud': c.longitud,
    },
    fromFirebaseDoc: (isar, doc) async {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      
      final codigoSitur = data['codigoSitur'] as String? ?? doc.id;
      final local = await isar.comunas.filter().codigoSiturEqualTo(codigoSitur).findFirst();
      if (local != null && !local.isSynced) return null; // No sobrescribir cambios locales
      
      final comuna = local ?? Comuna();
      comuna.codigoSitur = codigoSitur;
      comuna.rif = data['rif'] as String?;
      comuna.codigoComElectoral = data['codigoComElectoral'] as String? ?? '';
      comuna.nombreComuna = data['nombreComuna'] as String? ?? '';
      comuna.municipio = data['municipio'] as String? ?? AppConstants.defaultMunicipality;
      comuna.latitud = (data['latitud'] as num?)?.toDouble() ?? 0.0;
      comuna.longitud = (data['longitud'] as num?)?.toDouble() ?? 0.0;
      comuna.parroquia = _parseParroquia(data['parroquia'] as String?);
      return comuna;
    },
    getPendingItems: (isar) => isar.comunas.filter().isSyncedEqualTo(false).findAll(),
    saveItem: (isar, item) => isar.comunas.put(item),
  );

  /// Configuración para sincronizar Consejos Comunales.
  SyncConfig<ConsejoComunal> get _consejoConfig => SyncConfig<ConsejoComunal>(
    firebaseCollection: 'consejosComunales',
    getDocumentId: (c) => c.codigoSitur,
    toFirebaseMap: (c) => {
      'codigoSitur': c.codigoSitur,
      'rif': c.rif ?? '',
      'nombreConsejo': c.nombreConsejo,
      'comunidades': c.comunidades,
      'latitud': c.latitud,
      'longitud': c.longitud,
      'comunaCodigoSitur': c.comuna.value?.codigoSitur,
      'tipoZona': c.tipoZona.name,
      'cargos': c.cargos.map((cargo) => {
        'nombreCargo': cargo.nombreCargo,
        'esUnico': cargo.esUnico,
      }).toList(),
    },
    fromFirebaseDoc: (isar, doc) async {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      
      final codigoSitur = data['codigoSitur'] as String? ?? doc.id;
      final local = await isar.consejoComunals.filter().codigoSiturEqualTo(codigoSitur).findFirst();
      if (local != null && !local.isSynced) return null;
      
      final consejo = local ?? ConsejoComunal();
      consejo.codigoSitur = codigoSitur;
      consejo.rif = data['rif'] as String?;
      consejo.nombreConsejo = data['nombreConsejo'] as String;
      consejo.comunidades = List<String>.from(data['comunidades'] ?? []);
      consejo.latitud = (data['latitud'] as num?)?.toDouble() ?? 0.0;
      consejo.longitud = (data['longitud'] as num?)?.toDouble() ?? 0.0;
      consejo.tipoZona = TipoZona.values.firstWhere(
        (t) => t.name == (data['tipoZona'] as String? ?? 'Urbano'),
        orElse: () => TipoZona.Urbano,
      );
      
      // Cargar cargos
      final cargosData = data['cargos'] as List<dynamic>?;
      if (cargosData != null) {
        consejo.cargos = cargosData.map((cargoMap) {
          final cargo = Cargo();
          cargo.nombreCargo = cargoMap['nombreCargo'] as String? ?? '';
          cargo.esUnico = cargoMap['esUnico'] as bool? ?? false;
          return cargo;
        }).toList();
      } else {
        consejo.cargos = [];
      }
      
      // Buscar comuna relacionada
      final comunaCodigoSitur = data['comunaCodigoSitur'] as String?;
      if (comunaCodigoSitur != null) {
        final comuna = await isar.comunas.filter().codigoSiturEqualTo(comunaCodigoSitur).findFirst();
        if (comuna != null) consejo.comuna.value = comuna;
      }
      return consejo;
    },
    getPendingItems: (isar) => isar.consejoComunals.filter().isSyncedEqualTo(false).findAll(),
    saveItem: (isar, item) => isar.consejoComunals.put(item),
    loadRelations: (c) => c.comuna.load(),
    saveRelations: (isar, item) async {
      if (item.comuna.value != null) await item.comuna.save();
    },
  );

  /// Configuración para sincronizar Organizaciones.
  SyncConfig<Organizacion> get _organizacionConfig => SyncConfig<Organizacion>(
    firebaseCollection: 'organizaciones',
    getDocumentId: (o) => 'ORG_${o.id}',
    toFirebaseMap: (o) => {
      'nombreLargo': o.nombreLargo,
      'abreviacion': o.abreviacion,
      'tipo': o.tipo.name,
    },
    fromFirebaseDoc: (isar, doc) async {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      
      Id? isarId;
      if (doc.id.startsWith('ORG_')) {
        isarId = int.tryParse(doc.id.replaceFirst('ORG_', ''));
      }
      
      Organizacion? local;
      if (isarId != null) local = await isar.organizacions.get(isarId);
      local ??= await isar.organizacions.filter()
          .nombreLargoEqualTo(data['nombreLargo'] as String).findFirst();
      
      if (local != null && !local.isSynced) return null;
      
      final org = local ?? Organizacion();
      org.nombreLargo = data['nombreLargo'] as String;
      org.abreviacion = data['abreviacion'] as String?;
      org.tipo = TipoOrganizacion.values.firstWhere(
        (t) => t.name == (data['tipo'] as String? ?? 'Politico'),
        orElse: () => TipoOrganizacion.Politico,
      );
      return org;
    },
    getPendingItems: (isar) => isar.organizacions.filter().isSyncedEqualTo(false).findAll(),
    saveItem: (isar, item) => isar.organizacions.put(item),
  );

  /// Configuración para sincronizar CLAPs.
  SyncConfig<Clap> get _clapConfig => SyncConfig<Clap>(
    firebaseCollection: 'claps',
    getDocumentId: (clap) => 'CLAP_${clap.id}',
    toFirebaseMap: (clap) => {
      'nombreClap': clap.nombreClap,
      'jefeComunidadCedula': clap.jefeComunidad.value?.cedula,
      'jefeComunidadNombre': clap.jefeComunidad.value?.nombreCompleto,
    },
    fromFirebaseDoc: (isar, doc) async {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      
      Id? isarId;
      if (doc.id.startsWith('CLAP_')) {
        isarId = int.tryParse(doc.id.replaceFirst('CLAP_', ''));
      }
      
      Clap? local;
      if (isarId != null) local = await isar.claps.get(isarId);
      local ??= await isar.claps.filter()
          .nombreClapEqualTo(data['nombreClap'] as String).findFirst();
      
      if (local != null && !local.isSynced) return null;
      
      final clap = local ?? Clap();
      clap.nombreClap = data['nombreClap'] as String;
      
      // Buscar jefe de comunidad
      final jefeCedula = data['jefeComunidadCedula'] as int?;
      if (jefeCedula != null) {
        final jefe = await isar.habitantes.filter().cedulaEqualTo(jefeCedula).findFirst();
        if (jefe != null) clap.jefeComunidad.value = jefe;
      }
      return clap;
    },
    getPendingItems: (isar) => isar.claps.filter().isSyncedEqualTo(false).findAll(),
    saveItem: (isar, item) => isar.claps.put(item),
    loadRelations: (clap) => clap.jefeComunidad.load(),
    saveRelations: (isar, item) async {
      if (item.jefeComunidad.value != null) await item.jefeComunidad.save();
    },
  );

  /// Configuración para sincronizar Proyectos.
  SyncConfig<Proyecto> get _proyectoConfig => SyncConfig<Proyecto>(
    firebaseCollection: 'proyectos',
    getDocumentId: (p) => 'PROJ_${p.id}_${p.nombreProyecto.replaceAll(' ', '')}',
    toFirebaseMap: (p) => {
      'nombreProyecto': p.nombreProyecto,
      'tipoObra': p.tipoObra,
      'montoAprobado': p.montoAprobado,
      'estatus': p.estatus.name,
      'transformacion': p.transformacion,
    },
    fromFirebaseDoc: (isar, doc) async {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      
      final nombreProyecto = data['nombreProyecto'] as String? ?? '';
      final local = await isar.proyectos.filter().nombreProyectoEqualTo(nombreProyecto).findFirst();
      if (local != null && !local.isSynced) return null;
      
      final proyecto = local ?? Proyecto();
      proyecto.nombreProyecto = nombreProyecto;
      proyecto.tipoObra = data['tipoObra'] as String? ?? '';
      proyecto.montoAprobado = (data['montoAprobado'] as num?)?.toDouble() ?? 0.0;
      proyecto.estatus = EstatusObra.values.firstWhere(
        (e) => e.name == (data['estatus'] as String? ?? 'PorIniciar'),
        orElse: () => EstatusObra.PorIniciar,
      );
      proyecto.transformacion = (data['transformacion'] as num?)?.toInt() ?? 1;
      return proyecto;
    },
    getPendingItems: (isar) => isar.proyectos.filter().isSyncedEqualTo(false).findAll(),
    saveItem: (isar, item) => isar.proyectos.put(item),
  );

  // ============================================================================
  // API PÚBLICA
  // ============================================================================

  /// Sincroniza todos los datos en orden lógico (BIDIRECCIONAL).
  /// 
  /// Primero sube cambios locales a la nube, luego descarga cambios de la nube.
  /// Retorna un mapa con 'subidos' y 'descargados'.
  /// 
  /// Lanza [SyncException] si no hay conexión a internet.
  /// Lanza [QuotaExceededException] si se excede la cuota de Firebase.
  Future<Map<String, int>> sincronizarTodo() async {
    // 1. Verificar Internet
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw SyncException('No hay conexión a internet');
    }

    int totalSubidos = 0;
    int totalDescargados = 0;

    try {
      // 2. Subir cambios locales a la nube (tablas maestras primero)
      AppLogger.info('Iniciando sincronización - Subiendo cambios...');
      
      totalSubidos += await _syncHelper.uploadPending(_comunaConfig);
      totalSubidos += await _syncHelper.uploadPending(_consejoConfig);
      totalSubidos += await _syncHelper.uploadPending(_organizacionConfig);
      totalSubidos += await _syncHelper.uploadPending(_clapConfig);
      totalSubidos += await _syncHabitantes();
      totalSubidos += await _syncHelper.uploadPending(_proyectoConfig);
      totalSubidos += await _syncSolicitudes();
      totalSubidos += await _syncBitacora();

      // 3. Descargar cambios de la nube al local (con paginación)
      AppLogger.info('Descargando cambios desde la nube...');
      
      totalDescargados += await _syncHelper.downloadWithPagination(_comunaConfig);
      totalDescargados += await _syncHelper.downloadWithPagination(_consejoConfig);
      totalDescargados += await _syncHelper.downloadWithPagination(_organizacionConfig);
      totalDescargados += await _syncHelper.downloadWithPagination(_clapConfig);
      totalDescargados += await _downloadHabitantes();
      totalDescargados += await _syncHelper.downloadWithPagination(_proyectoConfig);
      totalDescargados += await _downloadSolicitudes();

      AppLogger.info('Sincronización completada: $totalSubidos subidos, $totalDescargados descargados');
    } catch (e, stackTrace) {
      // Detectar error de cuota excedida
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('resource_exhausted') || 
          errorStr.contains('quota exceeded') ||
          (errorStr.contains('quota') && errorStr.contains('exceeded'))) {
        
        // Contar registros pendientes
        final isar = await DbHelper().db;
        final pendientes = await isar.habitantes.filter().isSyncedEqualTo(false).count();
        
        AppLogger.warning('⚠️ CUOTA DE FIREBASE EXCEDIDA');
        AppLogger.info('Registros subidos antes del error: $totalSubidos');
        AppLogger.info('Registros pendientes: $pendientes');
        
        throw QuotaExceededException(
          'Se ha excedido la cuota diaria de Firebase. Intente nuevamente mañana.',
          registrosSubidos: totalSubidos,
          registrosPendientes: pendientes,
        );
      }
      
      AppLogger.error('Error durante sincronización', e, stackTrace);
      rethrow;
    }

    return {
      'subidos': totalSubidos,
      'descargados': totalDescargados,
    };
  }
  
  /// Obtiene el conteo de registros pendientes por sincronizar
  Future<Map<String, int>> obtenerPendientes() async {
    final isar = await DbHelper().db;
    
    return {
      'habitantes': await isar.habitantes.filter().isSyncedEqualTo(false).count(),
      'comunas': await isar.comunas.filter().isSyncedEqualTo(false).count(),
      'consejos': await isar.consejoComunals.filter().isSyncedEqualTo(false).count(),
      'organizaciones': await isar.organizacions.filter().isSyncedEqualTo(false).count(),
      'claps': await isar.claps.filter().isSyncedEqualTo(false).count(),
      'proyectos': await isar.proyectos.filter().isSyncedEqualTo(false).count(),
      'solicitudes': await isar.solicituds.filter().isSyncedEqualTo(false).count(),
    };
  }

  // ============================================================================
  // HABITANTES (Caso especial por complejidad)
  // ============================================================================

  Future<int> _syncHabitantes() async {
    final isar = await DbHelper().db;
    final pendientes = await isar.habitantes.filter().isSyncedEqualTo(false).findAll();
    if (pendientes.isEmpty) return 0;

    int count = 0;
    const batchSize = AppConstants.batchSize;
    
    for (int i = 0; i < pendientes.length; i += batchSize) {
      final lote = pendientes.skip(i).take(batchSize).toList();
      final batch = _firestore.batch();
      final paraMarcar = <Habitante>[];

      final docRefs = lote.map((h) => _firestore.collection('habitantes').doc(h.cedula.toString())).toList();
      final snapshots = await Future.wait(docRefs.map((ref) => ref.get()));

      for (int j = 0; j < lote.length; j++) {
        final h = lote[j];
        final docRef = docRefs[j];
        final docSnapshot = snapshots[j];

        try {
          if (h.isDeleted) {
            if (docSnapshot.exists) batch.delete(docRef);
            paraMarcar.add(h);
            count++;
            continue;
          }

          final data = {
            'cedula': h.cedula,
            'nacionalidad': h.nacionalidad.name,
            'nombreCompleto': h.nombreCompleto,
            'telefono': h.telefono,
            'fechaNacimiento': Timestamp.fromDate(h.fechaNacimiento),
            'genero': h.genero.name,
            'direccion': h.direccion,
            'estatusPolitico': h.estatusPolitico.name,
            'nivelVoto': h.nivelVoto.name,
            'nivelUsuario': h.nivelUsuario,
            'fotoUrl': h.fotoUrl,
            'ultimaActualizacion': FieldValue.serverTimestamp(),
          };

          docSnapshot.exists ? batch.update(docRef, data) : batch.set(docRef, data);
          paraMarcar.add(h);
          count++;
        } catch (e) {
          AppLogger.warning('Error preparando habitante ${h.cedula}: $e');
        }
      }

      await _commitHabitantesBatch(isar, batch, paraMarcar);
    }
    
    AppLogger.debug('_syncHabitantes: Subidos $count habitantes');
    return count;
  }

  Future<void> _commitHabitantesBatch(Isar isar, WriteBatch batch, List<Habitante> items) async {
    if (items.isEmpty) return;
    
    try {
      await batch.commit();
      await isar.writeTxn(() async {
        for (var h in items) {
          h.isSynced = true;
          await isar.habitantes.put(h);
        }
      });
    } catch (e) {
      // Detectar error de cuota excedida
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('resource_exhausted') || 
          errorStr.contains('quota exceeded') ||
          errorStr.contains('quota') && errorStr.contains('exceeded')) {
        AppLogger.warning('⚠️ CUOTA DE FIREBASE EXCEDIDA - Deteniendo sincronización');
        rethrow; // Propagar para que sincronizarTodo lo maneje
      }
      
      AppLogger.error('Error en batch de habitantes', e);
      // Fallback: intentar uno por uno
      for (var h in items) {
        try {
          final docRef = _firestore.collection('habitantes').doc(h.cedula.toString());
          final data = {
            'cedula': h.cedula,
            'nacionalidad': h.nacionalidad.name,
            'nombreCompleto': h.nombreCompleto,
            'telefono': h.telefono,
            'fechaNacimiento': Timestamp.fromDate(h.fechaNacimiento),
            'genero': h.genero.name,
            'direccion': h.direccion,
            'estatusPolitico': h.estatusPolitico.name,
            'nivelVoto': h.nivelVoto.name,
            'nivelUsuario': h.nivelUsuario,
            'fotoUrl': h.fotoUrl,
            'ultimaActualizacion': FieldValue.serverTimestamp(),
          };
          await docRef.set(data, SetOptions(merge: true));
          await isar.writeTxn(() async {
            h.isSynced = true;
            await isar.habitantes.put(h);
          });
        } catch (e2) {
          // También verificar cuota en fallback
          final errorStr2 = e2.toString().toLowerCase();
          if (errorStr2.contains('resource_exhausted') || errorStr2.contains('quota')) {
            AppLogger.warning('⚠️ CUOTA DE FIREBASE EXCEDIDA en fallback');
            rethrow;
          }
          AppLogger.warning('Error subiendo habitante ${h.cedula} (fallback): $e2');
        }
      }
    }
  }

  Future<int> _downloadHabitantes() async {
    final isar = await DbHelper().db;
    int count = 0;
    DocumentSnapshot? lastDoc;
    const pageSize = AppConstants.defaultPageSize;

    try {
      while (true) {
        firestore.Query<Map<String, dynamic>> query = _firestore
            .collection('habitantes')
            .limit(pageSize);

        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }

        final snapshot = await query.get().timeout(AppConstants.syncTimeout);
        if (snapshot.docs.isEmpty) break;

        for (var doc in snapshot.docs) {
          try {
            final data = doc.data();
            final cedula = (data['cedula'] as num?)?.toInt() ?? int.tryParse(doc.id) ?? 0;
            if (cedula == 0) continue;

            final local = await isar.habitantes.filter().cedulaEqualTo(cedula).findFirst();
            if (local != null && !local.isSynced) continue;

            final habitante = local ?? Habitante();
            habitante.cedula = cedula;
            habitante.nacionalidad = Nacionalidad.values.firstWhere(
              (n) => n.name == (data['nacionalidad'] as String? ?? 'V'),
              orElse: () => Nacionalidad.V,
            );
            habitante.nombreCompleto = data['nombreCompleto'] as String;
            habitante.telefono = data['telefono'] as String;
            habitante.direccion = data['direccion'] as String? ?? '';
            habitante.fotoUrl = data['fotoUrl'] as String?;
            habitante.nivelUsuario = (data['nivelUsuario'] as num?)?.toInt() ?? 1;
            
            final fechaNacTimestamp = data['fechaNacimiento'] as Timestamp?;
            habitante.fechaNacimiento = fechaNacTimestamp?.toDate() ?? AppConstants.defaultBirthDate;
            
            habitante.genero = Genero.values.firstWhere(
              (g) => g.name == (data['genero'] as String? ?? 'Masculino'),
              orElse: () => Genero.Masculino,
            );
            habitante.estatusPolitico = EstatusPolitico.values.firstWhere(
              (e) => e.name == (data['estatusPolitico'] as String? ?? 'Neutral'),
              orElse: () => EstatusPolitico.Neutral,
            );
            habitante.nivelVoto = NivelVoto.values.firstWhere(
              (n) => n.name == (data['nivelVoto'] as String? ?? 'Blando'),
              orElse: () => NivelVoto.Blando,
            );
            habitante.isSynced = true;
            habitante.isDeleted = false;

            await isar.writeTxn(() => isar.habitantes.put(habitante));
            count++;
          } catch (e) {
            AppLogger.warning('Error descargando habitante ${doc.id}: $e');
          }
        }

        lastDoc = snapshot.docs.last;
        if (snapshot.docs.length < pageSize) break;
      }
    } catch (e) {
      AppLogger.error('Error en _downloadHabitantes', e);
    }

    return count;
  }

  // ============================================================================
  // SOLICITUDES (Caso especial por múltiples relaciones)
  // ============================================================================

  Future<int> _syncSolicitudes() async {
    final isar = await DbHelper().db;
    final pendientes = await isar.solicituds.filter().isSyncedEqualTo(false).findAll();
    if (pendientes.isEmpty) return 0;

    int count = 0;
    const batchSize = AppConstants.batchSize;
    
    for (int i = 0; i < pendientes.length; i += batchSize) {
      final lote = pendientes.skip(i).take(batchSize).toList();
      final batch = _firestore.batch();
      final paraMarcar = <Solicitud>[];

      // Cargar todas las relaciones
      await Future.wait(lote.map((s) async {
        await s.comuna.load();
        await s.consejoComunal.load();
        await s.ubch.load();
        await s.creador.load();
      }));

      final docRefs = lote.map((s) => _firestore.collection('solicitudes').doc('SOL_${s.id}')).toList();
      final snapshots = await Future.wait(docRefs.map((ref) => ref.get()));

      for (int j = 0; j < lote.length; j++) {
        final s = lote[j];
        final docRef = docRefs[j];
        final docSnapshot = snapshots[j];

        try {
          if (s.isDeleted) {
            if (docSnapshot.exists) batch.delete(docRef);
            paraMarcar.add(s);
            count++;
            continue;
          }

          final data = {
            'idSolicitud': s.idSolicitud,
            'comunaId': s.comuna.value?.id,
            'comunaNombre': s.comuna.value?.nombreComuna,
            'consejoComunalId': s.consejoComunal.value?.id,
            'consejoComunalNombre': s.consejoComunal.value?.nombreConsejo,
            'comunidad': s.comunidad,
            'ubchId': s.ubch.value?.id,
            'ubchNombre': s.ubch.value?.nombreLargo,
            'creadorCedula': s.creador.value?.cedula,
            'creadorNombre': s.creador.value?.nombreCompleto,
            'tipoSolicitud': s.tipoSolicitud.name,
            'otrosTipoSolicitud': s.otrosTipoSolicitud,
            'descripcion': s.descripcion,
            'cantidadLuminarias': s.cantidadLuminarias,
            'ultimaActualizacion': FieldValue.serverTimestamp(),
          };

          docSnapshot.exists ? batch.update(docRef, data) : batch.set(docRef, data);
          paraMarcar.add(s);
          count++;
        } catch (e) {
          AppLogger.warning('Error preparando solicitud ${s.id}: $e');
        }
      }

      await _commitSolicitudesBatch(isar, batch, paraMarcar);
    }
    
    return count;
  }

  Future<void> _commitSolicitudesBatch(Isar isar, WriteBatch batch, List<Solicitud> items) async {
    if (items.isEmpty) return;
    try {
      await batch.commit();
      await isar.writeTxn(() async {
        for (var s in items) {
          s.isSynced = true;
          await isar.solicituds.put(s);
        }
      });
    } catch (e) {
      AppLogger.error('Error en batch de solicitudes', e);
    }
  }

  Future<int> _downloadSolicitudes() async {
    final isar = await DbHelper().db;
    int count = 0;
    DocumentSnapshot? lastDoc;
    const pageSize = AppConstants.defaultPageSize;

    try {
      while (true) {
        firestore.Query<Map<String, dynamic>> query = _firestore
            .collection('solicitudes')
            .limit(pageSize);

        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }

        final snapshot = await query.get().timeout(AppConstants.networkTimeout);
        if (snapshot.docs.isEmpty) break;

        for (var doc in snapshot.docs) {
          try {
            final data = doc.data();
            final idSolicitud = (data['idSolicitud'] as num?)?.toInt();
            if (idSolicitud == null) continue;

            final local = await isar.solicituds.filter().idSolicitudEqualTo(idSolicitud).findFirst();
            if (local != null && !local.isSynced) continue;

            // Buscar relaciones
            final comunaId = (data['comunaId'] as num?)?.toInt();
            final consejoComunalId = (data['consejoComunalId'] as num?)?.toInt();
            final ubchId = (data['ubchId'] as num?)?.toInt();
            final creadorCedula = (data['creadorCedula'] as num?)?.toInt();

            Comuna? comuna = comunaId != null ? await isar.comunas.get(comunaId) : null;
            comuna ??= data['comunaNombre'] != null 
                ? await isar.comunas.filter().nombreComunaEqualTo(data['comunaNombre'] as String).findFirst() 
                : null;

            ConsejoComunal? consejo = consejoComunalId != null ? await isar.consejoComunals.get(consejoComunalId) : null;
            consejo ??= data['consejoComunalNombre'] != null 
                ? await isar.consejoComunals.filter().nombreConsejoEqualTo(data['consejoComunalNombre'] as String).findFirst() 
                : null;

            Organizacion? ubch = ubchId != null ? await isar.organizacions.get(ubchId) : null;
            ubch ??= data['ubchNombre'] != null 
                ? await isar.organizacions.filter().nombreLargoEqualTo(data['ubchNombre'] as String).findFirst() 
                : null;

            Habitante? creador = creadorCedula != null 
                ? await isar.habitantes.filter().cedulaEqualTo(creadorCedula).findFirst() 
                : null;

            final solicitud = local ?? Solicitud();
            solicitud.idSolicitud = idSolicitud;
            solicitud.comunidad = data['comunidad'] as String? ?? '';
            solicitud.descripcion = data['descripcion'] as String? ?? '';
            solicitud.cantidadLuminarias = (data['cantidadLuminarias'] as num?)?.toInt();
            solicitud.otrosTipoSolicitud = data['otrosTipoSolicitud'] as String?;
            solicitud.tipoSolicitud = TipoSolicitud.values.firstWhere(
              (t) => t.name == (data['tipoSolicitud'] as String? ?? 'Otros'),
              orElse: () => TipoSolicitud.Otros,
            );

            if (comuna != null) solicitud.comuna.value = comuna;
            if (consejo != null) solicitud.consejoComunal.value = consejo;
            if (ubch != null) solicitud.ubch.value = ubch;
            if (creador != null) solicitud.creador.value = creador;

            solicitud.isSynced = true;
            solicitud.isDeleted = false;

            await isar.writeTxn(() async {
              await isar.solicituds.put(solicitud);
              if (comuna != null) await solicitud.comuna.save();
              if (consejo != null) await solicitud.consejoComunal.save();
              if (ubch != null) await solicitud.ubch.save();
              if (creador != null) await solicitud.creador.save();
            });
            count++;
          } catch (e) {
            AppLogger.warning('Error descargando solicitud ${doc.id}: $e');
          }
        }

        lastDoc = snapshot.docs.last;
        if (snapshot.docs.length < pageSize) break;
      }
    } catch (e) {
      AppLogger.error('Error en _downloadSolicitudes', e);
    }

    return count;
  }

  // ============================================================================
  // BITÁCORA (Solo subida - auditoría)
  // ============================================================================

  Future<int> _syncBitacora() async {
    final isar = await DbHelper().db;
    final logsPendientes = await isar.bitacoras.filter().isSyncedEqualTo(false).findAll();
    if (logsPendientes.isEmpty) return 0;

    int count = 0;
    final batch = _firestore.batch();

    for (var log in logsPendientes) {
      await log.usuarioResponsable.load();
      
      final docRef = _firestore.collection('auditoria_logs').doc();
      batch.set(docRef, {
        'fechaHora': Timestamp.fromDate(log.fechaHora),
        'accion': log.accion,
        'tablaAfectada': log.tablaAfectada,
        'detalles': log.detalles,
        'usuarioResponsable': log.usuarioResponsable.value?.nombreCompleto ?? 'Desconocido',
        'usuarioCedula': log.usuarioResponsable.value?.cedula ?? 0,
      });
      count++;
    }

    if (count > 0) {
      await batch.commit();
      await isar.writeTxn(() async {
        for (var log in logsPendientes) {
          log.isSynced = true;
          await isar.bitacoras.put(log);
        }
      });
    }
    return count;
  }

  // ============================================================================
  // FUNCIONES AUXILIARES
  // ============================================================================

  /// Parsea un string a Parroquia.
  Parroquia _parseParroquia(String? value) {
    if (value == null) return Parroquia.LaFria;
    return Parroquia.values.firstWhere(
      (p) => p.name == value,
      orElse: () => Parroquia.LaFria,
    );
  }
}
