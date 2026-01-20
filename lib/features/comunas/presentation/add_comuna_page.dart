import 'package:flutter/material.dart';
import '../../../../database/db_helper.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/repositories/comuna_repository.dart';
import '../../consejos/presentation/map_location_picker_page.dart';

class AddComunaPage extends StatefulWidget {
  const AddComunaPage({super.key});

  @override
  State<AddComunaPage> createState() => _AddComunaPageState();
}

class _AddComunaPageState extends State<AddComunaPage> {
  final _formKey = GlobalKey<FormState>();
  late final ComunaRepository _repo;

  final _codigoSiturController = TextEditingController();
  final _rifController = TextEditingController();
  final _codigoComElectoralController = TextEditingController();
  final _nombreComunaController = TextEditingController();
  final _municipioController = TextEditingController();

  Parroquia _selectedParroquia = Parroquia.LaFria;
  bool _isSaving = false;

  double? _latitud;
  double? _longitud;

  @override
  void initState() {
    super.initState();
    _initializeRepositoryAndLoadData();
  }

  Future<void> _initializeRepositoryAndLoadData() async {
    final isar = await DbHelper().db;
    _repo = ComunaRepository(isar);
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

  Future<void> _guardar() async {
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
      final comuna = Comuna()
        ..codigoSitur = _codigoSiturController.text.trim()
        ..rif = _rifController.text.trim().isEmpty ? null : _rifController.text.trim()
        ..codigoComElectoral = _codigoComElectoralController.text.trim()
        ..nombreComuna = _nombreComunaController.text.trim()
        ..municipio = _municipioController.text.trim().isEmpty
            ? "García de Hevia"
            : _municipioController.text.trim()
        ..parroquia = _selectedParroquia
        ..latitud = _latitud ?? 0.0
        ..longitud = _longitud ?? 0.0
        ..isSynced = false;

      await _repo.guardarComuna(comuna);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("✅ Comuna registrada con éxito"),
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
      appBar: AppBar(title: const Text("Nueva Comuna")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Datos de la Comuna",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 24),
              _buildInput("Código SITUR", Icons.qr_code, _codigoSiturController),
              const SizedBox(height: 16),
              _buildInputWithOptional("RIF", Icons.badge, _rifController),
              const SizedBox(height: 16),
              _buildInput("Código Comunal Electoral", Icons.ballot, _codigoComElectoralController),
              const SizedBox(height: 16),
              _buildInput("Nombre de la Comuna", Icons.location_city, _nombreComunaController),
              const SizedBox(height: 16),
              _buildInput("Municipio", Icons.map, _municipioController, required: false),
              const SizedBox(height: 16),
              _buildDropdown<Parroquia>(
                "Parroquia",
                Icons.place,
                Parroquia.values,
                _selectedParroquia,
                (Parroquia? newValue) {
                  setState(() {
                    _selectedParroquia = newValue!;
                  });
                },
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 32),
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
                      : const Text("GUARDAR COMUNA"),
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
    T selectedValue,
    void Function(T?) onChanged,
  ) {
    return DropdownButtonFormField<T>(
      value: selectedValue,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      items: items.map((T value) {
        return DropdownMenuItem<T>(
          value: value,
          child: Text(value.toString().split('.').last),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
