import 'package:flutter/material.dart';
import 'package:goblafria/core/theme/app_theme.dart';
import 'package:goblafria/core/services/user_role_service.dart';
import 'package:goblafria/database/db_helper.dart';
import 'package:goblafria/features/inhabitants/data/repositories/habitante_repository.dart';
import '../data/control_seguimiento_model.dart';
import '../data/repositories/control_seguimiento_repository.dart';
import 'package:intl/intl.dart';
import 'control_seguimiento_form_page.dart';
import 'control_seguimiento_informe_pdf_page.dart';
import 'control_seguimiento_report_page.dart';

/// Lista de registros de Control y Seguimiento guardados en la base local.
class ControlSeguimientoListPage extends StatefulWidget {
  const ControlSeguimientoListPage({super.key});

  @override
  State<ControlSeguimientoListPage> createState() => _ControlSeguimientoListPageState();
}

class _ControlSeguimientoListPageState extends State<ControlSeguimientoListPage> {
  final ControlSeguimientoRepository _repo = ControlSeguimientoRepository();
  List<ControlSeguimiento> _registros = [];
  final Map<int, String> _nombresCreadores = {}; // cedula -> nombreCompleto
  bool _loading = true;
  bool _canDelete = false;
  final UserRoleService _roleService = UserRoleService();

  @override
  void initState() {
    super.initState();
    _loadRegistros();
    _roleService.getNivelUsuario().then((n) {
      if (mounted) setState(() => _canDelete = _roleService.canDelete(n));
    });
  }

  Future<void> _loadRegistros() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = await _repo.getAll();
      _nombresCreadores.clear();
      final isar = await DbHelper().db;
      final habitanteRepo = HabitanteRepository(isar);
      for (final r in list) {
        if (r.cedulaCreador != null) {
          final h = await habitanteRepo.getHabitanteByCedula(r.cedulaCreador!);
          if (h != null && !h.isDeleted) {
            _nombresCreadores[r.cedulaCreador!] = h.nombreCompleto;
          }
        }
      }
      if (mounted) {
        setState(() {
          _registros = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar registros: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _nuevoRegistro() async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ControlSeguimientoFormPage(),
      ),
    );
    if (guardado == true) {
        _loadRegistros();
      }
  }

  Future<void> _confirmarEliminar(ControlSeguimiento r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar registro"),
        content: Text(
          "¿Eliminar registro del ${DateFormat('dd/MM/yyyy').format(r.fecha)} - ${r.categoria}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _repo.delete(r.id);
    _loadRegistros();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Control y Seguimiento"),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Generar informe PDF",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ControlSeguimientoInformePdfPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _registros.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        "No hay registros",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Pulse el botón + para agregar uno",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRegistros,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _registros.length,
                    itemBuilder: (context, index) {
                      final r = _registros[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ControlSeguimientoReportPage(
                                  registro: r,
                                  nombreCreador: _nombresCreadores[r.cedulaCreador],
                                ),
                              ),
                            ).then((_) => _loadRegistros());
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          title: Text(
                            r.categoria,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd/MM/yyyy').format(r.fecha),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (r.nombreActividad.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    r.nombreActividad,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (r.objetivo.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    r.objetivo,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              Text(
                                "Estatus: ${r.estatus}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (r.transformacion7T.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    "Plan de la Patria 2025 - 2030: ${r.transformacion7T}",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              if (r.semanaInicio != null && r.semanaFin != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    "Semana: ${DateFormat('dd/MM').format(r.semanaInicio!)} - ${DateFormat('dd/MM/yyyy').format(r.semanaFin!)}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Text(
                                "Registrado por: ${r.cedulaCreador != null ? (_nombresCreadores[r.cedulaCreador] ?? "Cédula ${r.cedulaCreador}") : "Sin vincular"}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.outline,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: _canDelete
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: AppColors.error,
                                  onPressed: () => _confirmarEliminar(r),
                                )
                              : null,
                        ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _nuevoRegistro,
        child: const Icon(Icons.add),
      ),
    );
  }
}
