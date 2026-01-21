import 'package:flutter/material.dart';
import 'package:goblafria/core/theme/app_theme.dart';
import 'package:goblafria/features/solicitudes/data/repositories/solicitud_repository.dart';
import 'package:goblafria/models/models.dart';
import 'package:goblafria/database/db_helper.dart';
import 'solicitud_profile_page.dart';

class SolicitudesListPage extends StatefulWidget {
  const SolicitudesListPage({super.key});

  @override
  State<SolicitudesListPage> createState() => _SolicitudesListPageState();
}

class _SolicitudesListPageState extends State<SolicitudesListPage> {
  SolicitudRepository? _solicitudRepo;
  List<Solicitud> _solicitudes = [];
  bool _isLoading = true;
  bool _repoInicializado = false;

  @override
  void initState() {
    super.initState();
    _inicializarRepositorio();
  }

  Future<void> _inicializarRepositorio() async {
    final isar = await DbHelper().db;
    if (!mounted) return;
    setState(() {
      _solicitudRepo = SolicitudRepository(isar);
      _repoInicializado = true;
    });
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (!_repoInicializado || _solicitudRepo == null) {
      await _inicializarRepositorio();
    }
    final datos = await _solicitudRepo!.getAllSolicitudes();
    // Cargar relaciones
    for (var s in datos) {
      await s.comuna.load();
      await s.consejoComunal.load();
      await s.ubch.load();
      await s.creador.load();
    }
    if (!mounted) return;
    setState(() {
      _solicitudes = datos;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Listado de Solicitudes")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _solicitudes.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _solicitudes.length,
                  itemBuilder: (context, index) {
                    final s = _solicitudes[index];
                    return _buildSolicitudCard(s);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            "No hay solicitudes registradas",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitudCard(Solicitud s) {
    // Cargar los enlaces para asegurar que los valores estén disponibles
    s.comuna.loadSync();
    s.consejoComunal.loadSync();
    s.ubch.loadSync();
    s.creador.loadSync();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SolicitudProfilePage(solicitud: s),
            ),
          );
          if (result == true) {
            _cargarDatos();
          }
        },
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: AppColors.info,
          child: Icon(
            _getIconForTipoSolicitud(s.tipoSolicitud),
            color: Colors.white,
          ),
        ),
        title: Text(
          s.descripcion,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Tipo: ${_getTipoSolicitudText(s.tipoSolicitud)}",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              if (s.comunidad.isNotEmpty)
                Text(
                  "Comunidad: ${s.comunidad}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              if (s.cantidadLamparas != null || s.cantidadBombillos != null)
                Text(
                  "Luminarias: ${(s.cantidadLamparas ?? 0) + (s.cantidadBombillos ?? 0)}${s.cantidadLamparas != null && s.cantidadBombillos != null ? ' (${s.cantidadLamparas} lámparas, ${s.cantidadBombillos} bombillos)' : ''}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              if (s.otrosTipoSolicitud != null)
                Text(
                  "Otros: ${s.otrosTipoSolicitud}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              if (s.consejoComunal.value != null)
                Text(
                  "Consejo Comunal: ${s.consejoComunal.value!.nombreConsejo}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              if (s.ubch.value != null)
                Text(
                  "UBCH: ${s.ubch.value!.nombreLargo}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              if (s.creador.value != null)
                Text(
                  "Creado por: ${s.creador.value!.nombreCompleto}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              s.isSynced ? Icons.cloud_done : Icons.cloud_off,
              color: s.isSynced ? AppColors.success : AppColors.warning,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              s.isSynced ? "En Línea" : "Pendiente",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: s.isSynced ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  IconData _getIconForTipoSolicitud(TipoSolicitud tipo) {
    switch (tipo) {
      case TipoSolicitud.Agua:
        return Icons.water_drop_rounded;
      case TipoSolicitud.Electrico:
        return Icons.power_rounded;
      case TipoSolicitud.Iluminacion:
        return Icons.lightbulb_rounded;
      case TipoSolicitud.Otros:
        return Icons.category_rounded;
    }
  }

  String _getTipoSolicitudText(TipoSolicitud tipo) {
    switch (tipo) {
      case TipoSolicitud.Agua:
        return "Agua";
      case TipoSolicitud.Electrico:
        return "Eléctrico";
      case TipoSolicitud.Iluminacion:
        return "Plan García de Hevia Iluminada 2026";
      case TipoSolicitud.Otros:
        return "Otros";
    }
  }
}