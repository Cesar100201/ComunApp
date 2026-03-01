import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/module_action_card.dart';
import 'reportes_list_page.dart';
import 'reporte_municipal_page.dart';

class ReportesMainPage extends StatelessWidget {
  const ReportesMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reportes"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              "Gestión de Reportes",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ModuleActionCard(
            title: "Solicitudes",
            subtitle: "Reportar solución de solicitudes individuales con evidencia fotográfica.",
            icon: Icons.assignment_outlined,
            color: AppModulePastel.reportes,
            colorAccent: AppModulePastel.reportesAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReportesListPage(),
                ),
              );
            },
          ),
          ModuleActionCard(
            title: "Reporte Municipal",
            subtitle: "Estadísticas y reportes consolidados de planes de gestión pública.",
            icon: Icons.analytics_outlined,
            color: AppModulePastel.reporteMunicipal,
            colorAccent: AppModulePastel.reporteMunicipalAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReporteMunicipalPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
