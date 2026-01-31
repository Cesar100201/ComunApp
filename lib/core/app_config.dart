import 'package:flutter/material.dart';
import 'contracts/habitante_repository.dart';
import 'contracts/comuna_repository.dart';
import 'contracts/consejo_repository.dart';
import 'contracts/clap_repository.dart';
import 'contracts/vinculacion_repository.dart';
import 'contracts/file_download_service.dart';
import 'contracts/notification_service.dart';

/// Un módulo mostrado en la pantalla principal (Home).
/// La lista de módulos la inyecta cada plataforma (móvil = 5, web = 3).
class HomeModuleEntry {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final void Function(BuildContext context) onTap;

  const HomeModuleEntry({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

/// Configuración de la app inyectada por plataforma.
/// El código compartido no usa globals ni kIsWeb; lee esto del contexto.
class AppConfig {
  final bool firebaseAvailable;
  final List<HomeModuleEntry> homeModules;
  final HabitanteRepository habitanteRepository;
  final ComunaRepository comunaRepository;
  final ConsejoRepository consejoRepository;
  final ClapRepository clapRepository;
  final VinculacionRepository vinculacionRepository;
  final FileDownloadService fileDownloadService;
  final NotificationService notificationService;

  const AppConfig({
    required this.firebaseAvailable,
    required this.homeModules,
    required this.habitanteRepository,
    required this.comunaRepository,
    required this.consejoRepository,
    required this.clapRepository,
    required this.vinculacionRepository,
    required this.fileDownloadService,
    required this.notificationService,
  });
}

/// Provee [AppConfig] en el árbol de widgets.
class AppConfigScope extends InheritedWidget {
  final AppConfig config;

  const AppConfigScope({
    super.key,
    required this.config,
    required super.child,
  });

  static AppConfig of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppConfigScope>();
    assert(scope != null, 'AppConfigScope not found. Wrap app with AppConfigScope.');
    return scope!.config;
  }

  @override
  bool updateShouldNotify(AppConfigScope oldWidget) =>
      config.firebaseAvailable != oldWidget.config.firebaseAvailable ||
      config.homeModules != oldWidget.config.homeModules;
}
