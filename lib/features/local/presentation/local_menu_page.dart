import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../inhabitants/presentation/habitantes_list_page.dart';
import '../../comunas/presentation/comunas_list_page.dart';
import '../../consejos/presentation/consejos_comunales_list_page.dart';
import '../../organizations/presentation/organizaciones_list_page.dart';
import '../../claps/presentation/claps_list_page.dart';
import '../../solicitudes/presentation/solicitudes_list_page.dart';

class LocalMenuPage extends StatelessWidget {
  const LocalMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Base de Datos Local"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // HABITANTES
          _buildActionCard(
            context,
            title: "Habitantes",
            subtitle: "Ver lista completa y estatus de sincronización",
            icon: Icons.people_rounded,
            color: AppColors.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HabitantesListPage()),
            ),
          ),

          // COMUNAS
          _buildActionCard(
            context,
            title: "Comunas",
            subtitle: "Ver lista de comunas registradas",
            icon: Icons.location_city_rounded,
            color: AppColors.info,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComunasListPage()),
            ),
          ),

          // CONSEJOS COMUNALES
          _buildActionCard(
            context,
            title: "Consejos Comunales",
            subtitle: "Ver y editar consejos comunales registrados",
            icon: Icons.groups_rounded,
            color: AppColors.primaryLight,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConsejosComunalesListPage()),
            ),
          ),

          // ORGANIZACIONES
          _buildActionCard(
            context,
            title: "Organizaciones",
            subtitle: "Ver lista de organizaciones",
            icon: Icons.business_rounded,
            color: AppColors.warning,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrganizacionesListPage()),
            ),
          ),

          // CLAPS
          _buildActionCard(
            context,
            title: "CLAPs",
            subtitle: "Ver lista de Comités Locales de Abastecimiento",
            icon: Icons.store_rounded,
            color: AppColors.success,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClapsListPage()),
            ),
          ),

          // SOLICITUDES
          _buildActionCard(
            context,
            title: "Solicitudes",
            subtitle: "Ver y gestionar solicitudes de la comunidad",
            icon: Icons.assignment_rounded,
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

  Widget _buildActionCard(
    BuildContext context, {
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
