import 'package:flutter/material.dart';
import '../../inhabitants/presentation/habitantes_menu_page.dart';
import '../../inhabitants/presentation/extranjeros_menu_page.dart';
import '../../comunas/presentation/add_comuna_page.dart';
import '../../consejos/presentation/add_consejo_page.dart';
import '../../organizations/presentation/add_organizacion_page.dart';
import '../../claps/presentation/add_clap_page.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/module_action_card.dart';
import '../../../../core/services/user_role_service.dart';

class RegistrosMenuPage extends StatefulWidget {
  const RegistrosMenuPage({super.key});

  @override
  State<RegistrosMenuPage> createState() => _RegistrosMenuPageState();
}

class _RegistrosMenuPageState extends State<RegistrosMenuPage> {
  final UserRoleService _roleService = UserRoleService();
  bool _loading = true;
  bool _canAccess = false;

  @override
  void initState() {
    super.initState();
    _roleService.getNivelUsuario().then((n) {
      if (mounted) {
        setState(() {
        _canAccess = _roleService.canAccessRegistros(n);
        _loading = false;
      });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Registros")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text("Registros")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  'No tiene permiso para acceder a este módulo.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registros"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ModuleActionCard(
            title: "Gestión de Habitantes",
            subtitle: "Registro y búsqueda de ciudadanos",
            icon: Icons.groups_rounded,
            color: AppModulePastel.habitantes,
            colorAccent: AppModulePastel.habitantesAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HabitantesMenuPage()),
            ),
          ),
          ModuleActionCard(
            title: "Gestión de Extranjeros",
            subtitle: "Registro y búsqueda de extranjeros con cédula colombiana",
            icon: Icons.public_rounded,
            color: AppModulePastel.extranjeros,
            colorAccent: AppModulePastel.extranjerosAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExtranjerosMenuPage()),
            ),
          ),
          ModuleActionCard(
            title: "Gestión de Comunas",
            subtitle: "Registrar y administrar comunas",
            icon: Icons.location_city_rounded,
            color: AppModulePastel.comunas,
            colorAccent: AppModulePastel.comunasAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddComunaPage()),
            ),
          ),
          ModuleActionCard(
            title: "Gestión de Consejos Comunales",
            subtitle: "Registrar consejos comunales y comunidades",
            icon: Icons.groups_rounded,
            color: AppModulePastel.consejos,
            colorAccent: AppModulePastel.consejosAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddConsejoPage()),
            ),
          ),
          ModuleActionCard(
            title: "Gestión de Organizaciones",
            subtitle: "Registrar organizaciones políticas y sociales",
            icon: Icons.business_rounded,
            color: AppModulePastel.organizaciones,
            colorAccent: AppModulePastel.organizacionesAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddOrganizacionPage()),
            ),
          ),
          ModuleActionCard(
            title: "Gestión de CLAPs",
            subtitle: "Registrar Comités Locales de Abastecimiento",
            icon: Icons.store_rounded,
            color: AppModulePastel.claps,
            colorAccent: AppModulePastel.clapsAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddClapPage()),
            ),
          ),
        ],
      ),
    );
  }
}
