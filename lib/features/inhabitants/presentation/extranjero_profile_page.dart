import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/repositories/extranjero_repository.dart';
import '../../../../database/db_helper.dart';

class ExtranjeroProfilePage extends StatefulWidget {
  final Extranjero extranjero;

  const ExtranjeroProfilePage({
    super.key,
    required this.extranjero,
  });

  @override
  State<ExtranjeroProfilePage> createState() => _ExtranjeroProfilePageState();
}

class _ExtranjeroProfilePageState extends State<ExtranjeroProfilePage> {
  ExtranjeroRepository? _repo;
  bool _repoInicializado = false;

  @override
  void initState() {
    super.initState();
    _inicializarRepositorio();
  }

  Future<void> _inicializarRepositorio() async {
    final isar = await DbHelper().db;
    setState(() {
      _repo = ExtranjeroRepository(isar);
      _repoInicializado = true;
    });
  }

  Future<void> _eliminarExtranjero() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar eliminación"),
        content: const Text(
          "¿Está seguro de que desea eliminar este registro de extranjero?",
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
        if (!_repoInicializado || _repo == null) await _inicializarRepositorio();
        await _repo!.eliminarExtranjero(widget.extranjero.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Extranjero eliminado"),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? "—" : value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                  ),
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
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.extranjero;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Perfil del Extranjero"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _eliminarExtranjero,
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryUltraLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: Text(
                      e.nombreCompleto.isNotEmpty ? e.nombreCompleto.substring(0, 1).toUpperCase() : "?",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.nombreCompleto,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "C.C ${e.cedulaColombiana} • ${e.departamento}, ${e.municipio}",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Datos personales
            _buildSection(
              context,
              title: "Datos personales",
              icon: Icons.person,
              children: [
                _buildInfoRow("Nombre completo", e.nombreCompleto),
                _buildInfoRow("Cédula colombiana", e.cedulaColombiana.toString()),
                _buildInfoRow("Teléfono", e.telefono),
                _buildInfoRow("¿Nacionalizado?", e.esNacionalizado ? "Sí" : "No"),
                if (e.esNacionalizado && e.cedulaVenezolana != null)
                  _buildInfoRow("Cédula venezolana", e.cedulaVenezolana.toString()),
                if (e.direccion != null && e.direccion!.isNotEmpty)
                  _buildInfoRow("Dirección", e.direccion!),
                if (e.email != null && e.email!.isNotEmpty)
                  _buildInfoRow("Correo electrónico", e.email!),
              ],
            ),
            const SizedBox(height: 16),

            // Ubicación
            _buildSection(
              context,
              title: "Ubicación en Colombia",
              icon: Icons.location_on,
              children: [
                _buildInfoRow("Departamento", e.departamento),
                _buildInfoRow("Municipio", e.municipio),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
