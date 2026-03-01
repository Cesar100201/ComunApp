import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../main.dart' show firebaseInitialized;

/// Página de configuración de la aplicación.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.onSettingsChanged,
    this.onSyncSettingsChanged,
  });

  /// Se invoca al cambiar tema o escala de texto para que la app se actualice.
  final VoidCallback? onSettingsChanged;

  /// Se invoca al cambiar sincronización automática o intervalo para reiniciar el timer.
  final VoidCallback? onSyncSettingsChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _syncCompleteNotifications = true;
  bool _autoSyncEnabled = false;
  int _syncIntervalMinutes = 30;
  bool _wifiOnlySync = false;
  int _themeMode = 0;
  double _textScale = 1.0;
  bool _appLockEnabled = false;
  bool _loading = true;
  bool _isWifi = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkConnectivity();
  }

  Future<void> _loadSettings() async {
    try {
      final notif = await SettingsService.getNotificationsEnabled();
      final syncNotif = await SettingsService.getSyncCompleteNotifications();
      final autoSync = await SettingsService.getAutoSyncEnabled();
      final interval = await SettingsService.getSyncIntervalMinutes();
      final wifiOnly = await SettingsService.getWifiOnlySync();
      final theme = await SettingsService.getThemeMode();
      final scale = await SettingsService.getTextScale();
      final lock = await SettingsService.getAppLockEnabled();
      if (mounted) {
        setState(() {
          _notificationsEnabled = notif;
          _syncCompleteNotifications = syncNotif;
          _autoSyncEnabled = autoSync;
          _syncIntervalMinutes = interval;
          _wifiOnlySync = wifiOnly;
          _themeMode = theme;
          _textScale = scale;
          _appLockEnabled = lock;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    final isWifi =
        result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.ethernet);
    if (mounted) setState(() => _isWifi = isWifi);
  }

  Future<void> _syncNow() async {
    if (!firebaseInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modo offline. No hay conexión a la nube.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }
    if (_wifiOnlySync && !_isWifi) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Configuración: sincronizar solo con Wi‑Fi. Conecte a Wi‑Fi e intente de nuevo.',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }
    Navigator.pop(context);
    final notifications = NotificationService();
    try {
      await notifications.ensureReady();
      await notifications.showSyncProgressNotification(
        progress: 0,
        stepLabel: 'Iniciando sincronización...',
      );
    } catch (_) {}
    final service = SyncService();
    service
        .sincronizarTodo(
          profunda: true,
          onProgress: (p) {
            notifications.showSyncProgressNotification(
              progress: (p.progress * 100).round().clamp(0, 100),
              stepLabel: p.stepLabel,
              subidos: p.subidos,
              descargados: p.descargados,
            );
          },
        )
        .then((resultado) async {
          final subidos = resultado['subidos'] ?? 0;
          final descargados = resultado['descargados'] ?? 0;
          await notifications.showSyncCompleteNotification(
            subidos: subidos,
            descargados: descargados,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Sincronización completada: $subidos subidos, $descargados descargados.',
                ),
                backgroundColor: AppColors.success,
              ),
            );
          }
        })
        .catchError((e, _) async {
          await notifications.showSyncErrorNotification(e.toString());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${e.toString()}'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        });
  }

  void _showThemeDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tema'),
        content: RadioGroup<int>(
          groupValue: _themeMode,
          onChanged: (v) async {
            if (v == null) return;
            await SettingsService.setThemeMode(v);
            if (mounted) {
              setState(() => _themeMode = v);
              widget.onSettingsChanged?.call();
            }
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RadioListTile<int>(title: Text('Según sistema'), value: 0),
              const RadioListTile<int>(title: Text('Claro'), value: 1),
              const RadioListTile<int>(title: Text('Oscuro'), value: 2),
            ],
          ),
        ),
      ),
    );
  }

  void _showTextScaleDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tamaño de texto'),
        content: RadioGroup<double>(
          groupValue: _textScale,
          onChanged: (v) async {
            if (v == null) return;
            await SettingsService.setTextScale(v);
            if (mounted) {
              setState(() => _textScale = v);
              widget.onSettingsChanged?.call();
            }
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RadioListTile<double>(title: Text('Normal'), value: 1.0),
              const RadioListTile<double>(title: Text('Grande'), value: 1.15),
              const RadioListTile<double>(
                title: Text('Muy grande'),
                value: 1.3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSyncIntervalDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Intervalo de sincronización'),
        content: RadioGroup<int>(
          groupValue: _syncIntervalMinutes,
          onChanged: (v) async {
            if (v == null) return;
            await SettingsService.setSyncIntervalMinutes(v);
            if (mounted) {
              setState(() => _syncIntervalMinutes = v);
              widget.onSyncSettingsChanged?.call();
            }
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [15, 30, 60].map((mins) {
              return RadioListTile<int>(
                title: Text(
                  mins == 15
                      ? 'Cada 15 minutos'
                      : mins == 30
                      ? 'Cada 30 minutos'
                      : 'Cada 1 hora',
                ),
                value: mins,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String get _themeModeLabel {
    switch (_themeMode) {
      case 1:
        return 'Claro';
      case 2:
        return 'Oscuro';
      default:
        return 'Según sistema';
    }
  }

  String get _textScaleLabel {
    if (_textScale <= 1.0) return 'Normal';
    if (_textScale <= 1.15) return 'Grande';
    return 'Muy grande';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuración')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('General'),
          _SettingsTile(
            icon: Icons.cloud_rounded,
            title: 'Estado de conexión',
            subtitle: firebaseInitialized
                ? 'Conectado a la nube'
                : 'Modo offline',
            trailing: Icon(
              firebaseInitialized ? Icons.cloud_done : Icons.cloud_off,
              color: firebaseInitialized
                  ? AppColors.success
                  : AppColors.warning,
              size: 22,
            ),
          ),
          _sectionTitle('Sincronización y datos'),
          _SettingsSwitchTile(
            icon: Icons.sync_rounded,
            title: 'Sincronización automática',
            subtitle: _autoSyncEnabled
                ? 'Activada (cada $_syncIntervalMinutes min)'
                : 'Desactivada',
            value: _autoSyncEnabled,
            onChanged: (v) async {
              await SettingsService.setAutoSyncEnabled(v);
              if (mounted) {
                setState(() => _autoSyncEnabled = v);
                widget.onSyncSettingsChanged?.call();
              }
            },
          ),
          if (_autoSyncEnabled)
            _SettingsTile(
              icon: Icons.schedule_rounded,
              title: 'Intervalo',
              subtitle: 'Cada $_syncIntervalMinutes minutos',
              onTap: _showSyncIntervalDialog,
            ),
          _SettingsSwitchTile(
            icon: Icons.wifi_rounded,
            title: 'Solo Wi‑Fi para sincronizar',
            subtitle: _wifiOnlySync ? 'Sí' : 'No',
            value: _wifiOnlySync,
            onChanged: (v) async {
              await SettingsService.setWifiOnlySync(v);
              if (mounted) setState(() => _wifiOnlySync = v);
            },
          ),
          _SettingsTile(
            icon: Icons.cloud_upload_rounded,
            title: 'Sincronizar ahora',
            subtitle: 'Enviar y recibir datos con la nube',
            onTap: _syncNow,
          ),
          _SettingsTile(
            icon: Icons.cleaning_services_rounded,
            title: 'Limpiar datos temporales',
            subtitle: 'Liberar espacio (no borra la base de datos)',
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Limpiar datos temporales'),
                  content: const Text(
                    'Se limpiarán archivos temporales. La base de datos local no se borrará.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Continuar'),
                    ),
                  ],
                ),
              );
              if (ok == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Limpieza completada.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
          ),
          _sectionTitle('Notificaciones'),
          _SettingsSwitchTile(
            icon: Icons.notifications_rounded,
            title: 'Notificaciones',
            subtitle: _notificationsEnabled ? 'Activadas' : 'Desactivadas',
            value: _notificationsEnabled,
            onChanged: (v) async {
              await SettingsService.setNotificationsEnabled(v);
              if (mounted) setState(() => _notificationsEnabled = v);
            },
          ),
          _SettingsSwitchTile(
            icon: Icons.cloud_done_rounded,
            title: 'Al terminar sincronización',
            subtitle: _syncCompleteNotifications ? 'Sí' : 'No',
            value: _syncCompleteNotifications,
            onChanged: (v) async {
              await SettingsService.setSyncCompleteNotifications(v);
              if (mounted) setState(() => _syncCompleteNotifications = v);
            },
          ),
          _sectionTitle('Apariencia'),
          _SettingsTile(
            icon: Icons.palette_rounded,
            title: 'Tema',
            subtitle: _themeModeLabel,
            onTap: _showThemeDialog,
          ),
          _SettingsTile(
            icon: Icons.text_fields_rounded,
            title: 'Tamaño de texto',
            subtitle: _textScaleLabel,
            onTap: _showTextScaleDialog,
          ),
          _sectionTitle('Privacidad y seguridad'),
          if (firebaseInitialized)
            _SettingsTile(
              icon: Icons.lock_reset_rounded,
              title: 'Cambiar contraseña',
              subtitle: 'Recibirás un correo para restablecerla',
              onTap: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user?.email == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No hay correo asociado a esta cuenta.'),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                  }
                  return;
                }
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: user!.email!,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Revisa tu correo para restablecer la contraseña.',
                        ),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
            ),
          _SettingsSwitchTile(
            icon: Icons.fingerprint_rounded,
            title: 'Bloqueo con PIN o biometría',
            subtitle: _appLockEnabled
                ? 'Activado'
                : 'Desactivado (próximamente)',
            value: _appLockEnabled,
            onChanged: (v) async {
              await SettingsService.setAppLockEnabled(v);
              if (mounted) {
                setState(() => _appLockEnabled = v);
                if (v) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'La función de bloqueo estará disponible en una próxima actualización.',
                      ),
                    ),
                  );
                }
              }
            },
          ),
          _sectionTitle('Ayuda y soporte'),
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Preguntas frecuentes',
            subtitle: 'Guía rápida de uso',
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Preguntas frecuentes'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _faqItem(
                          '¿Cómo sincronizo?',
                          'Ve a Centro de Sincronización en la pantalla principal y elige sincronización rápida o completa.',
                        ),
                        _faqItem(
                          '¿Puedo usar la app sin internet?',
                          'Sí. Los datos se guardan localmente y se sincronizarán cuando haya conexión.',
                        ),
                        _faqItem(
                          '¿Dónde se guardan los datos?',
                          'En tu dispositivo y en la nube (Firebase) cuando sincronizas.',
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.mail_outline_rounded,
            title: 'Contactar soporte',
            subtitle: 'Alcaldía de La Fría',
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Contactar soporte'),
                  content: const Text(
                    'Para soporte técnico o consultas sobre la Sala Situacional, '
                    'contacte a la Alcaldía de La Fría.\n\n'
                    'La función de envío de correo estará disponible en una próxima actualización.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.policy_rounded,
            title: 'Política de privacidad',
            subtitle: 'Términos y condiciones',
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Política de privacidad'),
                  content: const SingleChildScrollView(
                    child: Text(
                      'Los datos que usted registra en esta aplicación son utilizados '
                      'exclusivamente para la gestión municipal de la Alcaldía de La Fría. '
                      'Se almacenan de forma segura y se sincronizan con los sistemas oficiales.\n\n'
                      'Para más información, contacte a la Alcaldía.',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            },
          ),
          _sectionTitle('Acerca de'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Sala Situacional',
            subtitle: 'Alcaldía de La Fría',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Sala Situacional',
                applicationVersion: '1.0.0',
                applicationLegalese: '© Alcaldía de La Fría',
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _faqItem(String q, String a) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(a, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 22),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing:
            trailing ??
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 22),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}
