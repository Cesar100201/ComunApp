import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/services/user_role_service.dart';
import '../../../../database/db_helper.dart';
import '../../../../models/models.dart';

/// Pantalla que lista todos los registros pendientes de subir a la nube
/// y permite subir cada uno individualmente.
class PendientesSyncPage extends StatefulWidget {
  const PendientesSyncPage({super.key});

  @override
  State<PendientesSyncPage> createState() => _PendientesSyncPageState();
}

class _PendientesSyncPageState extends State<PendientesSyncPage> {
  final SyncService _syncService = SyncService();
  final UserRoleService _roleService = UserRoleService();
  bool _loading = true;
  List<Habitante> _habitantes = [];
  List<Comuna> _comunas = [];
  List<ConsejoComunal> _consejos = [];
  List<Organizacion> _organizaciones = [];
  List<Clap> _claps = [];
  List<Proyecto> _proyectos = [];
  List<Solicitud> _solicitudes = [];
  List<Extranjero> _extranjeros = [];
  final Set<String> _subiendo = {};
  bool _canUpload = false;

  @override
  void initState() {
    super.initState();
    _cargarPendientes();
    _roleService.getNivelUsuario().then((n) {
      if (mounted)
        setState(() => _canUpload = _roleService.canAccessRegistros(n));
    });
  }

  Future<void> _cargarPendientes() async {
    setState(() => _loading = true);
    try {
      final isar = await DbHelper().db;
      // Isar 3.1: usar buildQuery<R>() para obtener Query y ejecutar findAll() (evita problemas con QueryBuilder.findAll)
      final habitantesRaw = await isar.habitantes
          .buildQuery<Habitante>()
          .findAll();
      _habitantes = habitantesRaw
          .where((h) => !h.isSynced && !h.isDeleted)
          .toList();
      final comunasRaw = await isar.comunas.buildQuery<Comuna>().findAll();
      _comunas = comunasRaw.where((c) => !c.isSynced && !c.isDeleted).toList();
      final consejosRaw = await isar.consejoComunals
          .buildQuery<ConsejoComunal>()
          .findAll();
      _consejos = consejosRaw
          .where((c) => !c.isSynced && !c.isDeleted)
          .toList();
      final orgsRaw = await isar.organizacions
          .buildQuery<Organizacion>()
          .findAll();
      _organizaciones = orgsRaw
          .where((o) => !o.isSynced && !o.isDeleted)
          .toList();
      final clapsRaw = await isar.claps.buildQuery<Clap>().findAll();
      _claps = clapsRaw.where((c) => !c.isSynced && !c.isDeleted).toList();
      final proyRaw = await isar.proyectos.buildQuery<Proyecto>().findAll();
      _proyectos = proyRaw.where((p) => !p.isSynced && !p.isDeleted).toList();
      final solRaw = await isar.solicituds.buildQuery<Solicitud>().findAll();
      _solicitudes = solRaw.where((s) => !s.isSynced && !s.isDeleted).toList();
      final extRaw = await isar.extranjeros.buildQuery<Extranjero>().findAll();
      _extranjeros = extRaw.where((e) => !e.isSynced && !e.isDeleted).toList();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _total =>
      _habitantes.length +
      _comunas.length +
      _consejos.length +
      _organizaciones.length +
      _claps.length +
      _proyectos.length +
      _solicitudes.length +
      _extranjeros.length;

  Future<void> _subirHabitante(Habitante h) async {
    final key = 'H-${h.cedula}';
    if (_subiendo.contains(key)) return;
    setState(() => _subiendo.add(key));
    try {
      final ok = await _syncService.uploadSingleHabitante(h);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Habitante subido a la nube' : 'Error al subir'),
            backgroundColor: ok ? AppColors.success : AppColors.error,
          ),
        );
        if (ok) await _cargarPendientes();
      }
    } finally {
      if (mounted) setState(() => _subiendo.remove(key));
    }
  }

  Future<void> _subirComuna(Comuna c) async {
    final key = 'C-${c.codigoSitur}';
    if (_subiendo.contains(key)) return;
    setState(() => _subiendo.add(key));
    try {
      final ok = await _syncService.uploadSingleComuna(c);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Comuna subida a la nube' : 'Error al subir'),
            backgroundColor: ok ? AppColors.success : AppColors.error,
          ),
        );
        if (ok) await _cargarPendientes();
      }
    } finally {
      if (mounted) setState(() => _subiendo.remove(key));
    }
  }

  Future<void> _subirConsejo(ConsejoComunal c) async {
    final key = 'CC-${c.codigoSitur}';
    if (_subiendo.contains(key)) return;
    setState(() => _subiendo.add(key));
    try {
      final ok = await _syncService.uploadSingleConsejoComunal(c);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Consejo subido a la nube' : 'Error al subir'),
            backgroundColor: ok ? AppColors.success : AppColors.error,
          ),
        );
        if (ok) await _cargarPendientes();
      }
    } finally {
      if (mounted) setState(() => _subiendo.remove(key));
    }
  }

  Future<void> _subirOrganizacion(Organizacion o) async {
    final key = 'O-${o.id}';
    if (_subiendo.contains(key)) return;
    setState(() => _subiendo.add(key));
    try {
      final ok = await _syncService.uploadSingleOrganizacion(o);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'Organización subida a la nube' : 'Error al subir',
            ),
            backgroundColor: ok ? AppColors.success : AppColors.error,
          ),
        );
        if (ok) await _cargarPendientes();
      }
    } finally {
      if (mounted) setState(() => _subiendo.remove(key));
    }
  }

  Future<void> _subirClap(Clap c) async {
    final key = 'CLAP-${c.id}';
    if (_subiendo.contains(key)) return;
    setState(() => _subiendo.add(key));
    try {
      final ok = await _syncService.uploadSingleClap(c);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'CLAP subido a la nube' : 'Error al subir'),
            backgroundColor: ok ? AppColors.success : AppColors.error,
          ),
        );
        if (ok) await _cargarPendientes();
      }
    } finally {
      if (mounted) setState(() => _subiendo.remove(key));
    }
  }

  Future<void> _subirProyecto(Proyecto p) async {
    final key = 'P-${p.id}';
    if (_subiendo.contains(key)) return;
    setState(() => _subiendo.add(key));
    try {
      final ok = await _syncService.uploadSingleProyecto(p);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Proyecto subido a la nube' : 'Error al subir'),
            backgroundColor: ok ? AppColors.success : AppColors.error,
          ),
        );
        if (ok) await _cargarPendientes();
      }
    } finally {
      if (mounted) setState(() => _subiendo.remove(key));
    }
  }

  Future<void> _subirSolicitud(Solicitud s) async {
    final key = 'S-${s.id}';
    if (_subiendo.contains(key)) return;
    setState(() => _subiendo.add(key));
    try {
      final ok = await _syncService.uploadSingleSolicitud(s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Solicitud subida a la nube' : 'Error al subir'),
            backgroundColor: ok ? AppColors.success : AppColors.error,
          ),
        );
        if (ok) await _cargarPendientes();
      }
    } finally {
      if (mounted) setState(() => _subiendo.remove(key));
    }
  }

  Future<void> _subirExtranjero(Extranjero e) async {
    final key = 'EX-${e.cedulaColombiana}';
    if (_subiendo.contains(key)) return;
    setState(() => _subiendo.add(key));
    try {
      final ok = await _syncService.uploadSingleExtranjero(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'Extranjero subido a la nube' : 'Error al subir',
            ),
            backgroundColor: ok ? AppColors.success : AppColors.error,
          ),
        );
        if (ok) await _cargarPendientes();
      }
    } finally {
      if (mounted) setState(() => _subiendo.remove(key));
    }
  }

  Future<void> _sincronizarTodo() async {
    if (_subiendo.isNotEmpty) return;
    setState(() => _loading = true);

    try {
      final successMap = await _syncService.sincronizarTodo(
        profunda: false,
        onProgress: (p) {},
      );

      final totalSincronizados = successMap.values.fold(
        0,
        (sum, val) => sum + val,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              totalSincronizados > 0
                  ? 'Sincronización masiva finalizada'
                  : 'No se procesaron registros o error al subir.',
            ),
            backgroundColor: totalSincronizados > 0
                ? AppColors.success
                : AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error durante sincronización: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        await _cargarPendientes();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registros pendientes de subir'),
        actions: [
          if (!_loading && _total > 0 && _canUpload)
            IconButton(
              icon: const Icon(Icons.cloud_upload_outlined),
              tooltip: 'Intentar sincronizar todo',
              onPressed: () => _sincronizarTodo(),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _total == 0
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_done,
                    size: 64,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay registros pendientes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _cargarPendientes,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section(
                    'Habitantes',
                    _habitantes.length,
                    AppModulePastel.habitantes,
                    _habitantes.map(
                      (h) => _Tile(
                        title: '${h.nombreCompleto} · ${h.cedula}',
                        key: 'H-${h.cedula}',
                        subiendo: _subiendo.contains('H-${h.cedula}'),
                        onSubir: () => _subirHabitante(h),
                      ),
                    ),
                  ),
                  _section(
                    'Comunas',
                    _comunas.length,
                    AppModulePastel.comunas,
                    _comunas.map(
                      (c) => _Tile(
                        title: c.nombreComuna,
                        key: 'C-${c.codigoSitur}',
                        subiendo: _subiendo.contains('C-${c.codigoSitur}'),
                        onSubir: () => _subirComuna(c),
                      ),
                    ),
                  ),
                  _section(
                    'Consejos Comunales',
                    _consejos.length,
                    AppModulePastel.consejos,
                    _consejos.map(
                      (c) => _Tile(
                        title: c.nombreConsejo,
                        key: 'CC-${c.codigoSitur}',
                        subiendo: _subiendo.contains('CC-${c.codigoSitur}'),
                        onSubir: () => _subirConsejo(c),
                      ),
                    ),
                  ),
                  _section(
                    'Organizaciones',
                    _organizaciones.length,
                    AppModulePastel.organizaciones,
                    _organizaciones.map(
                      (o) => _Tile(
                        title: o.nombreLargo,
                        key: 'O-${o.id}',
                        subiendo: _subiendo.contains('O-${o.id}'),
                        onSubir: () => _subirOrganizacion(o),
                      ),
                    ),
                  ),
                  _section(
                    'CLAPs',
                    _claps.length,
                    AppModulePastel.claps,
                    _claps.map(
                      (c) => _Tile(
                        title: c.nombreClap,
                        key: 'CLAP-${c.id}',
                        subiendo: _subiendo.contains('CLAP-${c.id}'),
                        onSubir: () => _subirClap(c),
                      ),
                    ),
                  ),
                  _section(
                    'Proyectos',
                    _proyectos.length,
                    AppModulePastel.reportes,
                    _proyectos.map(
                      (p) => _Tile(
                        title: p.nombreProyecto,
                        key: 'P-${p.id}',
                        subiendo: _subiendo.contains('P-${p.id}'),
                        onSubir: () => _subirProyecto(p),
                      ),
                    ),
                  ),
                  _section(
                    'Extranjeros',
                    _extranjeros.length,
                    AppModulePastel.extranjeros,
                    _extranjeros.map(
                      (e) => _Tile(
                        title: '${e.nombreCompleto} · ${e.cedulaColombiana}',
                        key: 'EX-${e.cedulaColombiana}',
                        subiendo: _subiendo.contains(
                          'EX-${e.cedulaColombiana}',
                        ),
                        onSubir: () => _subirExtranjero(e),
                      ),
                    ),
                  ),
                  _section(
                    'Solicitudes',
                    _solicitudes.length,
                    AppModulePastel.listado,
                    _solicitudes.map(
                      (s) => _Tile(
                        title: s.comunidad.isNotEmpty
                            ? s.comunidad
                            : 'Solicitud #${s.id}',
                        key: 'S-${s.id}',
                        subiendo: _subiendo.contains('S-${s.id}'),
                        onSubir: () => _subirSolicitud(s),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _section(String label, int count, Color color, Iterable<_Tile> tiles) {
    if (count == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$label ($count)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...tiles.map(
          (t) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              title: Text(t.title),
              trailing: t.subiendo
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _canUpload
                  ? TextButton.icon(
                      icon: const Icon(Icons.cloud_upload, size: 18),
                      label: const Text('Subir'),
                      onPressed: t.onSubir,
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _Tile {
  final String title;
  final String key;
  final bool subiendo;
  final VoidCallback onSubir;

  _Tile({
    required this.title,
    required this.key,
    required this.subiendo,
    required this.onSubir,
  });
}
