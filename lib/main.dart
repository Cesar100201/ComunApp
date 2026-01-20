import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database/db_helper.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/home/presentation/home_page.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
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
      AppLogger.warning('Firebase no disponible. La app funcionará en modo offline.');
      AppLogger.warning('Para habilitar sincronización, agregue google-services.json');
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
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              const Text(
                'Error de Inicialización',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
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
                  // Intentar reiniciar la app
                  main();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GobLaFriaApp extends StatelessWidget {
  final bool firebaseAvailable;
  
  const GobLaFriaApp({super.key, this.firebaseAvailable = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Alcaldía La Fría',
      theme: AppTheme.lightTheme,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    // Si Firebase no está disponible, ir directo a HomePage (modo offline)
    if (!firebaseAvailable) {
      return const HomePage();
    }

    // Con Firebase disponible, verificar estado de autenticación
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}




