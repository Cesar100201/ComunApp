import 'package:flutter/material.dart';
import 'package:goblafria/core/theme/app_theme.dart';
import 'package:goblafria/features/solicitudes/data/repositories/solicitud_repository.dart';
import 'package:goblafria/models/models.dart';
import 'package:goblafria/database/db_helper.dart';
import 'reportes_solicitud_detail_page.dart';

class ReportesListPage extends StatefulWidget {
  const ReportesListPage({super.key});

  @override
  State<ReportesListPage> createState() => _ReportesListPageState();
}

class _ReportesListPageState extends State<ReportesListPage> {
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
      appBar: AppBar(
        title: const Text("Módulo de Reportes"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
            tooltip: "Recargar",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _solicitudes.isEmpty
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        "Solicitudes para Reportar",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    ...List.generate(
                      _solicitudes.length,
                      (index) => _buildSolicitudCard(_solicitudes[index]),
                    ),
                  ],
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
            "No hay solicitudes para reportar",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            "Las solicitudes aparecerán aquí cuando se creen",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
            textAlign: TextAlign.center,
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
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReportesSolicitudDetailPage(solicitud: s),
            ),
          );
          if (result == true) {
            _cargarDatos();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppColors.shadowSmall,
                    ),
                    child: Icon(
                      _getIconForTipoSolicitud(s.tipoSolicitud),
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTipoSolicitudText(s.tipoSolicitud),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.comunidad.isNotEmpty ? s.comunidad : "Sin comunidad",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryUltraLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.descripcion,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (s.cantidadLamparas != null || s.cantidadBombillos != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Luminarias solicitadas: ${(s.cantidadLamparas ?? 0) + (s.cantidadBombillos ?? 0)}",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ],
                    if (s.consejoComunal.value != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.groups,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              s.consejoComunal.value!.nombreConsejo,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
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
