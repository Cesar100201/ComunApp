import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database/db_helper.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/cedula_validation_flow_page.dart';
import 'features/home/presentation/home_page.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/settings_service.dart';
import 'core/utils/logger.dart';

/// Indica si Firebase se inicializó correctamente.
bool firebaseInitialized = false;

/// Punto de entrada principal de la aplicación.
///
/// Inicializa todos los servicios necesarios antes de ejecutar la app.
/// Maneja errores de inicialización mostrando una pantalla de error si es necesario.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Intentar inicializar Firebase (opcional - puede fallar si no está configurado)
    AppLogger.info('Inicializando Firebase...');
    try {
      await Firebase.initializeApp();
      firebaseInitialized = true;
      AppLogger.info('Firebase inicializado correctamente');
    } catch (firebaseError) {
      // Firebase no está configurado - la app funcionará en modo offline
      firebaseInitialized = false;
      AppLogger.warning(
        'Firebase no disponible. La app funcionará en modo offline.',
      );
      AppLogger.warning(
        'Para habilitar sincronización, agregue google-services.json',
      );
    }

    // 2. Inicializar Base de Datos Local (Isar) - CRÍTICO
    AppLogger.info('Inicializando base de datos local...');
    await DbHelper().init();
    AppLogger.info('Base de datos local inicializada correctamente');

    // 3. Inicializar servicio de notificaciones
    AppLogger.info('Inicializando servicio de notificaciones...');
    try {
      await NotificationService().initialize();
      AppLogger.info('Servicio de notificaciones inicializado correctamente');
    } catch (notifError) {
      AppLogger.warning('Notificaciones no disponibles: $notifError');
    }

    // Las preferencias (tema, configuración) se cargan después de runApp
    // para evitar "channel-error" con SharedPreferences en Android.
    runApp(GobLaFriaApp(firebaseAvailable: firebaseInitialized));
  } catch (e, stackTrace) {
    // Si hay un error crítico en la inicialización, mostrar pantalla de error
    AppLogger.error('Error crítico durante la inicialización', e, stackTrace);

    runApp(
      MaterialApp(
        title: 'Error - Alcaldía La Fría',
        theme: AppTheme.lightTheme,
        home: ErrorInitializationScreen(error: e),
      ),
    );
  }
}

/// Pantalla mostrada cuando hay un error crítico durante la inicialización.
class ErrorInitializationScreen extends StatelessWidget {
  final Object error;

  const ErrorInitializationScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Error de Inicialización',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'No se pudo iniciar la aplicación correctamente.\n\n'
                'Por favor, cierre la aplicación e intente nuevamente.\n'
                'Si el problema persiste, contacte al soporte técnico.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // Cerrar la app para que el usuario la reinicie manualmente
                  SystemNavigator.pop();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Cerrar y Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GobLaFriaApp extends StatefulWidget {
  final bool firebaseAvailable;

  const GobLaFriaApp({super.key, this.firebaseAvailable = false});

  @override
  State<GobLaFriaApp> createState() => _GobLaFriaAppState();
}

class _GobLaFriaAppState extends State<GobLaFriaApp> {
  int _themeMode = 0;
  double _textScale = 1.0;

  @override
  void initState() {
    super.initState();
    // Cargar tema y escala después del primer frame (canal de plataforma listo).
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  Future<void> _loadSettings() async {
    try {
      await SettingsService.init();
      final t = await SettingsService.getThemeMode();
      final s = await SettingsService.getTextScale();
      if (mounted) {
        setState(() {
          _themeMode = t;
          _textScale = s;
        });
      }
    } catch (_) {
      // Usar valores por defecto si SharedPreferences no está disponible.
    }
  }

  Future<void> _refreshSettings() async {
    try {
      final t = await SettingsService.getThemeMode();
      final s = await SettingsService.getTextScale();
      if (mounted) {
        setState(() {
          _themeMode = t;
          _textScale = s;
        });
      }
    } catch (_) {
      // Mantener valores actuales si SharedPreferences falla.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Alcaldía La Fría',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeModeFromInt(_themeMode),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(_textScale)),
          child: child!,
        );
      },
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!widget.firebaseAvailable) {
      return HomePage(onSettingsChanged: _refreshSettings);
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return _AuthGate(
            user: snapshot.data!,
            onSettingsChanged: _refreshSettings,
          );
        }
        return const LoginPage();
      },
    );
  }
}

/// Muestra Home si el usuario tiene cédula vinculada; si no, el flujo de validación de cédula.
class _AuthGate extends StatelessWidget {
  final User user;
  final VoidCallback? onSettingsChanged;

  const _AuthGate({required this.user, this.onSettingsChanged});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: SettingsService.getLinkedHabitanteCedula(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          // Si falla la consulta de cédula vinculada, ir al Home como fallback
          return HomePage(onSettingsChanged: onSettingsChanged);
        }
        if (snapshot.data != null) {
          return HomePage(onSettingsChanged: onSettingsChanged);
        }
        return CedulaValidationFlowPage(onSettingsChanged: onSettingsChanged);
      },
    );
  }
}
