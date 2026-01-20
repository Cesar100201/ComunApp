import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/presentation/login_page.dart';
import '../../inhabitants/presentation/habitantes_menu_page.dart';
import '../../local/presentation/local_menu_page.dart';
import '../../comunas/presentation/add_comuna_page.dart';
import '../../consejos/presentation/add_consejo_page.dart';
import '../../organizations/presentation/add_organizacion_page.dart';
import '../../claps/presentation/add_clap_page.dart';
import '../../solicitudes/presentation/add_solicitud_page.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/theme/app_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
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
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => _logout(context),
            tooltip: "Cerrar sesión",
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

          // MÓDULO 2: HABITANTES (Abre el sub-menú)
          _buildModuleCard(
            context,
            title: "Gestión de Habitantes",
            description: "Registro y búsqueda de ciudadanos.",
            icon: Icons.groups_rounded,
            color: AppColors.primaryLight,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HabitantesMenuPage(),
                ),
              );
            },
          ),

          // MÓDULO 3: COMUNAS
          _buildModuleCard(
            context,
            title: "Gestión de Comunas",
            description: "Registrar y administrar comunas.",
            icon: Icons.location_city_rounded,
            color: AppColors.info,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddComunaPage(),
                ),
              );
            },
          ),

          // MÓDULO 4: CONSEJOS COMUNALES
          _buildModuleCard(
            context,
            title: "Gestión de Consejos Comunales",
            description: "Registrar consejos comunales y comunidades.",
            icon: Icons.groups_rounded,
            color: AppColors.primaryLight,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddConsejoPage(),
                ),
              );
            },
          ),

          // MÓDULO 5: ORGANIZACIONES
          _buildModuleCard(
            context,
            title: "Gestión de Organizaciones",
            description: "Registrar organizaciones políticas y sociales.",
            icon: Icons.business_rounded,
            color: AppColors.warning,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddOrganizacionPage(),
                ),
              );
            },
          ),

          // MÓDULO 6: CLAPS
          _buildModuleCard(
            context,
            title: "Gestión de CLAPs",
            description: "Registrar Comités Locales de Abastecimiento.",
            icon: Icons.store_rounded,
            color: AppColors.success,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddClapPage(),
                ),
              );
            },
          ),

          // MÓDULO 7: PLAN GARCÍA DE HEVIA ILUMINADA 2026
          _buildModuleCard(
            context,
            title: "Plan García de Hevia Iluminada 2026",
            description: "Registrar y administrar solicitudes de luminarias.",
            icon: Icons.lightbulb_outline_rounded,
            color: AppColors.info,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddSolicitudPage(),
                ),
              );
            },
          ),

          // MÓDULO 8: SINCRONIZACIÓN
          _buildModuleCard(
            context,
            title: "Centro de Sincronización",
            description: "Sincronizar datos bidireccionalmente entre local y nube.",
            icon: Icons.cloud_upload_rounded,
            color: AppColors.primaryDark,
            onTap: () async {
              // Mostramos diálogo de progreso
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
                          Text("Sincronizando datos..."),
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
                  Navigator.pop(context); // Cerrar diálogo de progreso
                  
                  if (subidos > 0 || descargados > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "✅ Sincronización completa:\n"
                          "• $subidos registro(s) subido(s) a la nube\n"
                          "• $descargados registro(s) descargado(s) desde la nube",
                        ),
                        backgroundColor: AppColors.success,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "👍 Todo está al día. Las bases de datos local y nube están sincronizadas.",
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Cerrar diálogo de progreso
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("❌ Error: ${e.toString()}"),
                      backgroundColor: AppColors.error,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
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
