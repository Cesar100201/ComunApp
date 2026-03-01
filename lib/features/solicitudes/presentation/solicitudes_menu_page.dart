import 'package:flutter/material.dart';
import 'add_solicitud_page.dart';
import 'solicitudes_list_page.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/module_action_card.dart';
import '../../../../core/services/user_role_service.dart';
import '../../../../core/utils/constants.dart';

class SolicitudesMenuPage extends StatefulWidget {
  const SolicitudesMenuPage({super.key});

  @override
  State<SolicitudesMenuPage> createState() => _SolicitudesMenuPageState();
}

class _SolicitudesMenuPageState extends State<SolicitudesMenuPage> {
  final UserRoleService _roleService = UserRoleService();
  int _nivelUsuario = AppConstants.nivelInvitado;

  @override
  void initState() {
    super.initState();
    _roleService.getNivelUsuario().then((n) {
      if (mounted) setState(() => _nivelUsuario = n);
    });
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = _roleService.canAccessRegistros(_nivelUsuario);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Solicitudes"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (canAdd)
            ModuleActionCard(
              title: "Plan García de Hevia Iluminada 2026",
              subtitle: "Registrar una nueva solicitud de luminarias",
              icon: Icons.lightbulb_outline_rounded,
              color: AppModulePastel.luminarias,
              colorAccent: AppModulePastel.luminariasAccent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddSolicitudPage()),
              ),
            ),
          if (canAdd) const SizedBox(height: 12),
          ModuleActionCard(
            title: "Lista de Solicitudes",
            subtitle: "Ver y gestionar todas las solicitudes registradas",
            icon: Icons.list_rounded,
            color: AppModulePastel.listado,
            colorAccent: AppModulePastel.listadoAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SolicitudesListPage()),
            ),
          ),
        ],
      ),
    );
  }
}
