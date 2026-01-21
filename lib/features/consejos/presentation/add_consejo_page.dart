import 'package:flutter/material.dart';
import '../../../../database/db_helper.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/repositories/consejo_repository.dart';
import '../../comunas/data/repositories/comuna_repository.dart';
import 'map_location_picker_page.dart';

class AddConsejoPage extends StatefulWidget {
  const AddConsejoPage({super.key});

  @override
  State<AddConsejoPage> createState() => _AddConsejoPageState();
}

class _AddConsejoPageState extends State<AddConsejoPage> {
  final _formKey = GlobalKey<FormState>();
  late final ConsejoRepository _repo;
  late final ComunaRepository _comunaRepo;

  final _codigoSiturController = TextEditingController();
  final _rifController = TextEditingController();
  final _nombreConsejoController = TextEditingController();
  final _comunidadController = TextEditingController();

  Comuna? _selectedComuna;
  final List<String> _comunidades = [];
  TipoZona _selectedTipoZona = TipoZona.Urbano;
  bool _isSaving = false;
  List<Comuna> _comunas = [];
  double? _latitud;
  double? _longitud;

  @override
  void initState() {
    super.initState();
    _initializeRepositoriesAndLoadData();
  }

  Future<void> _initializeRepositoriesAndLoadData() async {
    final isar = await DbHelper().db;
    _repo = ConsejoRepository(isar);
    _comunaRepo = ComunaRepository(isar);
    await _cargarComunas();
  }

  Future<void> _cargarComunas() async {
    final comunas = await _comunaRepo.getAllComunas();
    setState(() {
      _comunas = comunas;
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
      final consejo = ConsejoComunal()
        ..codigoSitur = _codigoSiturController.text.trim()
        ..rif = _rifController.text.trim().isEmpty ? null : _rifController.text.trim()
        ..nombreConsejo = _nombreConsejoController.text.trim()
        ..tipoZona = _selectedTipoZona
        ..latitud = _latitud ?? 0.0
        ..longitud = _longitud ?? 0.0
        ..comunidades = _comunidades
        ..isSynced = false;

      consejo.comuna.value = _selectedComuna;

      await _repo.guardarConsejo(consejo);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("✅ Consejo Comunal registrado con éxito"),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
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
      appBar: AppBar(title: const Text("Nuevo Consejo Comunal")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Datos del Consejo Comunal",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 24),
              _buildInput("Código SITUR", Icons.qr_code, _codigoSiturController),
              const SizedBox(height: 16),
              _buildInputWithOptional("RIF", Icons.badge, _rifController),
              const SizedBox(height: 16),
              _buildInput("Nombre del Consejo", Icons.group, _nombreConsejoController),
              const SizedBox(height: 16),
              _buildDropdown<Comuna?>(
                "Comuna",
                Icons.location_city,
                [null, ..._comunas],
                _selectedComuna,
                (Comuna? newValue) {
                  setState(() {
                    _selectedComuna = newValue;
                  });
                },
                itemToString: (Comuna? value) => value?.nombreComuna ?? "Seleccione...",
              ),
              const SizedBox(height: 16),
              _buildDropdown<TipoZona>(
                "Tipo de Zona",
                Icons.terrain,
                TipoZona.values,
                _selectedTipoZona,
                (TipoZona? newValue) {
                  if (newValue == null) return;
                  setState(() {
                    _selectedTipoZona = newValue;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Selección de ubicación en mapa
              Text(
                "Ubicación",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
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
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInput("Nombre de Comunidad", Icons.home_work, _comunidadController, required: false),
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
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("GUARDAR CONSEJO COMUNAL"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(
    String label,
    IconData icon,
    TextEditingController controller, {
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: icon == Icons.location_on ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: required
          ? (value) => value == null || value.isEmpty ? "Campo requerido" : null
          : null,
    );
  }

  Widget _buildInputWithOptional(
    String label,
    IconData icon,
    TextEditingController controller,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.text,
      decoration: InputDecoration(
        label: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: label,
                style: Theme.of(context).inputDecorationTheme.labelStyle,
              ),
              TextSpan(
                text: ' (opcional)',
                style: Theme.of(context).inputDecorationTheme.labelStyle?.copyWith(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.normal,
                    ),
              ),
            ],
          ),
        ),
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _buildDropdown<T>(
    String label,
    IconData icon,
    List<T> items,
    T? selectedValue,
    void Function(T?) onChanged, {
    String Function(T)? itemToString,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: selectedValue,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      items: items.map((T value) {
        return DropdownMenuItem<T>(
          value: value,
          child: Text(itemToString != null ? itemToString(value) : value.toString().split('.').last),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
