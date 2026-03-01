import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/user_role_service.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/widgets/module_action_card.dart';
import '../../profile/presentation/profile_page.dart';
import '../data/formacion_service.dart';
import 'formacion_groups_list_page.dart';
import 'formacion_create_group_page.dart';
import 'formacion_join_group_page.dart';

/// Menú principal del módulo de Formación.
/// Solo usuarios con cédula asociada en Perfil pueden ver el contenido.
class FormacionMenuPage extends StatefulWidget {
  const FormacionMenuPage({super.key});

  @override
  State<FormacionMenuPage> createState() => _FormacionMenuPageState();
}

class _FormacionMenuPageState extends State<FormacionMenuPage> {
  bool _loading = true;
  int? _linkedCedula;
  int _nivelUsuario = AppConstants.nivelInvitado;
  bool _hasGroups = false;
  final UserRoleService _roleService = UserRoleService();
  final FormacionService _formacionService = FormacionService();

  @override
  void initState() {
    super.initState();
    _checkVerification();
  }

  Future<void> _checkVerification() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final cedula = await SettingsService.getLinkedHabitanteCedula(uid);
    final nivel = await _roleService.getNivelUsuario();
    bool hasGroups = false;
    if (uid != null && cedula != null && nivel == AppConstants.nivelInvitado) {
      try {
        final list = await _formacionService.getMyGroups(
          uid: uid,
          cedula: cedula,
        );
        hasGroups = list.isNotEmpty;
      } catch (_) {}
    } else if (cedula != null && uid != null) {
      try {
        final list = await _formacionService.getMyGroups(
          uid: uid,
          cedula: cedula,
        );
        hasGroups = list.isNotEmpty;
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _linkedCedula = cedula;
        _nivelUsuario = nivel;
        _hasGroups = hasGroups;
      });
    }
  }

  Future<void> _openProfileAndRefresh() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfilePage(
          onSettingsChanged: null,
          onSyncSettingsChanged: null,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _loading = true);
    await _checkVerification();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Formación')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_linkedCedula == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Formación')),
        body: _buildNotVerifiedContent(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Formación')),
      body: _buildMenuContent(),
    );
  }

  Widget _buildNotVerifiedContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppModulePastel.formacion.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.person_off_rounded,
                size: 64,
                color: AppModulePastel.formacionAccent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Cédula no asociada',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Para acceder a Formación debe asociar su cédula con su cuenta en Perfil.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _openProfileAndRefresh,
              icon: const Icon(Icons.person_rounded),
              label: const Text('Ir a Perfil'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuContent() {
    final isInvitado = _nivelUsuario == AppConstants.nivelInvitado;
    final showMisGrupos = !isInvitado || _hasGroups;
    final showCrearGrupo = _roleService.canCreateFormacionGroups(_nivelUsuario);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text(
            'Cursos y capacitaciones',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        if (showMisGrupos)
          ModuleActionCard(
            title: 'Mis grupos',
            subtitle: 'Ver los grupos en los que participas.',
            icon: Icons.groups_rounded,
            color: AppModulePastel.formacion,
            colorAccent: AppModulePastel.formacionAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FormacionGroupsListPage(),
                ),
              );
            },
          ),
        if (showMisGrupos) const SizedBox(height: 12),
        if (showCrearGrupo)
          ModuleActionCard(
            title: 'Crear grupo',
            subtitle:
                'Crear un nuevo grupo y compartir el código de invitación.',
            icon: Icons.add_circle_outline_rounded,
            color: AppModulePastel.formacion,
            colorAccent: AppModulePastel.formacionAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FormacionCreateGroupPage(),
                ),
              );
            },
          ),
        if (showCrearGrupo) const SizedBox(height: 12),
        ModuleActionCard(
          title: 'Unirse con código',
          subtitle: 'Entrar a un grupo usando el código que te hayan dado.',
          icon: Icons.login_rounded,
          color: AppModulePastel.formacion,
          colorAccent: AppModulePastel.formacionAccent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FormacionJoinGroupPage(),
              ),
            );
          },
        ),
      ],
    );
  }
}
