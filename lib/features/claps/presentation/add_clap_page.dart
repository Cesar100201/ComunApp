import 'package:flutter/material.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/app_config.dart';
import '../../../../core/contracts/clap_repository.dart';
import '../../../../core/contracts/habitante_repository.dart';

class AddClapPage extends StatefulWidget {
  const AddClapPage({super.key});

  @override
  State<AddClapPage> createState() => _AddClapPageState();
}

class _AddClapPageState extends State<AddClapPage> {
  final _formKey = GlobalKey<FormState>();
  ClapRepository? _repo;
  HabitanteRepository? _habitanteRepo;
  bool _repoInicializado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_repoInicializado) {
      final config = AppConfigScope.of(context);
      _repo = config.clapRepository;
      _habitanteRepo = config.habitanteRepository;
      _repoInicializado = true;
    }
  }

  Future<void> _inicializarRepositorio() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    final config = AppConfigScope.of(context);
    setState(() {
      _repo = config.clapRepository;
      _habitanteRepo = config.habitanteRepository;
      _repoInicializado = true;
    });
  }

  final _nombreClapController = TextEditingController();
  final _cedulaJefeController = TextEditingController();

  Habitante? _jefeEncontrado;
  bool _isSaving = false;
  bool _isBuscandoJefe = false;

  @override
  void dispose() {
    _nombreClapController.dispose();
    _cedulaJefeController.dispose();
    super.dispose();
  }

  Future<void> _buscarJefe() async {
    final cedulaTexto = _cedulaJefeController.text.trim();
    if (cedulaTexto.isEmpty) {
      if (!mounted) return;
      setState(() {
        _jefeEncontrado = null;
      });
      return;
    }

    final cedulaInt = int.tryParse(cedulaTexto);
    if (cedulaInt == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Cédula inválida"),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isBuscandoJefe = true;
    });

    try {
      // Asegurar que el repositorio esté inicializado
      if (!_repoInicializado || _habitanteRepo == null) {
        await _inicializarRepositorio();
      }
      
      final jefe = await _habitanteRepo!.getHabitanteByCedula(cedulaInt);
      if (!mounted) return;
      setState(() {
        _jefeEncontrado = jefe;
        _isBuscandoJefe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _jefeEncontrado = null;
        _isBuscandoJefe = false;
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final clap = Clap()
        ..nombreClap = _nombreClapController.text.trim()
        ..isSynced = false;

      if (_jefeEncontrado != null) {
        clap.jefeComunidad.value = _jefeEncontrado;
      }

      final repo = _repo;
      if (repo == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Configuración no disponible")),
          );
        }
        return;
      }
      await repo.guardarClap(clap);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("✅ CLAP registrado con éxito"),
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
      appBar: AppBar(title: const Text("Nuevo CLAP")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Datos del CLAP",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 24),
              _buildInput("Nombre del CLAP", Icons.store, _nombreClapController),
              const SizedBox(height: 24),
              Text(
                "Jefe de Comunidad",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cedulaJefeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Cédula del Jefe de Comunidad",
                  prefixIcon: const Icon(Icons.person_search),
                  suffixIcon: _isBuscandoJefe
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _buscarJefe,
                        ),
                ),
                onChanged: (value) {
                  Future.delayed(const Duration(milliseconds: 800), () {
                    if (_cedulaJefeController.text == value && value.isNotEmpty) {
                      _buscarJefe();
                    }
                  });
                },
              ),
              if (_jefeEncontrado != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: AppColors.success.withValues(alpha: 0.1),
                  child: ListTile(
                    leading: Icon(Icons.check_circle, color: AppColors.success),
                    title: Text(
                      _jefeEncontrado!.nombreCompleto,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    subtitle: Text("Cédula: ${_jefeEncontrado!.cedula}"),
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
                      : const Text("GUARDAR CLAP"),
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
}
