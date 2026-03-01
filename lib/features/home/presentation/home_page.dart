import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../local/presentation/local_menu_page.dart';
import '../../registros/presentation/registros_menu_page.dart';
import '../../gestion_municipal/presentation/gestion_municipal_menu_page.dart';
import '../../formacion/presentation/formacion_menu_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../../notifications/presentation/notifications_page.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/sync_service.dart'
    show SyncService, SyncProgress;
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/user_role_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/module_action_card.dart';
import '../../../../core/widgets/drawer_tile.dart';
import '../../../../core/utils/constants.dart'
    show AppConstants, QuotaExceededException;
import '../../../../main.dart' show firebaseInitialized;
import 'sync_dialogs.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onSettingsChanged});

  /// Se invoca cuando el usuario cambia tema o escala en Configuración.
  final VoidCallback? onSettingsChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _autoSyncTimer;
  bool _formacionModuleEnabled = true;
  int _nivelUsuario = AppConstants.nivelInvitado;
  final UserRoleService _roleService = UserRoleService();

  @override
  void initState() {
    super.initState();
    _startAutoSyncTimer();
    _loadFormacionModuleEnabled();
    _loadNivelUsuario();
  }

  Future<void> _loadNivelUsuario() async {
    final nivel = await _roleService.getNivelUsuario();
    if (mounted) setState(() => _nivelUsuario = nivel);
  }

  Future<void> _loadFormacionModuleEnabled() async {
    final enabled = await SettingsService.getFormacionModuleEnabled();
    if (mounted) setState(() => _formacionModuleEnabled = enabled);
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  //  SINCRONIZACIÓN AUTOMÁTICA
  // ══════════════════════════════════════════════════════════════

  /// Inicia el timer de sincronización automática si está activada en configuración.
  Future<void> _startAutoSyncTimer() async {
    _autoSyncTimer?.cancel();
    final enabled = await SettingsService.getAutoSyncEnabled();
    if (!enabled || !firebaseInitialized) return;
    final minutes = await SettingsService.getSyncIntervalMinutes();
    final duration = Duration(minutes: minutes);
    _autoSyncTimer = Timer.periodic(duration, (_) => _runAutoSync());
  }

  /// Ejecuta una sincronización automática (respetando solo Wi‑Fi si está activo).
  Future<void> _runAutoSync() async {
    final enabled = await SettingsService.getAutoSyncEnabled();
    if (!enabled) {
      _autoSyncTimer?.cancel();
      return;
    }
    if (!firebaseInitialized) return;
    final wifiOnly = await SettingsService.getWifiOnlySync();
    if (wifiOnly) {
      final result = await Connectivity().checkConnectivity();
      final isWifi =
          result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.ethernet);
      if (!isWifi) return;
    }
    final notifications = NotificationService();
    try {
      await notifications.ensureReady();
      await notifications.showSyncProgressNotification(
        progress: 0,
        stepLabel: 'Sincronización automática...',
      );
    } catch (_) {
      return;
    }
    final service = SyncService();
    service
        .sincronizarTodo(
          profunda: false,
          onProgress: (SyncProgress p) {
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
          final showNotif =
              await SettingsService.getSyncCompleteNotifications();
          if (showNotif) {
            await notifications.showSyncCompleteNotification(
              subidos: subidos,
              descargados: descargados,
            );
          }
        })
        .catchError((Object e, _) async {
          await notifications.showSyncErrorNotification(
            e is QuotaExceededException
                ? 'Cuota de Firebase excedida. Intente mañana.'
                : e.toString(),
          );
        });
  }

  // ══════════════════════════════════════════════════════════════
  //  SINCRONIZACIÓN MANUAL (BACKGROUND)
  // ══════════════════════════════════════════════════════════════

  /// Inicia la sincronización en segundo plano con notificaciones de progreso.
  Future<void> _startSyncInBackground(
    BuildContext context, {
    required bool profunda,
  }) async {
    final notifications = NotificationService();
    try {
      await notifications.ensureReady();
      await notifications.showSyncProgressNotification(
        progress: 0,
        stepLabel: 'Iniciando sincronización...',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pueden mostrar notificaciones. Active las notificaciones en ajustes.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final servicio = SyncService();
    servicio
        .sincronizarTodo(
          profunda: profunda,
          onProgress: (SyncProgress p) {
            final percent = (p.progress * 100).round().clamp(0, 100);
            notifications.showSyncProgressNotification(
              progress: percent,
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
          if (context.mounted) {
            if (subidos > 0 || descargados > 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "✅ Sincronización completa: $subidos subidos, $descargados descargados.",
                  ),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 4),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("👍 Todo está al día. Datos sincronizados."),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        })
        .catchError((Object e, StackTrace _) async {
          await notifications.showSyncErrorNotification(
            e is QuotaExceededException
                ? 'Cuota de Firebase excedida. Intente mañana.'
                : e.toString(),
          );
          if (context.mounted) {
            if (e is QuotaExceededException) {
              SyncDialogs.showQuotaExceededDialog(
                context,
                registrosSubidos: e.registrosSubidos,
                registrosPendientes: e.registrosPendientes,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("❌ Error: ${e.toString()}"),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        });
  }

  // ══════════════════════════════════════════════════════════════
  //  SESIÓN
  // ══════════════════════════════════════════════════════════════

  Future<void> _logout(BuildContext context) async {
    if (!firebaseInitialized) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La aplicación está en modo offline. No hay sesión activa.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Está seguro que desea cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  Future<void> _requestDeepSyncAsInvited(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('deepSyncRequests').add({
        'userId': user.uid,
        'email': user.email ?? 'Sin correo',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Su solicitud ha sido enviada. Un administrador la revisará.',
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar solicitud: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Sala Situacional"),
            Text(
              "Alcaldía de La Fría",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          if (_roleService.canApproveDeepSync(_nivelUsuario))
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsPage(),
                  ),
                );
              },
              tooltip: 'Notificaciones',
            ),
          if (!firebaseInitialized)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Chip(
                avatar: Icon(Icons.cloud_off, size: 16, color: Colors.white),
                label: Text(
                  'Offline',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: AppColors.warning,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
      drawer: _buildDrawer(context, user),
      body: _buildModuleList(context),
    );
  }

  Widget _buildDrawer(BuildContext context, User? user) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  user?.displayName ?? 'Usuario',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? 'Sin sesión',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                DrawerTile(
                  icon: Icons.person_rounded,
                  title: 'Perfil',
                  subtitle: 'Ver y editar tu información',
                  color: AppModulePastel.habitantes,
                  colorAccent: AppModulePastel.habitantesAccent,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilePage(
                          onSettingsChanged: widget.onSettingsChanged,
                          onSyncSettingsChanged: _startAutoSyncTimer,
                        ),
                      ),
                    );
                  },
                ),
                DrawerTile(
                  icon: Icons.settings_rounded,
                  title: 'Configuración',
                  subtitle: 'Ajustes de la aplicación',
                  color: AppModulePastel.sincronizacion,
                  colorAccent: AppModulePastel.sincronizacionAccent,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingsPage(
                          onSettingsChanged: widget.onSettingsChanged,
                          onSyncSettingsChanged: _startAutoSyncTimer,
                        ),
                      ),
                    );
                  },
                ),
                if (firebaseInitialized) ...[
                  const Divider(height: 24, indent: 20, endIndent: 20),
                  DrawerTile(
                    icon: Icons.logout_rounded,
                    title: 'Cerrar sesión',
                    subtitle: 'Salir de tu cuenta',
                    color: AppColors.error,
                    colorAccent: AppColors.error,
                    onTap: () {
                      Navigator.pop(context);
                      _logout(context);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleList(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Encabezado
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text(
            "Módulos de Gestión",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),

        // MÓDULO 1: BASE DE DATOS LOCAL
        ModuleActionCard(
          title: "Base de Datos Local",
          subtitle: "Ver y gestionar todos los registros locales.",
          icon: Icons.storage_rounded,
          color: AppModulePastel.baseDatos,
          colorAccent: AppModulePastel.baseDatosAccent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LocalMenuPage()),
            );
          },
        ),

        // MÓDULO 2: REGISTROS (solo admin y generador)
        if (_roleService.canAccessRegistros(_nivelUsuario))
          ModuleActionCard(
            title: "Registros",
            subtitle:
                "Gestionar habitantes, comunas, consejos comunales, organizaciones y CLAPs.",
            icon: Icons.app_registration_rounded,
            color: AppModulePastel.registros,
            colorAccent: AppModulePastel.registrosAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RegistrosMenuPage(),
                ),
              );
            },
          ),
        if (_roleService.canAccessRegistros(_nivelUsuario))
          const SizedBox(height: 12),

        // MÓDULO 3: GESTIÓN MUNICIPAL
        ModuleActionCard(
          title: "Gestión Municipal",
          subtitle: "Solicitudes, reportes y administración municipal.",
          icon: Icons.apartment_rounded,
          color: AppModulePastel.gestionMunicipal,
          colorAccent: AppModulePastel.gestionMunicipalAccent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const GestionMunicipalMenuPage(),
              ),
            );
          },
        ),

        // MÓDULO 4: FORMACIÓN
        if (_formacionModuleEnabled)
          ModuleActionCard(
            title: "Formación",
            subtitle: "Cursos, talleres y capacitaciones.",
            icon: Icons.school_rounded,
            color: AppModulePastel.formacion,
            colorAccent: AppModulePastel.formacionAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FormacionMenuPage(),
                ),
              );
            },
          ),

        // MÓDULO 5: SINCRONIZACIÓN
        ModuleActionCard(
          title: "Centro de Sincronización",
          subtitle: "Sincronizar datos bidireccionalmente entre local y nube.",
          icon: Icons.cloud_upload_rounded,
          color: AppModulePastel.sincronizacion,
          colorAccent: AppModulePastel.sincronizacionAccent,
          onTap: () async {
            if (!context.mounted) return;
            if (_roleService.canRunDeepSyncDirectly(_nivelUsuario)) {
              final tipo = await SyncDialogs.showSyncTypeDialog(context);
              if (!context.mounted || tipo == null) return;
              await _startSyncInBackground(context, profunda: tipo);
            } else {
              final ok = await SyncDialogs.showInvitedSyncDialog(context);
              if (!context.mounted) return;
              if (ok == true) {
                await _startSyncInBackground(context, profunda: false);
              } else if (ok == false) {
                await _requestDeepSyncAsInvited(context);
              }
            }
          },
        ),
      ],
    );
  }
}
