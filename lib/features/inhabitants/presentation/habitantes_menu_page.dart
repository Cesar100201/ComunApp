import 'package:flutter/material.dart';
import 'add_habitante_page.dart';
import 'bulk_upload_habitantes_page.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/module_action_card.dart';

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
          ModuleActionCard(
            title: "Nuevo Registro",
            subtitle: "Inscribir un habitante en la base de datos",
            icon: Icons.person_add_rounded,
            color: AppModulePastel.nuevoRegistro,
            colorAccent: AppModulePastel.nuevoRegistroAccent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHabitantePage())),
          ),
          ModuleActionCard(
            title: "Carga Masiva",
            subtitle: "Importar múltiples habitantes desde CSV",
            icon: Icons.upload_file_rounded,
            color: AppModulePastel.cargaMasiva,
            colorAccent: AppModulePastel.cargaMasivaAccent,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BulkUploadHabitantesPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}