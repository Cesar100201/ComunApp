import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/app_config.dart';
import 'web/repositories/habitante_repository_firestore.dart';
import 'web/repositories/comuna_repository_firestore.dart';
import 'web/repositories/consejo_repository_firestore.dart';
import 'web/repositories/clap_repository_firestore.dart';
import 'web/repositories/vinculacion_repository_firestore.dart';
import 'web/services/file_download_service_web.dart';
import 'web/services/notification_service_web.dart';
import 'app.dart';
import 'features/registros/presentation/registros_menu_page.dart';
import 'features/solicitudes/presentation/solicitudes_menu_page.dart';
import 'features/reportes/presentation/reportes_main_page.dart';

/// Punto de entrada para web (dart.library.html).
/// No se compila para móvil. Solo Firebase; sin Isar, SyncService ni notificaciones locales.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    // En web Firebase es obligatorio; si falla mostramos error
    runApp(
      MaterialApp(
        title: 'Alcaldía La Fría',
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Error al conectar con Firebase',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text('$e', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  final config = AppConfig(
    firebaseAvailable: true,
    homeModules: _buildWebHomeModules(),
    habitanteRepository: HabitanteRepositoryFirestore(),
    comunaRepository: ComunaRepositoryFirestore(),
    consejoRepository: ConsejoRepositoryFirestore(),
    clapRepository: ClapRepositoryFirestore(),
    vinculacionRepository: VinculacionRepositoryFirestore(),
    fileDownloadService: FileDownloadServiceWeb(),
    notificationService: NotificationServiceWeb(),
  );

  runApp(
    AppConfigScope(
      config: config,
      child: const GobLaFriaApp(firebaseAvailable: true),
    ),
  );
}

List<HomeModuleEntry> _buildWebHomeModules() {
  return [
    HomeModuleEntry(
      title: 'Registros',
      description: 'Gestionar habitantes, comunas, consejos comunales, organizaciones y CLAPs.',
      icon: Icons.app_registration_rounded,
      color: AppColors.primary,
      onTap: _navigateToRegistros,
    ),
    HomeModuleEntry(
      title: 'Gestión de Solicitudes',
      description: 'Registrar y administrar solicitudes de luminarias.',
      icon: Icons.lightbulb_outline_rounded,
      color: AppColors.info,
      onTap: _navigateToSolicitudes,
    ),
    HomeModuleEntry(
      title: 'Módulo de Reportes',
      description: 'Reportar soluciones y consultar estadísticas municipales.',
      icon: Icons.assignment_turned_in_rounded,
      color: AppColors.success,
      onTap: _navigateToReportes,
    ),
  ];
}

void _navigateToRegistros(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const RegistrosMenuPage(),
    ),
  );
}

void _navigateToSolicitudes(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const SolicitudesMenuPage(),
    ),
  );
}

void _navigateToReportes(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const ReportesMainPage(),
    ),
  );
}
