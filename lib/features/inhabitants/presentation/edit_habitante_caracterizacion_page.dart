import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/user_role_service.dart';
import '../../../../core/utils/constants.dart';
import '../../../../database/db_helper.dart';
import '../data/repositories/habitante_repository.dart';

class EditHabitanteCaracterizacionPage extends StatefulWidget {
  final Habitante habitante;

  const EditHabitanteCaracterizacionPage({
    super.key,
    required this.habitante,
  });

  @override
  State<EditHabitanteCaracterizacionPage> createState() => _EditHabitanteCaracterizacionPageState();
}

class _EditHabitanteCaracterizacionPageState extends State<EditHabitanteCaracterizacionPage> {
  final _formKey = GlobalKey<FormState>();
  late final HabitanteRepository _repo;
  final UserRoleService _roleService = UserRoleService();

  late EstatusPolitico _selectedEstatusPolitico;
  late NivelVoto _selectedNivelVoto;
  late int _selectedNivelUsuario;

  bool _isSaving = false;
  bool _canEditNivelUsuario = false;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
    _selectedEstatusPolitico = widget.habitante.estatusPolitico;
    _selectedNivelVoto = widget.habitante.nivelVoto;
    _selectedNivelUsuario = widget.habitante.nivelUsuario;
    _roleService.getNivelUsuario().then((n) {
      if (mounted) setState(() => _canEditNivelUsuario = n == AppConstants.nivelAdministrador);
    });
  }

  Future<void> _initializeRepository() async {
    final isar = await DbHelper().db;
    _repo = HabitanteRepository(isar);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final isar = await DbHelper().db;
      final habitante = await isar.habitantes.get(widget.habitante.id);

      if (habitante != null) {
        habitante.estatusPolitico = _selectedEstatusPolitico;
        habitante.nivelVoto = _selectedNivelVoto;
        if (_canEditNivelUsuario) habitante.nivelUsuario = _selectedNivelUsuario;

        await _repo.actualizarHabitante(habitante);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Caracterización política actualizada"),
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
        title: const Text("Editar Caracterización Política"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Estatus político
              DropdownButtonFormField<EstatusPolitico>(
                initialValue: _selectedEstatusPolitico,
                decoration: const InputDecoration(
                  labelText: "Estatus Político *",
                  prefixIcon: Icon(Icons.how_to_vote),
                ),
                items: EstatusPolitico.values.map((estatus) {
                  return DropdownMenuItem(
                    value: estatus,
                    child: Text(estatus.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedEstatusPolitico = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Nivel de voto
              DropdownButtonFormField<NivelVoto>(
                initialValue: _selectedNivelVoto,
                decoration: const InputDecoration(
                  labelText: "Nivel de Voto *",
                  prefixIcon: Icon(Icons.poll),
                ),
                items: NivelVoto.values.map((nivel) {
                  return DropdownMenuItem(
                    value: nivel,
                    child: Text(nivel.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedNivelVoto = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Nivel de usuario: solo visible y editable para administrador
              if (_canEditNivelUsuario) ...[
                DropdownButtonFormField<int>(
                  initialValue: _selectedNivelUsuario >= 1 && _selectedNivelUsuario <= 3 ? _selectedNivelUsuario : AppConstants.nivelInvitado,
                  decoration: const InputDecoration(
                    labelText: "Nivel de Usuario *",
                    prefixIcon: Icon(Icons.shield),
                  ),
                  items: [1, 2, 3].map((nivel) {
                    return DropdownMenuItem(
                      value: nivel,
                      child: Text(AppConstants.nivelUsuarioLabel(nivel)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedNivelUsuario = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
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
