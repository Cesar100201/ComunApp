import 'package:flutter/material.dart';
import 'package:goblafria/models/models.dart';
import 'package:goblafria/core/theme/app_theme.dart';
import 'package:goblafria/database/db_helper.dart';
import 'generar_reporte_page.dart';

class ReportesSolicitudDetailPage extends StatefulWidget {
  final Solicitud solicitud;

  const ReportesSolicitudDetailPage({
    super.key,
    required this.solicitud,
  });

  @override
  State<ReportesSolicitudDetailPage> createState() =>
      _ReportesSolicitudDetailPageState();
}

class _ReportesSolicitudDetailPageState
    extends State<ReportesSolicitudDetailPage> {
  Solicitud? _solicitudCompleto;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosCompletos();
  }

  Future<void> _cargarDatosCompletos() async {
    final isar = await DbHelper().db;
    final solicitud = await isar.solicituds.get(widget.solicitud.id);

    if (solicitud != null) {
      await solicitud.comuna.load();
      await solicitud.consejoComunal.load();
      await solicitud.ubch.load();
      await solicitud.creador.load();

      if (mounted) {
        setState(() {
          _solicitudCompleto = solicitud;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _solicitudCompleto = widget.solicitud;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Detalle de Solicitud")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final s = _solicitudCompleto ?? widget.solicitud;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalle de Solicitud"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(s),
            const SizedBox(height: 24),
            _buildSection(
              context,
              title: "Información General",
              icon: Icons.info,
              children: [
                _buildInfoRow("Tipo de Solicitud",
                    _getTipoSolicitudText(s.tipoSolicitud)),
                _buildInfoRow("Descripción", s.descripcion),
                if (s.cantidadLamparas != null || s.cantidadBombillos != null)
                  _buildInfoRow("Cantidad de Luminarias",
                      ((s.cantidadLamparas ?? 0) + (s.cantidadBombillos ?? 0)).toString()),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              context,
              title: "Ubicación",
              icon: Icons.location_on,
              children: [
                if (s.comuna.value != null)
                  _buildInfoRow("Comuna", s.comuna.value!.nombreComuna),
                if (s.consejoComunal.value != null)
                  _buildInfoRow(
                      "Consejo Comunal", s.consejoComunal.value!.nombreConsejo),
                _buildInfoRow("Comunidad", s.comunidad),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              context,
              title: "Organización",
              icon: Icons.business,
              children: [
                if (s.ubch.value != null)
                  _buildInfoRow("UBCH", s.ubch.value!.nombreLargo),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              context,
              title: "Creador",
              icon: Icons.person,
              children: [
                if (s.creador.value != null)
                  _buildInfoRow("Nombre", s.creador.value!.nombreCompleto)
                else
                  _buildInfoRow("Creador", "No asignado",
                      valueColor: AppColors.textTertiary),
                if (s.creador.value != null)
                  _buildInfoRow(
                    "Cédula",
                    "${s.creador.value!.nacionalidad.toString().split('.').last}-${s.creador.value!.cedula}",
                  ),
              ],
            ),
            const SizedBox(height: 32),
            // Botón para generar reporte
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          GenerarReportePage(solicitud: s),
                    ),
                  );
                  if (result == true && mounted) {
                    Navigator.pop(context, true);
                  }
                },
                icon: const Icon(Icons.assignment_turned_in),
                label: const Text("GENERAR REPORTE"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Solicitud s) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.shadowMedium,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            child: Icon(
              _getIconForTipoSolicitud(s.tipoSolicitud),
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTipoSolicitudText(s.tipoSolicitud),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.descripcion.length > 40
                      ? "${s.descripcion.substring(0, 40)}..."
                      : s.descripcion,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryUltraLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
