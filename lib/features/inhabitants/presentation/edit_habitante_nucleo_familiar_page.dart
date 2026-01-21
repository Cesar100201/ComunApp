import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';
import '../data/repositories/habitante_repository.dart';

class EditHabitanteNucleoFamiliarPage extends StatefulWidget {
  final Habitante habitante;

  const EditHabitanteNucleoFamiliarPage({
    super.key,
    required this.habitante,
  });

  @override
  State<EditHabitanteNucleoFamiliarPage> createState() => _EditHabitanteNucleoFamiliarPageState();
}

class _EditHabitanteNucleoFamiliarPageState extends State<EditHabitanteNucleoFamiliarPage> {
  final _formKey = GlobalKey<FormState>();
  late final HabitanteRepository _repo;

  late final TextEditingController _cedulaJefeController;
  late bool _esJefeDeFamilia;
  Habitante? _jefeEncontrado;
  bool _isBuscandoJefe = false;
  String? _errorBusquedaJefe;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
    _cedulaJefeController = TextEditingController();
    
    if (widget.habitante.jefeDeFamilia.value != null) {
      _esJefeDeFamilia = false;
      _jefeEncontrado = widget.habitante.jefeDeFamilia.value;
      _cedulaJefeController.text = _jefeEncontrado!.cedula.toString();
    } else {
      _esJefeDeFamilia = true;
    }
  }

  Future<void> _initializeRepository() async {
    final isar = await DbHelper().db;
    _repo = HabitanteRepository(isar);
  }

  @override
  void dispose() {
    _cedulaJefeController.dispose();
    super.dispose();
  }

  Future<void> _buscarJefeDeFamilia() async {
    final cedulaTexto = _cedulaJefeController.text.trim();
    if (cedulaTexto.isEmpty) {
      setState(() {
        _jefeEncontrado = null;
        _errorBusquedaJefe = null;
      });
      return;
    }

    final cedulaInt = int.tryParse(cedulaTexto);
    if (cedulaInt == null) {
      setState(() {
        _jefeEncontrado = null;
        _errorBusquedaJefe = "Cédula inválida";
      });
      return;
    }

    // No puede ser jefe de sí mismo
    if (cedulaInt == widget.habitante.cedula) {
      setState(() {
        _jefeEncontrado = null;
        _errorBusquedaJefe = "No puede ser jefe de sí mismo";
      });
      return;
    }

    setState(() {
      _isBuscandoJefe = true;
      _errorBusquedaJefe = null;
      _jefeEncontrado = null;
    });

    try {
      final local = await _repo.getHabitanteByCedula(cedulaInt);
      if (local != null) {
        await local.jefeDeFamilia.load();
        if (local.jefeDeFamilia.value != null) {
          setState(() {
            _jefeEncontrado = null;
            _errorBusquedaJefe = "Esta persona es carga familiar, no puede ser jefe";
            _isBuscandoJefe = false;
          });
          return;
        }
        setState(() {
          _jefeEncontrado = local;
          _errorBusquedaJefe = null;
          _isBuscandoJefe = false;
        });
        return;
      }

      setState(() {
        _jefeEncontrado = null;
        _errorBusquedaJefe = "No se encontró habitante con esa cédula";
        _isBuscandoJefe = false;
      });
    } catch (e) {
      setState(() {
        _jefeEncontrado = null;
        _errorBusquedaJefe = "Error al buscar: $e";
        _isBuscandoJefe = false;
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_esJefeDeFamilia && _jefeEncontrado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Debe buscar y seleccionar un jefe de familia válido"),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isar = await DbHelper().db;
      final habitante = await isar.habitantes.get(widget.habitante.id);

      if (habitante != null) {
        if (_esJefeDeFamilia) {
          habitante.jefeDeFamilia.value = null;
        } else {
          if (_jefeEncontrado != null) {
            final jefeCompleto = await isar.habitantes.getByCedula(_jefeEncontrado!.cedula);
            if (jefeCompleto != null) {
              habitante.jefeDeFamilia.value = jefeCompleto;
            }
          }
        }

        await _repo.actualizarHabitante(habitante);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ Núcleo familiar actualizado"),
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
        title: const Text("Editar Núcleo Familiar"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Switch de jefe de familia
              SwitchListTile(
                title: const Text("¿Es jefe de familia?"),
                subtitle: const Text("Active si esta persona no tiene jefe de familia asignado"),
                value: _esJefeDeFamilia,
                onChanged: (value) {
                  setState(() {
                    _esJefeDeFamilia = value;
                    if (value) {
                      _cedulaJefeController.clear();
                      _jefeEncontrado = null;
                      _errorBusquedaJefe = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 24),

              // Búsqueda de jefe (solo si no es jefe)
              if (!_esJefeDeFamilia) ...[
                Text(
                  "Buscar Jefe de Familia",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cedulaJefeController,
                        decoration: InputDecoration(
                          labelText: "Cédula del Jefe *",
                          prefixIcon: const Icon(Icons.badge),
                          errorText: _errorBusquedaJefe,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) {
                          setState(() {
                            _jefeEncontrado = null;
                            _errorBusquedaJefe = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isBuscandoJefe ? null : _buscarJefeDeFamilia,
                      child: _isBuscandoJefe
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Resultado de búsqueda
                if (_jefeEncontrado != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.success),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Jefe encontrado:",
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _jefeEncontrado!.nombreCompleto,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                "C.I: ${_jefeEncontrado!.cedula}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
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
