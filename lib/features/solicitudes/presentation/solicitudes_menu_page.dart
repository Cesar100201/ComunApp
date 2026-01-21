import 'package:flutter/material.dart';
import 'add_solicitud_page.dart';
import 'solicitudes_list_page.dart';
import '../../../../core/theme/app_theme.dart';

class SolicitudesMenuPage extends StatelessWidget {
  const SolicitudesMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Solicitudes"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // TARJETA 1: PLAN GARCÍA DE HEVIA ILUMINADA 2026
          _buildActionCard(
            context,
            title: "Plan García de Hevia Iluminada 2026",
            subtitle: "Registrar una nueva solicitud de luminarias",
            icon: Icons.lightbulb_outline_rounded,
            color: AppColors.warning,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddSolicitudPage()),
            ),
          ),

          // TARJETA 2: LISTA DE SOLICITUDES
          _buildActionCard(
            context,
            title: "Lista de Solicitudes",
            subtitle: "Ver y gestionar todas las solicitudes registradas",
            icon: Icons.list_rounded,
            color: AppColors.info,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SolicitudesListPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.shadowSmall,
                ),
                child: Icon(icon, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
        ),
      ),
    );
  }
}
