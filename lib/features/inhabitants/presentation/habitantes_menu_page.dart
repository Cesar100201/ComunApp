import 'package:flutter/material.dart';
import 'add_habitante_page.dart';
import 'search_habitante_page.dart';
import 'bulk_upload_habitantes_page.dart';
import '../../../../core/theme/app_theme.dart';

class HabitantesMenuPage extends StatelessWidget {
  const HabitantesMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Habitantes"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // TARJETA 1: REGISTRO
          _buildActionCard(
            context,
            title: "Nuevo Registro",
            subtitle: "Inscribir un habitante en la base de datos",
            icon: Icons.person_add_rounded,
            color: AppColors.success,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHabitantePage())),
          ),

          // TARJETA 2: BUSCAR
          _buildActionCard(
            context,
            title: "Buscar Habitante",
            subtitle: "Localizar por Cédula de Identidad",
            icon: Icons.search_rounded,
            color: AppColors.warning,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchHabitantePage())),
          ),

          // TARJETA 3: CARGA MASIVA
          _buildActionCard(
            context,
            title: "Carga Masiva",
                subtitle: "Importar múltiples habitantes desde CSV",
            icon: Icons.upload_file_rounded,
            color: AppColors.info,
            onTap: () async {
              final resultado = await Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const BulkUploadHabitantesPage())
              );
              // Si se guardaron datos, recargar la lista si estamos en la página de lista
              if (resultado == true) {
                // Notificar a la página de lista para que recargue (si está activa)
                // Esto se manejará automáticamente cuando el usuario navegue a la lista
              }
            },
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