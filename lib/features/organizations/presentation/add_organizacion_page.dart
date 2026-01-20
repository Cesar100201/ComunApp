import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/repositories/organizacion_repository.dart';

class AddOrganizacionPage extends StatefulWidget {
  const AddOrganizacionPage({super.key});

  @override
  State<AddOrganizacionPage> createState() => _AddOrganizacionPageState();
}

class _AddOrganizacionPageState extends State<AddOrganizacionPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = OrganizacionRepository();

  final _nombreLargoController = TextEditingController();
  final _abreviacionController = TextEditingController();

  TipoOrganizacion _selectedTipo = TipoOrganizacion.Politico;
  bool _tieneAbreviacion = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nombreLargoController.dispose();
    _abreviacionController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final organizacion = Organizacion()
        ..nombreLargo = _nombreLargoController.text.trim()
        ..abreviacion = _tieneAbreviacion && _abreviacionController.text.trim().isNotEmpty
            ? _abreviacionController.text.trim()
            : null
        ..tipo = _selectedTipo
        ..isSynced = false;

      await _repo.guardarOrganizacion(organizacion);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("✅ Organización registrada con éxito"),
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
      appBar: AppBar(title: const Text("Nueva Organización")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Datos de la Organización",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 24),
              _buildInput("Nombre Largo", Icons.business, _nombreLargoController),
              const SizedBox(height: 20),
              
              // Checkbox para indicar si tiene abreviación
              Row(
                children: [
                  Checkbox(
                    value: _tieneAbreviacion,
                    onChanged: (bool? value) {
                      setState(() {
                        _tieneAbreviacion = value ?? false;
                        if (!_tieneAbreviacion) {
                          _abreviacionController.clear();
                        }
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      "Tiene abreviación",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Campo de abreviación (solo visible si tiene abreviación)
              if (_tieneAbreviacion)
                _buildInput(
                  "Abreviación",
                  Icons.short_text,
                  _abreviacionController,
                  required: true,
                ),
              if (_tieneAbreviacion) const SizedBox(height: 16),
              _buildDropdown<TipoOrganizacion>(
                "Tipo de Organización",
                Icons.category,
                TipoOrganizacion.values,
                _selectedTipo,
                (TipoOrganizacion? newValue) {
                  setState(() {
                    _selectedTipo = newValue!;
                  });
                },
              ),
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
                      : const Text("GUARDAR ORGANIZACIÓN"),
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

  Widget _buildDropdown<T>(
    String label,
    IconData icon,
    List<T> items,
    T selectedValue,
    void Function(T?) onChanged,
  ) {
    return DropdownButtonFormField<T>(
      initialValue: selectedValue,
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
