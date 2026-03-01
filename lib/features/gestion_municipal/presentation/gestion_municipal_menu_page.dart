import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/module_action_card.dart';
import '../../../../core/services/user_role_service.dart';
import '../../../../core/utils/constants.dart';
import '../../solicitudes/presentation/solicitudes_menu_page.dart';
import '../../reportes/presentation/reportes_main_page.dart';
import 'seguimiento_municipal_page.dart';

/// Menú principal del módulo de Gestión Municipal.
///
/// Centraliza las funcionalidades relacionadas con la administración
/// municipal de la alcaldía: solicitudes, reportes y seguimiento.
/// Invitados solo ven Solicitudes (sin Reportes ni Seguimiento Municipal).
class GestionMunicipalMenuPage extends StatefulWidget {
  const GestionMunicipalMenuPage({super.key});

  @override
  State<GestionMunicipalMenuPage> createState() => _GestionMunicipalMenuPageState();
}

class _GestionMunicipalMenuPageState extends State<GestionMunicipalMenuPage> {
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
    final showReportes = _roleService.canAccessReportes(_nivelUsuario);
    final showSeguimiento = _roleService.canAccessSeguimientoMunicipal(_nivelUsuario);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión Municipal"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ModuleActionCard(
            title: "Solicitudes",
            subtitle: "Registrar y Administrar solicitudes.",
            icon: Icons.lightbulb_outline_rounded,
            color: AppModulePastel.solicitudes,
            colorAccent: AppModulePastel.solicitudesAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SolicitudesMenuPage(),
                ),
              );
            },
          ),
          if (showReportes) ...[
            const SizedBox(height: 12),
            ModuleActionCard(
              title: "Reportes",
              subtitle: "Reportar soluciones y consultar estadísticas municipales.",
              icon: Icons.assignment_turned_in_rounded,
              color: AppModulePastel.reportes,
              colorAccent: AppModulePastel.reportesAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReportesMainPage(),
                  ),
                );
              },
            ),
          ],
          if (showSeguimiento) ...[
            const SizedBox(height: 12),
            ModuleActionCard(
              title: "Seguimiento Municipal",
              subtitle: "Seguimiento y monitoreo de la gestión municipal.",
              icon: Icons.track_changes_rounded,
              color: AppModulePastel.gestionMunicipal,
              colorAccent: AppModulePastel.gestionMunicipalAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SeguimientoMunicipalPage(),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
