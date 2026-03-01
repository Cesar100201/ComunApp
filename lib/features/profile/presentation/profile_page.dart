import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../database/db_helper.dart';
import '../../../../models/models.dart';
import '../../settings/presentation/settings_page.dart';
import '../../inhabitants/data/repositories/habitante_repository.dart';
import '../../inhabitants/presentation/habitante_profile_page.dart';
import '../../../../main.dart' show firebaseInitialized;

/// Página de perfil del usuario: ver/editar nombre, email, verificación,
/// cambiar contraseña, metadata de cuenta, enlace a configuración y cerrar sesión.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.onSettingsChanged,
    this.onSyncSettingsChanged,
  });

  /// Se invoca cuando el usuario cambia tema o escala en Configuración (abierta desde aquí).
  final VoidCallback? onSettingsChanged;
  /// Se invoca cuando el usuario cambia sincronización en Configuración.
  final VoidCallback? onSyncSettingsChanged;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  User? _user;
  bool _sendingVerification = false;
  bool _sendingPasswordReset = false;

  int? _linkedCedula;
  Habitante? _linkedHabitante;
  bool _linkingInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
        final updated = FirebaseAuth.instance.currentUser;
        if (mounted) {
          setState(() => _user = updated);
          await _loadLinkedHabitante();
          if (mounted) setState(() => _loading = false);
        }
      } catch (_) {
        if (mounted) {
          setState(() => _user = user);
          await _loadLinkedHabitante();
          if (mounted) setState(() => _loading = false);
        }
      }
    } else {
      if (mounted) {
        setState(() {
        _user = null;
        _linkedCedula = null;
        _linkedHabitante = null;
        _loading = false;
      });
      }
    }
  }

  Future<void> _loadLinkedHabitante() async {
    final uid = _user?.uid;
    if (uid == null) return;
    final cedula = await SettingsService.getLinkedHabitanteCedula(uid);
    if (cedula == null) {
      if (mounted) {
        setState(() {
        _linkedCedula = null;
        _linkedHabitante = null;
      });
      }
      return;
    }
    final isar = await DbHelper().db;
    final repo = HabitanteRepository(isar);
    final h = await repo.getHabitanteByCedula(cedula);
    if (mounted) {
      if (h == null || h.isDeleted) {
        await SettingsService.clearLinkedHabitanteCedula(uid);
        setState(() {
          _linkedCedula = null;
          _linkedHabitante = null;
        });
      } else {
        setState(() {
          _linkedCedula = cedula;
          _linkedHabitante = h;
        });
      }
    }
  }

  Future<void> _linkHabitanteByCedula(int cedula) async {
    final uid = _user?.uid;
    if (uid == null) return;
    setState(() => _linkingInProgress = true);
    final isar = await DbHelper().db;
    final repo = HabitanteRepository(isar);
    final h = await repo.getHabitanteByCedula(cedula);
    if (!mounted) return;
    if (h == null) {
      setState(() => _linkingInProgress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No existe un habitante con esa cédula.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (h.isDeleted) {
      setState(() => _linkingInProgress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ese registro está eliminado.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    await SettingsService.setLinkedHabitanteCedula(uid, cedula);
    setState(() {
      _linkedCedula = cedula;
      _linkedHabitante = h;
      _linkingInProgress = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Perfil vinculado a ${h.nombreCompleto}.')),
    );
  }

  Future<void> _unlinkHabitante() async {
    final uid = _user?.uid;
    if (uid == null) return;
    await SettingsService.clearLinkedHabitanteCedula(uid);
    if (mounted) {
      setState(() {
      _linkedCedula = null;
      _linkedHabitante = null;
    });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil desvinculado del registro de habitante.')),
    );
  }

  Future<void> _editDisplayName() async {
    final user = _user;
    if (user == null) return;
    final controller = TextEditingController(text: user.displayName ?? '');
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar nombre'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nombre para mostrar',
              hintText: 'Ej. Juan Pérez',
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Escribe un nombre';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await user.updateDisplayName(controller.text.trim());
      await user.reload();
      if (mounted) {
        setState(() => _user = FirebaseAuth.instance.currentUser);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nombre actualizado correctamente')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Error al actualizar el nombre'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _resendVerification() async {
    final user = _user;
    if (user == null || user.emailVerified) return;
    setState(() => _sendingVerification = true);
    try {
      await user.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Correo de verificación enviado. Revisa tu bandeja.'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Error al enviar el correo'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingVerification = false);
    }
  }

  Future<void> _changePassword() async {
    final email = _user?.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay correo asociado para enviar el enlace.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    setState(() => _sendingPasswordReset = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enlace para cambiar contraseña enviado a tu correo.'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Error al enviar el enlace'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingPasswordReset = false);
    }
  }

  Future<void> _logout() async {
    if (!firebaseInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La aplicación está en modo offline. No hay sesión activa.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Está seguro que desea cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  String _providerLabel(User user) {
    if (user.providerData.isEmpty) return 'Correo y contraseña';
    final provider = user.providerData.first.providerId;
    if (provider == 'google.com') return 'Google';
    if (provider == 'password') return 'Correo y contraseña';
    return provider;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi Perfil')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final user = _user;
    final email = user?.email ?? 'Sin sesión';
    final displayName = user?.displayName;
    final photoUrl = user?.photoURL;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadUser,
              tooltip: 'Actualizar',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 52,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? const Icon(Icons.person_rounded, size: 56, color: AppColors.primary)
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              displayName ?? 'Usuario',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          const SizedBox(height: 24),
          if (user != null) ...[
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
              title: const Text('Editar nombre'),
              subtitle: const Text('Cambiar nombre para mostrar'),
              onTap: _editDisplayName,
            ),
            const SizedBox(height: 16),
            Text(
              'Registro de habitante',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            if (_linkedHabitante != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.badge_rounded, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _linkedHabitante!.nombreCompleto,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                Text(
                                  'Cédula $_linkedCedula',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => HabitanteProfilePage(habitante: _linkedHabitante!),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.person_rounded, size: 18),
                              label: const Text('Ver perfil'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _unlinkHabitante,
                              icon: const Icon(Icons.link_off_rounded, size: 18),
                              label: const Text('Desvincular'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vincula tu perfil con un registro de habitante ingresando tu cédula.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _LinkHabitanteForm(
                        linkingInProgress: _linkingInProgress,
                        onLink: _linkHabitanteByCedula,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
          if (user != null && !user.emailVerified) ...[
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.info),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Verifica tu correo para acceder a todas las funciones.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _sendingVerification ? null : _resendVerification,
                        icon: _sendingVerification
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.email_rounded, size: 20),
                        label: Text(_sendingVerification
                            ? 'Enviando…'
                            : 'Reenviar correo de verificación'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (user != null && user.email != null && user.email!.isNotEmpty) ...[
            ListTile(
              leading: const Icon(Icons.lock_reset_rounded, color: AppColors.primary),
              title: const Text('Cambiar contraseña'),
              subtitle: const Text('Recibirás un enlace por correo'),
              onTap: _sendingPasswordReset ? null : _changePassword,
              trailing: _sendingPasswordReset
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ],
          if (user != null && user.metadata.creationTime != null) ...[
            const SizedBox(height: 16),
            Text(
              'Información de la cuenta',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Cuenta creada',
                      value: DateFormat.yMd().add_Hm().format(user.metadata.creationTime!),
                    ),
                    if (user.metadata.lastSignInTime != null) ...[
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.login_rounded,
                        label: 'Último acceso',
                        value: DateFormat.yMd().add_Hm().format(user.metadata.lastSignInTime!),
                      ),
                    ],
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.link_rounded,
                      label: 'Inicio de sesión con',
                      value: _providerLabel(user),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.settings_rounded, color: AppColors.primary),
            title: const Text('Configuración'),
            subtitle: const Text('Tema, notificaciones, sincronización'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    onSettingsChanged: widget.onSettingsChanged,
                    onSyncSettingsChanged: widget.onSyncSettingsChanged,
                  ),
                ),
              );
            },
          ),
          if (firebaseInitialized) ...[
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Salir de tu cuenta'),
              onTap: _logout,
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _LinkHabitanteForm extends StatefulWidget {
  final bool linkingInProgress;
  final void Function(int cedula) onLink;

  const _LinkHabitanteForm({
    required this.linkingInProgress,
    required this.onLink,
  });

  @override
  State<_LinkHabitanteForm> createState() => _LinkHabitanteFormState();
}

class _LinkHabitanteFormState extends State<_LinkHabitanteForm> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Cédula',
              hintText: 'Ej. 12345678',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            keyboardType: TextInputType.number,
            enabled: !widget.linkingInProgress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Ingresa tu cédula';
              final n = int.tryParse(v.trim().replaceAll(RegExp(r'[^\d]'), ''));
              if (n == null) return 'Cédula inválida';
              if (n <= 0) return 'Cédula inválida';
              return null;
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.linkingInProgress
                ? null
                : () {
                    if (_formKey.currentState?.validate() != true) return;
                    final n = int.tryParse(
                        _controller.text.trim().replaceAll(RegExp(r'[^\d]'), ''));
                    if (n != null && n > 0) widget.onLink(n);
                  },
            icon: widget.linkingInProgress
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link_rounded, size: 20),
            label: Text(widget.linkingInProgress ? 'Vinculando…' : 'Vincular'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
