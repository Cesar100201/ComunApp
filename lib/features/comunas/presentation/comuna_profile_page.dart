import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';
import '../data/repositories/comuna_repository.dart';
import '../../consejos/presentation/map_location_picker_page.dart';

class ComunaProfilePage extends StatefulWidget {
  final Comuna comuna;

  const ComunaProfilePage({
    super.key,
    required this.comuna,
  });

  @override
  State<ComunaProfilePage> createState() => _ComunaProfilePageState();
}

class _ComunaProfilePageState extends State<ComunaProfilePage> {
  Comuna? _comunaCompleto;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  
  late ComunaRepository _repo;
  
  final _formKey = GlobalKey<FormState>();
  final _codigoSiturController = TextEditingController();
  final _rifController = TextEditingController();
  final _codigoComElectoralController = TextEditingController();
  final _nombreComunaController = TextEditingController();
  final _municipioController = TextEditingController();
  
  Parroquia _selectedParroquia = Parroquia.LaFria;
  double? _latitud;
  double? _longitud;

  @override
  void initState() {
    super.initState();
    _inicializarRepositorio();
  }

  Future<void> _inicializarRepositorio() async {
    final isar = await DbHelper().db;
    _repo = ComunaRepository(isar);
    await _cargarDatosCompletos();
  }

  Future<void> _cargarDatosCompletos() async {
    final isar = await DbHelper().db;
    final comuna = await isar.comunas.get(widget.comuna.id);
    
    if (comuna != null) {
      setState(() {
        _comunaCompleto = comuna;
        _codigoSiturController.text = comuna.codigoSitur;
        _rifController.text = comuna.rif ?? '';
        _codigoComElectoralController.text = comuna.codigoComElectoral;
        _nombreComunaController.text = comuna.nombreComuna;
        _municipioController.text = comuna.municipio;
        _selectedParroquia = comuna.parroquia;
        _latitud = comuna.latitud;
        _longitud = comuna.longitud;
        _isLoading = false;
      });
    } else {
      setState(() {
        _comunaCompleto = widget.comuna;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _codigoSiturController.dispose();
    _rifController.dispose();
    _codigoComElectoralController.dispose();
    _nombreComunaController.dispose();
    _municipioController.dispose();
    super.dispose();
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitud == null || _longitud == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Por favor seleccione una ubicación en el mapa"),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final isar = await DbHelper().db;
      final comunaActualizada = await isar.comunas.get(widget.comuna.id);
      
      if (comunaActualizada != null) {
        comunaActualizada.codigoSitur = _codigoSiturController.text.trim();
        comunaActualizada.rif = _rifController.text.trim().isEmpty ? null : _rifController.text.trim();
        comunaActualizada.codigoComElectoral = _codigoComElectoralController.text.trim();
        comunaActualizada.nombreComuna = _nombreComunaController.text.trim();
        comunaActualizada.municipio = _municipioController.text.trim().isEmpty
            ? "García de Hevia"
            : _municipioController.text.trim();
        comunaActualizada.parroquia = _selectedParroquia;
        comunaActualizada.latitud = _latitud ?? 0.0;
        comunaActualizada.longitud = _longitud ?? 0.0;
        
        await _repo.actualizarComuna(comunaActualizada);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ Comuna actualizada con éxito"),
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

  Future<void> _eliminarComuna() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Eliminación"),
        content: const Text("¿Está seguro de que desea eliminar esta comuna?"),
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
        await _repo.eliminarComuna(widget.comuna.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ Comuna eliminada"),
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
        appBar: AppBar(title: const Text("Perfil de la Comuna")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final c = _comunaCompleto ?? widget.comuna;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Perfil de la Comuna"),
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
              onPressed: _eliminarComuna,
              tooltip: "Eliminar",
            ),
        ],
      ),
      body: _isEditing ? _buildEditView() : _buildProfileView(c),
    );
  }

  Widget _buildProfileView(Comuna c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(c),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: "Información General",
            icon: Icons.info,
            children: [
              _buildInfoRow("Nombre de la Comuna", c.nombreComuna),
              _buildInfoRow("Código SITUR", c.codigoSitur),
              if (c.rif != null && c.rif!.isNotEmpty)
                _buildInfoRow("RIF", c.rif!),
              _buildInfoRow("Código Comunal Electoral", c.codigoComElectoral),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: "Ubicación",
            icon: Icons.location_on,
            children: [
              _buildInfoRow("Municipio", c.municipio),
              _buildInfoRow("Parroquia", c.parroquia.toString().split('.').last),
              _buildInfoRow("Latitud", c.latitud.toStringAsFixed(6)),
              _buildInfoRow("Longitud", c.longitud.toStringAsFixed(6)),
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
                c.isSynced ? "Sincronizado" : "Pendiente",
                valueColor: c.isSynced ? AppColors.success : AppColors.warning,
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
              controller: _codigoSiturController,
              decoration: const InputDecoration(
                labelText: "Código SITUR *",
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? "Requerido" : null,
              enabled: false, // No se puede cambiar el código SITUR
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rifController,
              decoration: const InputDecoration(
                labelText: "RIF",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codigoComElectoralController,
              decoration: const InputDecoration(
                labelText: "Código Comunal Electoral *",
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? "Requerido" : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombreComunaController,
              decoration: const InputDecoration(
                labelText: "Nombre de la Comuna *",
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? "Requerido" : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _municipioController,
              decoration: const InputDecoration(
                labelText: "Municipio",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Parroquia>(
              value: _selectedParroquia,
              decoration: const InputDecoration(
                labelText: "Parroquia *",
                border: OutlineInputBorder(),
              ),
              items: Parroquia.values.map((parroquia) {
                return DropdownMenuItem(
                  value: parroquia,
                  child: Text(parroquia.toString().split('.').last),
                );
              }).toList(),
              onChanged: (parroquia) {
                setState(() => _selectedParroquia = parroquia!);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.map),
                    label: const Text("Seleccionar Ubicación"),
                    onPressed: () async {
                      final location = await Navigator.push<Map<String, double>>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapLocationPickerPage(
                            initialLatitude: _latitud,
                            initialLongitude: _longitud,
                          ),
                        ),
                      );
                      if (location != null) {
                        setState(() {
                          _latitud = location['latitude'];
                          _longitud = location['longitude'];
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_latitud != null && _longitud != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Ubicación: ${_latitud!.toStringAsFixed(6)}, ${_longitud!.toStringAsFixed(6)}",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
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

  Widget _buildHeader(Comuna c) {
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
              Icons.location_city,
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
                  c.nombreComuna,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Código: ${c.codigoSitur}",
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
