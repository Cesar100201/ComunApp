import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';
import '../data/repositories/consejo_repository.dart';
import '../../comunas/data/repositories/comuna_repository.dart';
import 'map_location_picker_page.dart';

class EditConsejoUbicacionPage extends StatefulWidget {
  final ConsejoComunal consejo;

  const EditConsejoUbicacionPage({
    super.key,
    required this.consejo,
  });

  @override
  State<EditConsejoUbicacionPage> createState() => _EditConsejoUbicacionPageState();
}

class _EditConsejoUbicacionPageState extends State<EditConsejoUbicacionPage> {
  final _formKey = GlobalKey<FormState>();
  late ConsejoRepository _repo;
  late ComunaRepository _comunaRepo;

  late final TextEditingController _comunidadController;
  Comuna? _selectedComuna;
  List<String> _comunidades = [];
  List<Comuna> _comunas = [];
  double? _latitud;
  double? _longitud;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _comunidadController = TextEditingController();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final isar = await DbHelper().db;
    _repo = ConsejoRepository(isar);
    _comunaRepo = ComunaRepository(isar);
    
    // Cargar la comuna del consejo
    await widget.consejo.comuna.load();
    
    // Cargar lista de comunas
    final comunas = await _comunaRepo.getAllComunas();
    
    if (mounted) {
      setState(() {
        _comunas = comunas;
        // Buscar la comuna seleccionada en la lista por ID para evitar problemas de referencia
        if (widget.consejo.comuna.value != null) {
          _selectedComuna = _comunas.firstWhere(
            (c) => c.id == widget.consejo.comuna.value!.id,
            orElse: () => widget.consejo.comuna.value!,
          );
        }
        _comunidades = List<String>.from(widget.consejo.comunidades);
        _latitud = widget.consejo.latitud;
        _longitud = widget.consejo.longitud;
      });
    }
  }

  @override
  void dispose() {
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

  Future<void> _guardar() async {
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
      final consejo = await isar.consejoComunals.get(widget.consejo.id);

      if (consejo != null) {
        consejo.comuna.value = _selectedComuna;
        consejo.comunidades = _comunidades;
        consejo.latitud = _latitud ?? 0.0;
        consejo.longitud = _longitud ?? 0.0;

        await _repo.actualizarConsejo(consejo);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ Ubicación actualizada"),
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
            content: Text("Error al guardar: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Ubicación"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<Comuna>(
                value: _selectedComuna,
                decoration: const InputDecoration(
                  labelText: "Comuna *",
                  prefixIcon: Icon(Icons.location_city),
                ),
                items: [
                  const DropdownMenuItem<Comuna>(
                    value: null,
                    child: Text("Seleccione..."),
                  ),
                  ..._comunas.map((comuna) {
                    return DropdownMenuItem(
                      value: comuna,
                      child: Text(comuna.nombreComuna),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() => _selectedComuna = value);
                },
              ),
              const SizedBox(height: 16),

              // Selección de ubicación en mapa
              Text(
                "Ubicación en el Mapa",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Card(
                child: InkWell(
                  onTap: () async {
                    final result = await Navigator.push<Map<String, double>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapLocationPickerPage(
                          initialLatitude: _latitud,
                          initialLongitude: _longitud,
                        ),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        _latitud = result['latitude'];
                        _longitud = result['longitude'];
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryUltraLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.map,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Seleccionar ubicación en el mapa",
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              if (_latitud != null && _longitud != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "Lat: ${_latitud!.toStringAsFixed(6)}, Lng: ${_longitud!.toStringAsFixed(6)}",
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ] else
                                Text(
                                  "Toca para seleccionar",
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textTertiary,
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
              ),
              const SizedBox(height: 24),

              Text(
                "Comunidades",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _comunidadController,
                      decoration: const InputDecoration(
                        labelText: "Nombre de Comunidad",
                        prefixIcon: Icon(Icons.home_work),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _agregarComunidad,
                    icon: const Icon(Icons.add),
                    label: const Text("Agregar"),
                  ),
                ],
              ),
              if (_comunidades.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _comunidades.asMap().entries.map((entry) {
                    return Chip(
                      label: Text(entry.value),
                      onDeleted: () => _eliminarComunidad(entry.key),
                      deleteIcon: const Icon(Icons.close, size: 18),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _guardar,
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
      ),
    );
  }
}
