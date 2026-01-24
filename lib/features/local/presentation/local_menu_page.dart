import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';
import '../../../../models/models.dart';
import '../../inhabitants/presentation/habitantes_list_page.dart';
import '../../comunas/presentation/comunas_list_page.dart';
import '../../consejos/presentation/consejos_comunales_list_page.dart';
import '../../organizations/presentation/organizaciones_list_page.dart';
import '../../claps/presentation/claps_list_page.dart';
import '../../solicitudes/presentation/solicitudes_list_page.dart';

class LocalMenuPage extends StatefulWidget {
  const LocalMenuPage({super.key});

  @override
  State<LocalMenuPage> createState() => _LocalMenuPageState();
}

class _LocalMenuPageState extends State<LocalMenuPage> {
  int _sincronizados = 0;
  int _pendientes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    setState(() => _isLoading = true);
    
    try {
      final isar = await DbHelper().db;
      
      // Contar registros sincronizados y pendientes de todas las colecciones
      int sincronizados = 0;
      int pendientes = 0;
      
      // Habitantes
      final todosHabitantes = await isar.habitantes
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      final habitantesSync = todosHabitantes.where((h) => h.isSynced == true).length;
      final habitantesPend = todosHabitantes.where((h) => h.isSynced == false).length;
      sincronizados += habitantesSync;
      pendientes += habitantesPend;
      
      // Organizaciones
      final todasOrgs = await isar.organizacions
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      final orgsSync = todasOrgs.where((o) => o.isSynced == true).length;
      final orgsPend = todasOrgs.where((o) => o.isSynced == false).length;
      sincronizados += orgsSync;
      pendientes += orgsPend;
      
      // Vinculaciones
      final todasVinculaciones = await isar.vinculacions
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      final vincSync = todasVinculaciones.where((v) => v.isSynced == true).length;
      final vincPend = todasVinculaciones.where((v) => v.isSynced == false).length;
      sincronizados += vincSync;
      pendientes += vincPend;
      
      // Consejos Comunales
      final todosConsejos = await isar.consejoComunals
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      final consejosSync = todosConsejos.where((c) => c.isSynced == true).length;
      final consejosPend = todosConsejos.where((c) => c.isSynced == false).length;
      sincronizados += consejosSync;
      pendientes += consejosPend;
      
      // Comunas
      final todasComunas = await isar.comunas
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      final comunasSync = todasComunas.where((c) => c.isSynced == true).length;
      final comunasPend = todasComunas.where((c) => c.isSynced == false).length;
      sincronizados += comunasSync;
      pendientes += comunasPend;
      
      // Proyectos
      final todosProyectos = await isar.proyectos
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      final proyectosSync = todosProyectos.where((p) => p.isSynced == true).length;
      final proyectosPend = todosProyectos.where((p) => p.isSynced == false).length;
      sincronizados += proyectosSync;
      pendientes += proyectosPend;
      
      // CLAPs
      final todosClaps = await isar.claps
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      final clapsSync = todosClaps.where((c) => c.isSynced == true).length;
      final clapsPend = todosClaps.where((c) => c.isSynced == false).length;
      sincronizados += clapsSync;
      pendientes += clapsPend;
      
      // Solicitudes
      final todasSolicitudes = await isar.solicituds
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      final solicitudesSync = todasSolicitudes.where((s) => s.isSynced == true).length;
      final solicitudesPend = todasSolicitudes.where((s) => s.isSynced == false).length;
      sincronizados += solicitudesSync;
      pendientes += solicitudesPend;
      
      // Reportes
      final todosReportes = await isar.reportes
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      final reportesSync = todosReportes.where((r) => r.isSynced == true).length;
      final reportesPend = todosReportes.where((r) => r.isSynced == false).length;
      sincronizados += reportesSync;
      pendientes += reportesPend;
      
      if (mounted) {
        setState(() {
          _sincronizados = sincronizados;
          _pendientes = pendientes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Base de Datos Local"),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildContador(
                    icon: Icons.cloud_done,
                    cantidad: _sincronizados,
                    color: AppColors.success,
                    tooltip: "En línea",
                  ),
                  const SizedBox(width: 12),
                  _buildContador(
                    icon: Icons.cloud_off,
                    cantidad: _pendientes,
                    color: AppColors.warning,
                    tooltip: "Pendientes",
                  ),
                ],
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // HABITANTES
          _buildActionCard(
            context,
            title: "Habitantes",
            subtitle: "Ver lista completa y estatus de sincronización",
            icon: Icons.people_rounded,
            color: AppColors.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HabitantesListPage()),
            ),
          ),

          // COMUNAS
          _buildActionCard(
            context,
            title: "Comunas",
            subtitle: "Ver lista de comunas registradas",
            icon: Icons.location_city_rounded,
            color: AppColors.info,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComunasListPage()),
            ),
          ),

          // CONSEJOS COMUNALES
          _buildActionCard(
            context,
            title: "Consejos Comunales",
            subtitle: "Ver y editar consejos comunales registrados",
            icon: Icons.groups_rounded,
            color: AppColors.primaryLight,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConsejosComunalesListPage()),
            ),
          ),

          // ORGANIZACIONES
          _buildActionCard(
            context,
            title: "Organizaciones",
            subtitle: "Ver lista de organizaciones",
            icon: Icons.business_rounded,
            color: AppColors.warning,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrganizacionesListPage()),
            ),
          ),

          // CLAPS
          _buildActionCard(
            context,
            title: "CLAPs",
            subtitle: "Ver lista de Comités Locales de Abastecimiento",
            icon: Icons.store_rounded,
            color: AppColors.success,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClapsListPage()),
            ),
          ),

          // SOLICITUDES
          _buildActionCard(
            context,
            title: "Solicitudes",
            subtitle: "Ver y gestionar solicitudes de la comunidad",
            icon: Icons.assignment_rounded,
            color: AppColors.info,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SolicitudesListPage()),
            ),
          ),
        ],
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
              onPressed: _cargarEstadisticas,
              tooltip: "Actualizar estadísticas",
              child: const Icon(Icons.refresh),
            ),
    );
  }

  Widget _buildContador({
    required IconData icon,
    required int cantidad,
    required Color color,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              cantidad.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
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
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.shadowSmall,
                ),
                child: Icon(icon, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 20),
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
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
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
