import 'package:flutter/material.dart';
import '../../inhabitants/presentation/habitantes_menu_page.dart';
import '../../comunas/presentation/add_comuna_page.dart';
import '../../consejos/presentation/add_consejo_page.dart';
import '../../organizations/presentation/add_organizacion_page.dart';
import '../../claps/presentation/add_clap_page.dart';
import '../../../../core/theme/app_theme.dart';

class RegistrosMenuPage extends StatelessWidget {
  const RegistrosMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registros"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // TARJETA 1: HABITANTES
          _buildActionCard(
            context,
            title: "Gestión de Habitantes",
            subtitle: "Registro y búsqueda de ciudadanos",
            icon: Icons.groups_rounded,
            color: AppColors.primaryLight,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HabitantesMenuPage()),
            ),
          ),

          // TARJETA 2: COMUNAS
          _buildActionCard(
            context,
            title: "Gestión de Comunas",
            subtitle: "Registrar y administrar comunas",
            icon: Icons.location_city_rounded,
            color: AppColors.info,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddComunaPage()),
            ),
          ),

          // TARJETA 3: CONSEJOS COMUNALES
          _buildActionCard(
            context,
            title: "Gestión de Consejos Comunales",
            subtitle: "Registrar consejos comunales y comunidades",
            icon: Icons.groups_rounded,
            color: AppColors.primaryLight,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddConsejoPage()),
            ),
          ),

          // TARJETA 4: ORGANIZACIONES
          _buildActionCard(
            context,
            title: "Gestión de Organizaciones",
            subtitle: "Registrar organizaciones políticas y sociales",
            icon: Icons.business_rounded,
            color: AppColors.warning,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddOrganizacionPage()),
            ),
          ),

          // TARJETA 5: CLAPS
          _buildActionCard(
            context,
            title: "Gestión de CLAPs",
            subtitle: "Registrar Comités Locales de Abastecimiento",
            icon: Icons.store_rounded,
            color: AppColors.success,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddClapPage()),
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
