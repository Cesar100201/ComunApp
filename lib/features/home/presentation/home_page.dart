import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../local/presentation/local_menu_page.dart';
import '../../registros/presentation/registros_menu_page.dart';
import '../../solicitudes/presentation/solicitudes_menu_page.dart';
import '../../reportes/presentation/reportes_main_page.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/sync_service.dart' show SyncService, SyncProgress;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/constants.dart' show QuotaExceededException;
import '../../../../main.dart' show firebaseInitialized;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  /// Inicia la sincronización en segundo plano. El progreso se muestra como
  /// notificación fija (no eliminable) en la barra de notificaciones.
  Future<void> _startSyncInBackground(BuildContext context) async {
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
          SnackBar(
            content: Text('No se pueden mostrar notificaciones. Active las notificaciones en ajustes.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final servicio = SyncService();
    servicio.sincronizarTodo(
      onProgress: (SyncProgress p) {
        final percent = (p.progress * 100).round().clamp(0, 100);
        notifications.showSyncProgressNotification(
          progress: percent,
          stepLabel: p.stepLabel,
          subidos: p.subidos,
          descargados: p.descargados,
        );
      },
    ).then((resultado) async {
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
    }).catchError((Object e, StackTrace _) async {
      await notifications.showSyncErrorNotification(
        e is QuotaExceededException
            ? 'Cuota de Firebase excedida. Intente mañana.'
            : e.toString(),
      );
      if (context.mounted) {
        if (e is QuotaExceededException) {
          final q = e as QuotaExceededException;
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Cuota de Firebase Excedida')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Se ha alcanzado el límite diario de escrituras en Firebase.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  if (q.registrosSubidos != null)
                    Text('✓ Subidos: ${q.registrosSubidos}', style: TextStyle(color: AppColors.success)),
                  if (q.registrosPendientes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('⏳ Pendientes: ${q.registrosPendientes}', style: TextStyle(color: AppColors.warning)),
                    ),
                  const SizedBox(height: 16),
                  const Text('• La cuota se reinicia cada 24 h\n• Intente sincronizar mañana'),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ENTENDIDO'),
                ),
              ],
            ),
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

  Future<void> _logout(BuildContext context) async {
    // Verificar si Firebase está disponible
    if (!firebaseInitialized) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La aplicación está en modo offline. No hay sesión activa.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Mostrar diálogo de confirmación
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
      // Solo hacer signOut - el StreamBuilder en main.dart
      // detectará el cambio y navegará al LoginPage automáticamente
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          // Solo mostrar botón de logout si Firebase está disponible
          if (firebaseInitialized)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () => _logout(context),
              tooltip: "Cerrar sesión",
            )
          else
            // Indicador de modo offline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Chip(
                avatar: const Icon(Icons.cloud_off, size: 16, color: Colors.white),
                label: const Text('Offline', style: TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: Colors.orange,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Encabezado
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              "Módulos de Gestión",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
          ),

          // MÓDULO 1: BASE DE DATOS LOCAL
          _buildModuleCard(
            context,
            title: "Base de Datos Local",
            description: "Ver y gestionar todos los registros locales.",
            icon: Icons.storage_rounded,
            color: AppColors.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LocalMenuPage(),
                ),
              );
            },
          ),

          // MÓDULO 2: REGISTROS
          _buildModuleCard(
            context,
            title: "Registros",
            description: "Gestionar habitantes, comunas, consejos comunales, organizaciones y CLAPs.",
            icon: Icons.app_registration_rounded,
            color: AppColors.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RegistrosMenuPage(),
                ),
              );
            },
          ),

          // MÓDULO 3: GESTIÓN DE SOLICITUDES
          _buildModuleCard(
            context,
            title: "Gestión de Solicitudes",
            description: "Registrar y administrar solicitudes de luminarias.",
            icon: Icons.lightbulb_outline_rounded,
            color: AppColors.info,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SolicitudesMenuPage(),
                ),
              );
            },
          ),

          // MÓDULO 4: REPORTES
          _buildModuleCard(
            context,
            title: "Módulo de Reportes",
            description: "Reportar soluciones y consultar estadísticas municipales.",
            icon: Icons.assignment_turned_in_rounded,
            color: AppColors.success,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReportesMainPage(),
                ),
              );
            },
          ),

          // MÓDULO 5: SINCRONIZACIÓN
          _buildModuleCard(
            context,
            title: "Centro de Sincronización",
            description: "Sincronizar datos bidireccionalmente entre local y nube.",
            icon: Icons.cloud_upload_rounded,
            color: AppColors.primaryDark,
            onTap: () async {
              if (!context.mounted) return;
              await _startSyncInBackground(context);
            },
          ),
        ],
      ),
    );
  }

  // WIDGET DE TARJETA HORIZONTAL (Diseño minimalista y futurista)
  Widget _buildModuleCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icono con fondo degradado
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.shadowSmall,
                ),
                child: Icon(icon, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 16),

              // Textos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
