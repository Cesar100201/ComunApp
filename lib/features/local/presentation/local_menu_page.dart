import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/user_role_service.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/widgets/module_action_card.dart';
import '../../../../database/db_helper.dart';
import '../../../../models/models.dart';
import '../../inhabitants/presentation/habitantes_list_page.dart';
import '../../inhabitants/presentation/extranjeros_list_page.dart';
import '../../comunas/presentation/comunas_list_page.dart';
import '../../consejos/presentation/consejos_comunales_list_page.dart';
import '../../organizations/presentation/organizaciones_list_page.dart';
import '../../claps/presentation/claps_list_page.dart';
import '../../solicitudes/presentation/solicitudes_list_page.dart';
import 'pendientes_sync_page.dart';

class LocalMenuPage extends StatefulWidget {
  const LocalMenuPage({super.key});

  @override
  State<LocalMenuPage> createState() => _LocalMenuPageState();
}

class _LocalMenuPageState extends State<LocalMenuPage> {
  int _sincronizados = 0;
  int _pendientes = 0;
  bool _isLoading = true;
  int _nivelUsuario = AppConstants.nivelInvitado;
  final UserRoleService _roleService = UserRoleService();

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
    _roleService.getNivelUsuario().then((n) {
      if (mounted) setState(() => _nivelUsuario = n);
    });
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
      final habitantesSync = todosHabitantes
          .where((h) => h.isSynced == true)
          .length;
      final habitantesPend = todosHabitantes
          .where((h) => h.isSynced == false)
          .length;
      sincronizados += habitantesSync;
      pendientes += habitantesPend;

      // Extranjeros
      final todosExtranjeros = await isar.extranjeros
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      final extranjerosSync = todosExtranjeros
          .where((e) => e.isSynced == true)
          .length;
      final extranjerosPend = todosExtranjeros
          .where((e) => e.isSynced == false)
          .length;
      sincronizados += extranjerosSync;
      pendientes += extranjerosPend;

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
      final vincSync = todasVinculaciones
          .where((v) => v.isSynced == true)
          .length;
      final vincPend = todasVinculaciones
          .where((v) => v.isSynced == false)
          .length;
      sincronizados += vincSync;
      pendientes += vincPend;

      // Consejos Comunales
      final todosConsejos = await isar.consejoComunals
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      final consejosSync = todosConsejos
          .where((c) => c.isSynced == true)
          .length;
      final consejosPend = todosConsejos
          .where((c) => c.isSynced == false)
          .length;
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
      final proyectosSync = todosProyectos
          .where((p) => p.isSynced == true)
          .length;
      final proyectosPend = todosProyectos
          .where((p) => p.isSynced == false)
          .length;
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
      final solicitudesSync = todasSolicitudes
          .where((s) => s.isSynced == true)
          .length;
      final solicitudesPend = todasSolicitudes
          .where((s) => s.isSynced == false)
          .length;
      sincronizados += solicitudesSync;
      pendientes += solicitudesPend;

      // Reportes
      final todosReportes = await isar.reportes
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      final reportesSync = todosReportes
          .where((r) => r.isSynced == true)
          .length;
      final reportesPend = todosReportes
          .where((r) => r.isSynced == false)
          .length;
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
                  InkWell(
                    onTap:
                        (_nivelUsuario == AppConstants.nivelInvitado ||
                            _pendientes == 0)
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const PendientesSyncPage(),
                            ),
                          ).then((_) => _cargarEstadisticas()),
                    borderRadius: BorderRadius.circular(20),
                    child: _buildContador(
                      icon: Icons.cloud_off,
                      cantidad: _pendientes,
                      color: AppColors.warning,
                      tooltip: _nivelUsuario == AppConstants.nivelInvitado
                          ? "Pendientes (solo consulta)"
                          : "Pendientes (toca para ver y subir)",
                    ),
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
          ModuleActionCard(
            title: "Habitantes",
            subtitle: "Ver lista completa y estatus de sincronización",
            icon: Icons.people_rounded,
            color: AppModulePastel.habitantes,
            colorAccent: AppModulePastel.habitantesAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HabitantesListPage()),
            ),
          ),

          // LISTADO DE EXTRANJEROS
          ModuleActionCard(
            title: "Listado de Extranjeros",
            subtitle: "Ver todos los extranjeros en la base de datos local",
            icon: Icons.list_alt_rounded,
            color: AppModulePastel.extranjeros,
            colorAccent: AppModulePastel.extranjerosAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExtranjerosListPage()),
            ),
          ),

          // COMUNAS
          ModuleActionCard(
            title: "Comunas",
            subtitle: "Ver lista de comunas registradas",
            icon: Icons.location_city_rounded,
            color: AppModulePastel.comunas,
            colorAccent: AppModulePastel.comunasAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComunasListPage()),
            ),
          ),

          // CONSEJOS COMUNALES
          ModuleActionCard(
            title: "Consejos Comunales",
            subtitle: "Ver y editar consejos comunales registrados",
            icon: Icons.groups_rounded,
            color: AppModulePastel.consejos,
            colorAccent: AppModulePastel.consejosAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ConsejosComunalesListPage(),
              ),
            ),
          ),

          // ORGANIZACIONES
          ModuleActionCard(
            title: "Organizaciones",
            subtitle: "Ver lista de organizaciones",
            icon: Icons.business_rounded,
            color: AppModulePastel.organizaciones,
            colorAccent: AppModulePastel.organizacionesAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrganizacionesListPage()),
            ),
          ),

          // CLAPS
          ModuleActionCard(
            title: "CLAPs",
            subtitle: "Ver lista de Comités Locales de Abastecimiento",
            icon: Icons.store_rounded,
            color: AppModulePastel.claps,
            colorAccent: AppModulePastel.clapsAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClapsListPage()),
            ),
          ),

          // SOLICITUDES
          ModuleActionCard(
            title: "Solicitudes",
            subtitle: "Ver y gestionar solicitudes de la comunidad",
            icon: Icons.assignment_rounded,
            color: AppModulePastel.listado,
            colorAccent: AppModulePastel.listadoAccent,
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
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
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
}
