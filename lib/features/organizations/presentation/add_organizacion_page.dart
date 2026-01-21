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
  final _cargoController = TextEditingController();

  TipoOrganizacion _selectedTipo = TipoOrganizacion.Politico;
  bool _tieneAbreviacion = false;
  bool _isSaving = false;
  
  final List<Cargo> _cargos = [];

  @override
  void dispose() {
    _nombreLargoController.dispose();
    _abreviacionController.dispose();
    _cargoController.dispose();
    super.dispose();
  }

  void _agregarCargo(bool esUnico) {
    final nombreCargo = _cargoController.text.trim();
    if (nombreCargo.isEmpty) return;
    
    // Verificar que no exista ya
    if (_cargos.any((c) => c.nombreCargo.toLowerCase() == nombreCargo.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Este cargo ya existe"),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    
    setState(() {
      _cargos.add(Cargo()
        ..nombreCargo = nombreCargo
        ..esUnico = esUnico);
      _cargoController.clear();
    });
  }

  void _eliminarCargo(int index) {
    setState(() {
      _cargos.removeAt(index);
    });
  }

  Future<void> _mostrarDialogoAgregarCargo() async {
    final nombreCargo = _cargoController.text.trim();
    if (nombreCargo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Escriba el nombre del cargo primero"),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final esUnico = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tipo de Cargo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("¿Cuántas personas pueden ocupar el cargo \"$nombreCargo\"?"),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.person, color: AppColors.warning),
              title: const Text("Cargo Único"),
              subtitle: const Text("Solo una persona puede ocuparlo"),
              onTap: () => Navigator.pop(context, true),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppColors.warning),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.groups, color: AppColors.info),
              title: const Text("Cargo Múltiple"),
              subtitle: const Text("Varias personas pueden ocuparlo"),
              onTap: () => Navigator.pop(context, false),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppColors.info),
              ),
            ),
          ],
        ),
      ),
    );

    if (esUnico != null) {
      _agregarCargo(esUnico);
    }
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
        ..cargos = _cargos
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
              
              // Sección de cargos
              Text(
                "Cargos",
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
                      controller: _cargoController,
                      decoration: const InputDecoration(
                        labelText: "Nombre del Cargo",
                        prefixIcon: Icon(Icons.work),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _mostrarDialogoAgregarCargo,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Agregar"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_cargos.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _cargos.asMap().entries.map((entry) {
                    final cargo = entry.value;
                    return Chip(
                      avatar: Icon(
                        cargo.esUnico ? Icons.person : Icons.groups,
                        size: 18,
                        color: cargo.esUnico ? AppColors.warning : AppColors.info,
                      ),
                      label: Text(cargo.nombreCargo),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () => _eliminarCargo(entry.key),
                      backgroundColor: cargo.esUnico 
                          ? AppColors.warning.withOpacity(0.1)
                          : AppColors.info.withOpacity(0.1),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "🟡 Único: solo una persona • 🔵 Múltiple: varias personas",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                        ),
                      ),
                    ],
                  ),
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
