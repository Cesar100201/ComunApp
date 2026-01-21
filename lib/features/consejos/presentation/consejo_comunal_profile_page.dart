import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';
import '../data/repositories/consejo_repository.dart';
import 'edit_consejo_info_basica_page.dart';
import 'edit_consejo_ubicacion_page.dart';
import 'edit_consejo_organizacion_page.dart';
import 'edit_consejo_vinculaciones_page.dart';

class ConsejoComunalProfilePage extends StatefulWidget {
  final ConsejoComunal consejo;

  const ConsejoComunalProfilePage({
    super.key,
    required this.consejo,
  });

  @override
  State<ConsejoComunalProfilePage> createState() => _ConsejoComunalProfilePageState();
}

class _ConsejoComunalProfilePageState extends State<ConsejoComunalProfilePage> {
  ConsejoComunal? _consejoCompleto;
  bool _isLoading = true;
  ConsejoRepository? _repo;
  bool _repoInicializado = false;

  @override
  void initState() {
    super.initState();
    _inicializarRepositorio();
  }

  Future<void> _inicializarRepositorio() async {
    final isar = await DbHelper().db;
    setState(() {
      _repo = ConsejoRepository(isar);
      _repoInicializado = true;
    });
    _cargarDatosCompletos();
  }

  Future<void> _cargarDatosCompletos() async {
    if (!_repoInicializado || _repo == null) {
      await _inicializarRepositorio();
    }
    final isar = await DbHelper().db;
    final consejo = await isar.consejoComunals.get(widget.consejo.id);
    
    if (consejo != null) {
      // Cargar relaciones
      await consejo.comuna.load();
      
      setState(() {
        _consejoCompleto = consejo;
        _isLoading = false;
      });
    } else {
      setState(() {
        _consejoCompleto = widget.consejo;
        _isLoading = false;
      });
    }
  }

  Future<void> _eliminarConsejo() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Eliminación"),
        content: const Text("¿Está seguro de que desea eliminar este Consejo Comunal?"),
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
        await _repo!.eliminarConsejo(widget.consejo.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ Consejo Comunal eliminado"),
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
        appBar: AppBar(title: const Text("Perfil del Consejo Comunal")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final c = _consejoCompleto ?? widget.consejo;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Perfil del Consejo Comunal"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _eliminarConsejo,
            tooltip: "Eliminar",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con foto/avatar
            _buildHeader(c),
            const SizedBox(height: 24),

            // Información Básica
            _buildSection(
              context,
              title: "Información Básica",
              icon: Icons.info,
              onEdit: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditConsejoInfoBasicaPage(consejo: c),
                  ),
                );
                if (result == true) {
                  _cargarDatosCompletos();
                }
              },
              children: [
                _buildInfoRow("Código SITUR", c.codigoSitur),
                if (c.rif != null && c.rif!.isNotEmpty)
                  _buildInfoRow("RIF", c.rif!),
                _buildInfoRow("Nombre del Consejo", c.nombreConsejo),
                _buildInfoRow(
                  "Tipo de Zona",
                  c.tipoZona.toString().split('.').last,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Ubicación
            _buildSection(
              context,
              title: "Ubicación",
              icon: Icons.location_on,
              onEdit: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditConsejoUbicacionPage(consejo: c),
                  ),
                );
                if (result == true) {
                  _cargarDatosCompletos();
                }
              },
              children: [
                if (c.comuna.value != null)
                  _buildInfoRow("Comuna", c.comuna.value!.nombreComuna),
                _buildInfoRow(
                  "Coordenadas",
                  "Lat: ${c.latitud.toStringAsFixed(6)}, Lng: ${c.longitud.toStringAsFixed(6)}",
                ),
                if (c.comunidades.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Comunidades:",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: c.comunidades.map((comunidad) {
                      return Chip(
                        label: Text(comunidad),
                        backgroundColor: AppColors.primaryUltraLight,
                      );
                    }).toList(),
                  ),
                ],
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
                    builder: (context) => EditConsejoOrganizacionPage(consejo: c),
                  ),
                );
                if (result == true) {
                  _cargarDatosCompletos();
                }
              },
              children: [
                if (c.cargos.isEmpty)
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
                        "Cargos (${c.cargos.length}):",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 12),
                      ...c.cargos.map((cargo) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                cargo.esUnico ? Icons.person : Icons.groups,
                                size: 18,
                                color: cargo.esUnico ? AppColors.warning : AppColors.info,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  cargo.nombreCargo,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (cargo.esUnico ? AppColors.warning : AppColors.info).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  cargo.esUnico ? "Único" : "Múltiple",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cargo.esUnico ? AppColors.warning : AppColors.info,
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
                    builder: (context) => EditConsejoVinculacionesPage(consejo: c),
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
                  c.isSynced ? "Sincronizado" : "Pendiente",
                  valueColor: c.isSynced ? AppColors.success : AppColors.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ConsejoComunal c) {
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
            child: const Icon(
              Icons.groups,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.nombreConsejo,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Código SITUR: ${c.codigoSitur}",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
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
                    icon: Icon(Icons.edit, color: AppColors.primary, size: 20),
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
