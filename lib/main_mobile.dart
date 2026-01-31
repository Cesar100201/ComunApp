import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database/db_helper.dart';
import 'core/theme/app_theme.dart';
import 'core/app_config.dart';
import 'mobile/services/notification_service_mobile.dart';
import 'core/services/sync_service.dart';
import 'core/utils/logger.dart';
import 'core/utils/constants.dart' show QuotaExceededException;
import 'mobile/repositories/habitante_repository_isar.dart';
import 'app.dart';
import 'features/comunas/data/repositories/comuna_repository.dart';
import 'features/consejos/data/repositories/consejo_repository.dart';
import 'features/claps/data/repositories/clap_repository.dart';
import 'features/inhabitants/data/repositories/vinculacion_repository.dart';
import 'mobile/services/file_download_service_mobile.dart';
import 'features/local/presentation/local_menu_page.dart';
import 'features/registros/presentation/registros_menu_page.dart';
import 'features/solicitudes/presentation/solicitudes_menu_page.dart';
import 'features/reportes/presentation/reportes_main_page.dart';

/// Punto de entrada para móvil/desktop (dart.library.io).
/// No se compila para web. Inicializa Isar, notificaciones y SyncService.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseInitialized = false;
  try {
    AppLogger.info('Inicializando Firebase...');
    try {
      await Firebase.initializeApp();
      firebaseInitialized = true;
      AppLogger.info('Firebase inicializado correctamente');
    } catch (firebaseError) {
      firebaseInitialized = false;
      AppLogger.warning('Firebase no disponible. La app funcionará en modo offline.');
    }

    AppLogger.info('Inicializando base de datos local...');
    await DbHelper().init();
    AppLogger.info('Base de datos local inicializada correctamente');

    final notificationService = NotificationServiceMobile();
    AppLogger.info('Inicializando servicio de notificaciones...');
    try {
      await notificationService.initialize();
      AppLogger.info('Servicio de notificaciones inicializado correctamente');
    } catch (notifError) {
      AppLogger.warning('Notificaciones no disponibles: $notifError');
    }

    final db = await DbHelper().db;
    final config = AppConfig(
      firebaseAvailable: firebaseInitialized,
      homeModules: _buildMobileHomeModules(),
      habitanteRepository: HabitanteRepositoryIsar(db),
      comunaRepository: ComunaRepository(db),
      consejoRepository: ConsejoRepository(db),
      clapRepository: ClapRepository(db),
      vinculacionRepository: VinculacionRepository(db),
      fileDownloadService: FileDownloadServiceMobile(),
      notificationService: notificationService,
    );

    runApp(
      AppConfigScope(
        config: config,
        child: GobLaFriaApp(firebaseAvailable: firebaseInitialized),
      ),
    );
  } catch (e, stackTrace) {
    AppLogger.error('Error crítico durante la inicialización', e, stackTrace);
    runApp(
      MaterialApp(
        title: 'Error - Alcaldía La Fría',
        theme: AppTheme.lightTheme,
        home: ErrorInitializationScreen(
          error: e,
          onRetry: main,
        ),
      ),
    );
  }
}

List<HomeModuleEntry> _buildMobileHomeModules() {
  return [
    HomeModuleEntry(
      title: 'Base de Datos Local',
      description: 'Ver y gestionar todos los registros locales.',
      icon: Icons.storage_rounded,
      color: AppColors.primary,
      onTap: (context) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LocalMenuPage(),
          ),
        );
      },
    ),
    HomeModuleEntry(
      title: 'Registros',
      description: 'Gestionar habitantes, comunas, consejos comunales, organizaciones y CLAPs.',
      icon: Icons.app_registration_rounded,
      color: AppColors.primary,
      onTap: (context) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const RegistrosMenuPage(),
          ),
        );
      },
    ),
    HomeModuleEntry(
      title: 'Gestión de Solicitudes',
      description: 'Registrar y administrar solicitudes de luminarias.',
      icon: Icons.lightbulb_outline_rounded,
      color: AppColors.info,
      onTap: (context) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SolicitudesMenuPage(),
          ),
        );
      },
    ),
    HomeModuleEntry(
      title: 'Módulo de Reportes',
      description: 'Reportar soluciones y consultar estadísticas municipales.',
      icon: Icons.assignment_turned_in_rounded,
      color: AppColors.success,
      onTap: (context) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ReportesMainPage(),
          ),
        );
      },
    ),
    HomeModuleEntry(
      title: 'Centro de Sincronización',
      description: 'Sincronizar datos bidireccionalmente entre local y nube.',
      icon: Icons.cloud_upload_rounded,
      color: AppColors.primaryDark,
      onTap: _onSyncTap,
    ),
  ];
}

Future<void> _onSyncTap(BuildContext context) async {
  if (!context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Sincronizando datos...'),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    final servicio = SyncService();
    final resultado = await servicio.sincronizarTodo();
    final subidos = resultado['subidos'] ?? 0;
    final descargados = resultado['descargados'] ?? 0;

    if (context.mounted) {
      Navigator.pop(context);
      if (subidos > 0 || descargados > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Sincronización completa:\n'
              '• $subidos registro(s) subido(s) a la nube\n'
              '• $descargados registro(s) descargado(s) desde la nube',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '👍 Todo está al día. Las bases de datos local y nube están sincronizadas.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  } on QuotaExceededException catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryUltraLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (e.registrosSubidos != null)
                      Text(
                        '✓ Registros subidos: ${e.registrosSubidos}',
                        style: const TextStyle(color: AppColors.success),
                      ),
                    if (e.registrosPendientes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '⏳ Pendientes: ${e.registrosPendientes}',
                          style: const TextStyle(color: AppColors.warning),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('¿Qué hacer?', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('• La cuota se reinicia cada 24 horas'),
              const Text('• Los datos están guardados localmente'),
              const Text('• Intente sincronizar mañana'),
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
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
