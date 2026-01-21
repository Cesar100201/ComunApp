import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';

class EditOrganizacionInfoGeneralPage extends StatefulWidget {
  final Organizacion organizacion;

  const EditOrganizacionInfoGeneralPage({
    super.key,
    required this.organizacion,
  });

  @override
  State<EditOrganizacionInfoGeneralPage> createState() => _EditOrganizacionInfoGeneralPageState();
}

class _EditOrganizacionInfoGeneralPageState extends State<EditOrganizacionInfoGeneralPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreLargoController;
  late final TextEditingController _abreviacionController;
  late TipoOrganizacion _selectedTipo;
  late bool _tieneAbreviacion;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nombreLargoController = TextEditingController(text: widget.organizacion.nombreLargo);
    _abreviacionController = TextEditingController(text: widget.organizacion.abreviacion ?? '');
    _selectedTipo = widget.organizacion.tipo;
    _tieneAbreviacion = widget.organizacion.abreviacion != null && widget.organizacion.abreviacion!.isNotEmpty;
  }

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
      final isar = await DbHelper().db;
      
      await isar.writeTxn(() async {
        final org = await isar.organizacions.get(widget.organizacion.id);
        
        if (org != null) {
          org.nombreLargo = _nombreLargoController.text.trim();
          org.abreviacion = _tieneAbreviacion && _abreviacionController.text.trim().isNotEmpty
              ? _abreviacionController.text.trim()
              : null;
          org.tipo = _selectedTipo;
          org.isSynced = false;
          
          await isar.organizacions.put(org);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("✅ Información actualizada"),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
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
        title: const Text("Editar Información General"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nombreLargoController,
                decoration: const InputDecoration(
                  labelText: "Nombre Completo *",
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) => value?.isEmpty ?? true ? "Campo requerido" : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<TipoOrganizacion>(
                value: _selectedTipo,
                decoration: const InputDecoration(
                  labelText: "Tipo de Organización *",
                  prefixIcon: Icon(Icons.category),
                ),
                items: TipoOrganizacion.values.map((tipo) {
                  return DropdownMenuItem(
                    value: tipo,
                    child: Text(tipo.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedTipo = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              CheckboxListTile(
                title: const Text("Tiene abreviación"),
                value: _tieneAbreviacion,
                onChanged: (value) {
                  setState(() {
                    _tieneAbreviacion = value ?? false;
                    if (!_tieneAbreviacion) {
                      _abreviacionController.clear();
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              
              if (_tieneAbreviacion) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _abreviacionController,
                  decoration: const InputDecoration(
                    labelText: "Abreviación",
                    prefixIcon: Icon(Icons.short_text),
                  ),
                  validator: _tieneAbreviacion
                      ? (value) => value?.isEmpty ?? true ? "Campo requerido si tiene abreviación" : null
                      : null,
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
