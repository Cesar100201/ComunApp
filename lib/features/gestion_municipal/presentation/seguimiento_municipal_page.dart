import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/module_action_card.dart';
import 'control_seguimiento_list_page.dart';

/// Página del módulo Seguimiento Municipal.
///
/// Funcionalidades de seguimiento y monitoreo de gestión municipal.
class SeguimientoMunicipalPage extends StatelessWidget {
  const SeguimientoMunicipalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Seguimiento Municipal"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ModuleActionCard(
            title: "Control y Seguimiento",
            subtitle: "Registrar y consultar seguimiento con categoría, objetivo, acciones, medios de verificación y estatus.",
            icon: Icons.assignment_rounded,
            color: AppModulePastel.gestionMunicipal,
            colorAccent: AppModulePastel.gestionMunicipalAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ControlSeguimientoListPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
