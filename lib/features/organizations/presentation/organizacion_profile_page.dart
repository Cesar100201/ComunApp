import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';
import '../data/repositories/organizacion_repository.dart';

class OrganizacionProfilePage extends StatefulWidget {
  final Organizacion organizacion;

  const OrganizacionProfilePage({
    super.key,
    required this.organizacion,
  });

  @override
  State<OrganizacionProfilePage> createState() => _OrganizacionProfilePageState();
}

class _OrganizacionProfilePageState extends State<OrganizacionProfilePage> {
  Organizacion? _organizacionCompleto;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  
  late OrganizacionRepository _repo;
  
  final _formKey = GlobalKey<FormState>();
  final _nombreLargoController = TextEditingController();
  final _abreviacionController = TextEditingController();
  
  TipoOrganizacion _selectedTipo = TipoOrganizacion.Politico;
  bool _tieneAbreviacion = false;

  @override
  void initState() {
    super.initState();
    _inicializarRepositorio();
  }

  Future<void> _inicializarRepositorio() async {
    _repo = OrganizacionRepository();
    await _cargarDatosCompletos();
  }

  Future<void> _cargarDatosCompletos() async {
    final isar = await DbHelper().db;
    final organizacion = await isar.organizacions.get(widget.organizacion.id);
    
    if (organizacion != null) {
      setState(() {
        _organizacionCompleto = organizacion;
        _nombreLargoController.text = organizacion.nombreLargo;
        _abreviacionController.text = organizacion.abreviacion ?? '';
        _selectedTipo = organizacion.tipo;
        _tieneAbreviacion = organizacion.abreviacion != null && organizacion.abreviacion!.isNotEmpty;
        _isLoading = false;
      });
    } else {
      setState(() {
        _organizacionCompleto = widget.organizacion;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nombreLargoController.dispose();
    _abreviacionController.dispose();
    super.dispose();
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final isar = await DbHelper().db;
      final organizacionActualizada = await isar.organizacions.get(widget.organizacion.id);
      
      if (organizacionActualizada != null) {
        organizacionActualizada.nombreLargo = _nombreLargoController.text.trim();
        organizacionActualizada.abreviacion = _tieneAbreviacion && _abreviacionController.text.trim().isNotEmpty
            ? _abreviacionController.text.trim()
            : null;
        organizacionActualizada.tipo = _selectedTipo;
        
        await _repo.actualizarOrganizacion(organizacionActualizada);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ Organización actualizada con éxito"),
              backgroundColor: AppColors.success,
            ),
          );
          setState(() {
            _isEditing = false;
            _isSaving = false;
          });
          _cargarDatosCompletos();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al guardar: $e"),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _eliminarOrganizacion() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Eliminación"),
        content: const Text("¿Está seguro de que desea eliminar esta organización?"),
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
        await _repo.eliminarOrganizacion(widget.organizacion.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ Organización eliminada"),
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
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: "Editar",
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _isEditing = false);
                _cargarDatosCompletos();
              },
              tooltip: "Cancelar",
            ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _eliminarOrganizacion,
              tooltip: "Eliminar",
            ),
        ],
      ),
      body: _isEditing ? _buildEditView() : _buildProfileView(o),
    );
  }

  Widget _buildProfileView(Organizacion o) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(o),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: "Información General",
            icon: Icons.info,
            children: [
              _buildInfoRow("Nombre Completo", o.nombreLargo),
              if (o.abreviacion != null && o.abreviacion!.isNotEmpty)
                _buildInfoRow("Abreviación", o.abreviacion!),
              _buildInfoRow("Tipo", o.tipo.toString().split('.').last),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: "Estado",
            icon: Icons.cloud,
            children: [
              _buildInfoRow(
                "Sincronización",
                o.isSynced ? "Sincronizado" : "Pendiente",
                valueColor: o.isSynced ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditView() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nombreLargoController,
              decoration: const InputDecoration(
                labelText: "Nombre Completo *",
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? "Requerido" : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TipoOrganizacion>(
              value: _selectedTipo,
              decoration: const InputDecoration(
                labelText: "Tipo de Organización *",
                border: OutlineInputBorder(),
              ),
              items: TipoOrganizacion.values.map((tipo) {
                return DropdownMenuItem(
                  value: tipo,
                  child: Text(tipo.toString().split('.').last),
                );
              }).toList(),
              onChanged: (tipo) {
                setState(() => _selectedTipo = tipo!);
              },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text("Tiene abreviación"),
              value: _tieneAbreviacion,
              onChanged: (value) {
                setState(() => _tieneAbreviacion = value ?? false);
              },
            ),
            if (_tieneAbreviacion) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _abreviacionController,
                decoration: const InputDecoration(
                  labelText: "Abreviación",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _guardarCambios,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("GUARDAR CAMBIOS"),
              ),
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
            child: const Icon(
              Icons.business,
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
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
