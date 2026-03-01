import 'package:flutter/material.dart';
import 'add_extranjero_page.dart';
import 'search_extranjero_page.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/module_action_card.dart';

class ExtranjerosMenuPage extends StatelessWidget {
  const ExtranjerosMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Extranjeros"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ModuleActionCard(
            title: "Nuevo Registro",
            subtitle: "Inscribir extranjero con cédula colombiana (departamento y municipio)",
            icon: Icons.person_add_rounded,
            color: AppModulePastel.nuevoRegistro,
            colorAccent: AppModulePastel.nuevoRegistroAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddExtranjeroPage()),
            ),
          ),
          ModuleActionCard(
            title: "Buscar Extranjero",
            subtitle: "Buscar por nombre, cédula o criterios",
            icon: Icons.search_rounded,
            color: AppModulePastel.buscar,
            colorAccent: AppModulePastel.buscarAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchExtranjeroPage()),
            ),
          ),
        ],
      ),
    );
  }
}
