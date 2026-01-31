import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/home/presentation/home_page.dart';

/// Pantalla mostrada cuando hay un error crítico durante la inicialización.
class ErrorInitializationScreen extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const ErrorInitializationScreen({
    super.key,
    required this.error,
    this.onRetry,
  });

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
              if (onRetry != null) ...[
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget raíz de la aplicación. Recibe [firebaseAvailable] por inyección (no global).
class GobLaFriaApp extends StatelessWidget {
  final bool firebaseAvailable;

  const GobLaFriaApp({super.key, required this.firebaseAvailable});

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
    if (!firebaseAvailable) {
      return const HomePage();
    }
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
