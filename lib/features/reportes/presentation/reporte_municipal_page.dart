import 'package:flutter/material.dart';
import 'package:goblafria/core/theme/app_theme.dart';
import 'package:goblafria/models/models.dart';
import 'plan_estadisticas_page.dart';

class ReporteMunicipalPage extends StatelessWidget {
  const ReporteMunicipalPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Lista de planes activos (por ahora solo uno)
    final planesActivos = [
      {
        'titulo': 'Plan García de Hevia Iluminada 2026',
        'descripcion': 'Plan municipal de instalación de luminarias en todas las comunidades',
        'tipoSolicitud': TipoSolicitud.Iluminacion,
        'icono': Icons.lightbulb_rounded,
        'color': AppColors.warning,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reporte Municipal"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Encabezado
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Planes de Gestión Pública",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Selecciona un plan para ver estadísticas y generar reportes",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),

          // Tarjetas de planes activos
          ...planesActivos.map((plan) => _buildPlanCard(
                context,
                titulo: plan['titulo'] as String,
                descripcion: plan['descripcion'] as String,
                tipoSolicitud: plan['tipoSolicitud'] as TipoSolicitud,
                icono: plan['icono'] as IconData,
                color: plan['color'] as Color,
              )),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String titulo,
    required String descripcion,
    required TipoSolicitud tipoSolicitud,
    required IconData icono,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlanEstadisticasPage(
                tituloPlan: titulo,
                tipoSolicitud: tipoSolicitud,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icono
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.shadowMedium,
                ),
                child: Icon(
                  icono,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),

              // Textos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      descripcion,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),

              // Flecha
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
