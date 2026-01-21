import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';
import '../data/repositories/consejo_repository.dart';

class EditConsejoInfoBasicaPage extends StatefulWidget {
  final ConsejoComunal consejo;

  const EditConsejoInfoBasicaPage({
    super.key,
    required this.consejo,
  });

  @override
  State<EditConsejoInfoBasicaPage> createState() => _EditConsejoInfoBasicaPageState();
}

class _EditConsejoInfoBasicaPageState extends State<EditConsejoInfoBasicaPage> {
  final _formKey = GlobalKey<FormState>();
  late ConsejoRepository _repo;

  late final TextEditingController _codigoSiturController;
  late final TextEditingController _rifController;
  late final TextEditingController _nombreConsejoController;
  late TipoZona _selectedTipoZona;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
    _initializeControllers();
  }

  Future<void> _initializeRepository() async {
    final isar = await DbHelper().db;
    _repo = ConsejoRepository(isar);
  }

  void _initializeControllers() {
    _codigoSiturController = TextEditingController(text: widget.consejo.codigoSitur);
    _rifController = TextEditingController(text: widget.consejo.rif ?? '');
    _nombreConsejoController = TextEditingController(text: widget.consejo.nombreConsejo);
    _selectedTipoZona = widget.consejo.tipoZona;
  }

  @override
  void dispose() {
    _codigoSiturController.dispose();
    _rifController.dispose();
    _nombreConsejoController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final isar = await DbHelper().db;
      final consejo = await isar.consejoComunals.get(widget.consejo.id);

      if (consejo != null) {
        consejo.codigoSitur = _codigoSiturController.text.trim();
        consejo.rif = _rifController.text.trim().isEmpty ? null : _rifController.text.trim();
        consejo.nombreConsejo = _nombreConsejoController.text.trim();
        consejo.tipoZona = _selectedTipoZona;

        await _repo.actualizarConsejo(consejo);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ Información actualizada"),
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
        title: const Text("Editar Información Básica"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _codigoSiturController,
                decoration: const InputDecoration(
                  labelText: "Código SITUR *",
                  prefixIcon: Icon(Icons.qr_code),
                ),
                validator: (value) => value?.isEmpty ?? true ? "Campo requerido" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _rifController,
                decoration: const InputDecoration(
                  labelText: "RIF (opcional)",
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nombreConsejoController,
                decoration: const InputDecoration(
                  labelText: "Nombre del Consejo *",
                  prefixIcon: Icon(Icons.groups),
                ),
                validator: (value) => value?.isEmpty ?? true ? "Campo requerido" : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<TipoZona>(
                value: _selectedTipoZona,
                decoration: const InputDecoration(
                  labelText: "Tipo de Zona *",
                  prefixIcon: Icon(Icons.terrain),
                ),
                items: TipoZona.values.map((zona) {
                  return DropdownMenuItem(
                    value: zona,
                    child: Text(zona.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedTipoZona = value);
                  }
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
