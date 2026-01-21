import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';
import '../data/repositories/habitante_repository.dart';

class EditHabitanteInfoPersonalPage extends StatefulWidget {
  final Habitante habitante;

  const EditHabitanteInfoPersonalPage({
    super.key,
    required this.habitante,
  });

  @override
  State<EditHabitanteInfoPersonalPage> createState() => _EditHabitanteInfoPersonalPageState();
}

class _EditHabitanteInfoPersonalPageState extends State<EditHabitanteInfoPersonalPage> {
  final _formKey = GlobalKey<FormState>();
  late final HabitanteRepository _repo;

  late final TextEditingController _nombreController;
  late final TextEditingController _telefonoController;
  late Nacionalidad _selectedNacionalidad;
  late Genero _selectedGenero;
  late DateTime _selectedFechaNacimiento;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
    _nombreController = TextEditingController(text: widget.habitante.nombreCompleto);
    _telefonoController = TextEditingController(text: widget.habitante.telefono);
    _selectedNacionalidad = widget.habitante.nacionalidad;
    _selectedGenero = widget.habitante.genero;
    _selectedFechaNacimiento = widget.habitante.fechaNacimiento;
  }

  Future<void> _initializeRepository() async {
    final isar = await DbHelper().db;
    _repo = HabitanteRepository(isar);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final isar = await DbHelper().db;
      final habitante = await isar.habitantes.get(widget.habitante.id);

      if (habitante != null) {
        habitante.nombreCompleto = _nombreController.text.trim().toUpperCase();
        habitante.telefono = _telefonoController.text.trim();
        habitante.nacionalidad = _selectedNacionalidad;
        habitante.genero = _selectedGenero;
        habitante.fechaNacimiento = _selectedFechaNacimiento;

        await _repo.actualizarHabitante(habitante);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ Información personal actualizada"),
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

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _selectedFechaNacimiento,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );

    if (fecha != null) {
      setState(() {
        _selectedFechaNacimiento = fecha;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Información Personal"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cédula (solo lectura)
              TextFormField(
                initialValue: "${widget.habitante.nacionalidad.toString().split('.').last}-${widget.habitante.cedula}",
                decoration: const InputDecoration(
                  labelText: "Cédula de Identidad",
                  prefixIcon: Icon(Icons.badge),
                  enabled: false,
                ),
              ),
              const SizedBox(height: 16),

              // Nombre completo
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: "Nombre Completo *",
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) => value?.isEmpty ?? true ? "Campo requerido" : null,
              ),
              const SizedBox(height: 16),

              // Teléfono
              TextFormField(
                controller: _telefonoController,
                decoration: const InputDecoration(
                  labelText: "Teléfono",
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Género
              DropdownButtonFormField<Genero>(
                value: _selectedGenero,
                decoration: const InputDecoration(
                  labelText: "Género *",
                  prefixIcon: Icon(Icons.wc),
                ),
                items: Genero.values.map((genero) {
                  return DropdownMenuItem(
                    value: genero,
                    child: Text(genero.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedGenero = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Fecha de nacimiento
              InkWell(
                onTap: _seleccionarFecha,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Fecha de Nacimiento *",
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    "${_selectedFechaNacimiento.day.toString().padLeft(2, '0')}/${_selectedFechaNacimiento.month.toString().padLeft(2, '0')}/${_selectedFechaNacimiento.year}",
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Botón guardar
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
