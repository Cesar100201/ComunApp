import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/user_role_service.dart';
import '../../../../database/db_helper.dart';
import '../data/repositories/organizacion_repository.dart';
import 'edit_organizacion_info_general_page.dart';
import 'edit_organizacion_estructura_page.dart';
import 'edit_organizacion_vinculaciones_page.dart';

class OrganizacionProfilePage extends StatefulWidget {
  final Organizacion organizacion;

  const OrganizacionProfilePage({super.key, required this.organizacion});

  @override
  State<OrganizacionProfilePage> createState() =>
      _OrganizacionProfilePageState();
}

class _OrganizacionProfilePageState extends State<OrganizacionProfilePage> {
  Organizacion? _organizacionCompleto;
  bool _isLoading = true;
  OrganizacionRepository? _repo;
  bool _repoInicializado = false;
  bool _canDelete = false;
  final UserRoleService _roleService = UserRoleService();

  @override
  void initState() {
    super.initState();
    _inicializarRepositorio();
    _roleService.getNivelUsuario().then((n) {
      if (mounted) setState(() => _canDelete = _roleService.canDelete(n));
    });
  }

  Future<void> _inicializarRepositorio() async {
    setState(() {
      _repo = OrganizacionRepository();
      _repoInicializado = true;
    });
    _cargarDatosCompletos();
  }

  Future<void> _cargarDatosCompletos() async {
    if (!_repoInicializado || _repo == null) {
      await _inicializarRepositorio();
      return;
    }
    final isar = await DbHelper().db;
    final organizacion = await isar.organizacions.get(widget.organizacion.id);

    if (organizacion != null) {
      setState(() {
        _organizacionCompleto = organizacion;
        _isLoading = false;
      });
    } else {
      setState(() {
        _organizacionCompleto = widget.organizacion;
        _isLoading = false;
      });
    }
  }

  Future<void> _eliminarOrganizacion() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Eliminación"),
        content: const Text(
          "¿Está seguro de que desea eliminar esta organización?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirmacion == true) {
      try {
        if (!_repoInicializado || _repo == null) {
          await _inicializarRepositorio();
        }
        await _repo!.eliminarOrganizacion(widget.organizacion.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Organización eliminada"),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error al eliminar: $e"),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Perfil de la Organización")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final o = _organizacionCompleto ?? widget.organizacion;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Perfil de la Organización"),
        actions: [
          if (_canDelete)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _eliminarOrganizacion,
              tooltip: "Eliminar",
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(o),
            const SizedBox(height: 24),

            // Información General
            _buildSection(
              context,
              title: "Información General",
              icon: Icons.info,
              onEdit: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EditOrganizacionInfoGeneralPage(organizacion: o),
                  ),
                );
                if (result == true) {
                  _cargarDatosCompletos();
                }
              },
              children: [
                _buildInfoRow("Nombre Completo", o.nombreLargo),
                if (o.abreviacion != null && o.abreviacion!.isNotEmpty)
                  _buildInfoRow("Abreviación", o.abreviacion!),
                _buildInfoRow("Tipo", o.tipo.toString().split('.').last),
              ],
            ),
            const SizedBox(height: 16),

            // Estructura Organizativa (solo cargos)
            _buildSection(
              context,
              title: "Estructura Organizativa",
              icon: Icons.business,
              onEdit: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EditOrganizacionEstructuraPage(organizacion: o),
                  ),
                );
                if (result == true) {
                  _cargarDatosCompletos();
                }
              },
              children: [
                if (o.cargos.isEmpty)
                  _buildInfoRow(
                    "Cargos",
                    "Sin cargos definidos",
                    valueColor: AppColors.textSecondary,
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Cargos (${o.cargos.length}):",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...o.cargos.map((cargo) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                cargo.esUnico ? Icons.person : Icons.groups,
                                size: 18,
                                color: cargo.esUnico
                                    ? AppColors.warning
                                    : AppColors.info,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  cargo.nombreCargo,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (cargo.esUnico
                                              ? AppColors.warning
                                              : AppColors.info)
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  cargo.esUnico ? "Único" : "Múltiple",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cargo.esUnico
                                        ? AppColors.warning
                                        : AppColors.info,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Vinculaciones (categoría separada)
            _buildSection(
              context,
              title: "Vinculaciones",
              icon: Icons.people,
              onEdit: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EditOrganizacionVinculacionesPage(organizacion: o),
                  ),
                );
                if (result == true) {
                  _cargarDatosCompletos();
                }
              },
              children: [
                _buildInfoRow(
                  "Gestión",
                  "Vincular personas a cargos",
                  valueColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Estado de Sincronización
            _buildSection(
              context,
              title: "Estado",
              icon: Icons.cloud,
              children: [
                _buildInfoRow(
                  "Sincronización",
                  o.isSynced ? "Sincronizado" : "Pendiente",
                  valueColor: o.isSynced
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Organizacion o) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.shadowMedium,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            child: const Icon(Icons.business, size: 40, color: Colors.white),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.nombreLargo,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (o.abreviacion != null && o.abreviacion!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    o.abreviacion!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
    VoidCallback? onEdit,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryUltraLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    onPressed: onEdit,
                    tooltip: "Editar",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
