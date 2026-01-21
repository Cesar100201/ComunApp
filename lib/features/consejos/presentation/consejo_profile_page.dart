import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';
import '../data/repositories/consejo_repository.dart';
import '../../comunas/data/repositories/comuna_repository.dart';
import 'map_location_picker_page.dart';

class ConsejoProfilePage extends StatefulWidget {
  final ConsejoComunal consejo;

  const ConsejoProfilePage({
    super.key,
    required this.consejo,
  });

  @override
  State<ConsejoProfilePage> createState() => _ConsejoProfilePageState();
}

class _ConsejoProfilePageState extends State<ConsejoProfilePage> {
  ConsejoComunal? _consejoCompleto;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  
  late ConsejoRepository _repo;
  late ComunaRepository _comunaRepo;
  List<Comuna> _comunas = [];
  
  final _formKey = GlobalKey<FormState>();
  final _codigoSiturController = TextEditingController();
  final _rifController = TextEditingController();
  final _nombreConsejoController = TextEditingController();
  final _comunidadController = TextEditingController();
  
  Comuna? _selectedComuna;
  final List<String> _comunidades = [];
  TipoZona _selectedTipoZona = TipoZona.Urbano;
  double? _latitud;
  double? _longitud;

  @override
  void initState() {
    super.initState();
    _inicializarRepositorios();
  }

  Future<void> _inicializarRepositorios() async {
    final isar = await DbHelper().db;
    _repo = ConsejoRepository(isar);
    _comunaRepo = ComunaRepository(isar);
    await _cargarDatosCompletos();
    await _cargarComunas();
  }

  Future<void> _cargarDatosCompletos() async {
    final isar = await DbHelper().db;
    final consejo = await isar.consejoComunals.get(widget.consejo.id);
    
    if (consejo != null) {
      await consejo.comuna.load();
      
      setState(() {
        _consejoCompleto = consejo;
        _codigoSiturController.text = consejo.codigoSitur;
        _rifController.text = consejo.rif ?? '';
        _nombreConsejoController.text = consejo.nombreConsejo;
        _comunidades.addAll(consejo.comunidades);
        _selectedTipoZona = consejo.tipoZona;
        _latitud = consejo.latitud;
        _longitud = consejo.longitud;
        _selectedComuna = consejo.comuna.value;
        _isLoading = false;
      });
    } else {
      setState(() {
        _consejoCompleto = widget.consejo;
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarComunas() async {
    final comunas = await _comunaRepo.getAllComunas();
    setState(() {
      _comunas = comunas;
      if (_selectedComuna != null) {
        Comuna? seleccionada;
        for (final comuna in _comunas) {
          if (comuna.id == _selectedComuna!.id) {
            seleccionada = comuna;
            break;
          }
        }
        _selectedComuna = seleccionada;
      }
    });
  }

  @override
  void dispose() {
    _codigoSiturController.dispose();
    _rifController.dispose();
    _nombreConsejoController.dispose();
    _comunidadController.dispose();
    super.dispose();
  }

  void _agregarComunidad() {
    final comunidad = _comunidadController.text.trim();
    if (comunidad.isNotEmpty && !_comunidades.contains(comunidad)) {
      setState(() {
        _comunidades.add(comunidad);
        _comunidadController.clear();
      });
    }
  }

  void _eliminarComunidad(int index) {
    setState(() {
      _comunidades.removeAt(index);
    });
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedComuna == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Por favor seleccione una Comuna"),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final isar = await DbHelper().db;
      final consejoActualizado = await isar.consejoComunals.get(widget.consejo.id);
      
      if (consejoActualizado != null) {
        consejoActualizado.codigoSitur = _codigoSiturController.text.trim();
        consejoActualizado.rif = _rifController.text.trim().isEmpty ? null : _rifController.text.trim();
        consejoActualizado.nombreConsejo = _nombreConsejoController.text.trim();
        consejoActualizado.tipoZona = _selectedTipoZona;
        consejoActualizado.latitud = _latitud ?? 0.0;
        consejoActualizado.longitud = _longitud ?? 0.0;
        consejoActualizado.comunidades = _comunidades;
        consejoActualizado.comuna.value = _selectedComuna;
        
        await _repo.actualizarConsejo(consejoActualizado);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ Consejo Comunal actualizado con éxito"),
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

  Future<void> _eliminarConsejo() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Eliminación"),
        content: const Text("¿Está seguro de que desea eliminar este consejo comunal?"),
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
        final isar = await DbHelper().db;
        final consejo = await isar.consejoComunals.get(widget.consejo.id);
        
        if (consejo != null) {
          await _repo.eliminarConsejo(consejo.id);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("✅ Consejo Comunal eliminado"),
                backgroundColor: AppColors.success,
              ),
            );
            Navigator.pop(context, true);
          }
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
              onPressed: _eliminarConsejo,
              tooltip: "Eliminar",
            ),
        ],
      ),
      body: _isEditing ? _buildEditView() : _buildProfileView(c),
    );
  }

  Widget _buildProfileView(ConsejoComunal c) {
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
              _buildInfoRow("Nombre del Consejo", c.nombreConsejo),
              _buildInfoRow("Código SITUR", c.codigoSitur),
              if (c.rif != null && c.rif!.isNotEmpty)
                _buildInfoRow("RIF", c.rif!),
              _buildInfoRow("Tipo de Zona", c.tipoZona.toString().split('.').last),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: "Ubicación",
            icon: Icons.location_on,
            children: [
              if (c.comuna.value != null)
                _buildInfoRow("Comuna", c.comuna.value!.nombreComuna),
              _buildInfoRow("Latitud", c.latitud.toStringAsFixed(6)),
              _buildInfoRow("Longitud", c.longitud.toStringAsFixed(6)),
            ],
          ),
          const SizedBox(height: 16),
          if (c.comunidades.isNotEmpty)
            _buildSection(
              context,
              title: "Comunidades",
              icon: Icons.home_work,
              children: [
                for (var comunidad in c.comunidades)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            comunidad,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
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
              controller: _nombreConsejoController,
              decoration: const InputDecoration(
                labelText: "Nombre del Consejo *",
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? "Requerido" : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Comuna>(
              value: _selectedComuna,
              decoration: const InputDecoration(
                labelText: "Comuna *",
                border: OutlineInputBorder(),
              ),
              items: _comunas.map((comuna) {
                return DropdownMenuItem(
                  value: comuna,
                  child: Text(comuna.nombreComuna),
                );
              }).toList(),
              onChanged: (comuna) {
                setState(() => _selectedComuna = comuna);
              },
              validator: (value) => value == null ? "Requerido" : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TipoZona>(
              value: _selectedTipoZona,
              decoration: const InputDecoration(
                labelText: "Tipo de Zona *",
                border: OutlineInputBorder(),
              ),
              items: TipoZona.values.map((zona) {
                return DropdownMenuItem(
                  value: zona,
                  child: Text(zona.toString().split('.').last),
                );
              }).toList(),
              onChanged: (zona) {
                if (zona == null) return;
                setState(() => _selectedTipoZona = zona);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _comunidadController,
                    decoration: const InputDecoration(
                      labelText: "Agregar Comunidad",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _agregarComunidad,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (_comunidades.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_comunidades.length, (index) {
                  return Chip(
                    label: Text(_comunidades[index]),
                    onDeleted: () => _eliminarComunidad(index),
                  );
                }),
              ),
            ],
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
                            initialLatitude: _latitud ?? 8.2167,
                            initialLongitude: _longitud ?? -72.2489,
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
