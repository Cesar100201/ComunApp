import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';
import '../data/repositories/habitante_repository.dart';

class EditHabitanteDireccionPage extends StatefulWidget {
  final Habitante habitante;

  const EditHabitanteDireccionPage({
    super.key,
    required this.habitante,
  });

  @override
  State<EditHabitanteDireccionPage> createState() => _EditHabitanteDireccionPageState();
}

class _EditHabitanteDireccionPageState extends State<EditHabitanteDireccionPage> {
  final _formKey = GlobalKey<FormState>();
  late final HabitanteRepository _repo;

  late final TextEditingController _estadoController;
  late final TextEditingController _municipioController;
  late final TextEditingController _calleController;
  late final TextEditingController _numeroCasaController;
  late Parroquia _selectedParroquia;
  Comuna? _selectedComuna;
  ConsejoComunal? _selectedConsejoComunal;
  String _selectedComunidad = '';
  Clap? _selectedClap;

  List<Comuna> _comunas = [];
  List<Comuna> _comunasFiltradas = [];
  List<ConsejoComunal> _consejosComunales = [];
  List<ConsejoComunal> _consejosComunalesFiltrados = [];
  List<Clap> _claps = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
    _parsearDireccion();
    _cargarListas();
  }

  void _parsearDireccion() {
    final direccion = widget.habitante.direccion;
    final partes = direccion.split(',').map((e) => e.trim()).toList();
    
    _estadoController = TextEditingController();
    _municipioController = TextEditingController();
    _calleController = TextEditingController();
    _numeroCasaController = TextEditingController();
    
    for (var i = 0; i < partes.length; i++) {
      final parte = partes[i];
      if (parte.toLowerCase().startsWith('calle ')) {
        _calleController.text = parte.substring(6).trim();
      } else if (parte.toLowerCase().startsWith('casa ')) {
        _numeroCasaController.text = parte.substring(5).trim();
      } else if (i == 0) {
        _estadoController.text = parte;
      } else if (i == 1) {
        _municipioController.text = parte;
      }
    }

    // Cargar datos de relaciones
    if (widget.habitante.consejoComunal.value != null) {
      _selectedConsejoComunal = widget.habitante.consejoComunal.value;
      _selectedComuna = _selectedConsejoComunal?.comuna.value;
      if (_selectedComuna != null) {
        _selectedParroquia = _selectedComuna!.parroquia;
      } else {
        _selectedParroquia = Parroquia.LaFria;
      }
    } else {
      _selectedParroquia = Parroquia.LaFria;
    }

    _selectedClap = widget.habitante.clap.value;
  }

  Future<void> _initializeRepository() async {
    final isar = await DbHelper().db;
    _repo = HabitanteRepository(isar);
  }

  Future<void> _cargarListas() async {
    final isar = await DbHelper().db;
    _comunas = await isar.comunas.where().findAll();
    _consejosComunales = await isar.consejoComunals.where().findAll();
    _claps = await isar.claps.where().findAll();
    await _filtrarLocalizaciones();
    if (mounted) setState(() {});
  }

  Future<void> _filtrarLocalizaciones() async {
    _comunasFiltradas = _comunas.where((c) => c.parroquia == _selectedParroquia).toList();
    _comunasFiltradas.sort((a, b) => a.nombreComuna.compareTo(b.nombreComuna));
    
    if (_selectedComuna != null && !_comunasFiltradas.any((c) => c.id == _selectedComuna!.id)) {
      _selectedComuna = null;
      _selectedConsejoComunal = null;
      _selectedComunidad = '';
    }
    
    if (_selectedComuna != null) {
      _consejosComunalesFiltrados = [];
      for (var cc in _consejosComunales) {
        await cc.comuna.load();
        if (cc.comuna.value?.id == _selectedComuna!.id) {
          _consejosComunalesFiltrados.add(cc);
        }
      }
      _consejosComunalesFiltrados.sort((a, b) => a.nombreConsejo.compareTo(b.nombreConsejo));
      
      if (_selectedConsejoComunal != null) {
        await _selectedConsejoComunal!.comuna.load();
        if (_selectedConsejoComunal!.comuna.value?.id != _selectedComuna!.id) {
          _selectedConsejoComunal = null;
          _selectedComunidad = '';
        }
      }
    } else {
      _consejosComunalesFiltrados = [];
      _selectedConsejoComunal = null;
      _selectedComunidad = '';
    }
    
    if (mounted) setState(() {});
  }

  String _construirDireccion() {
    final partes = <String>[];
    if (_estadoController.text.trim().isNotEmpty) partes.add(_estadoController.text.trim());
    if (_municipioController.text.trim().isNotEmpty) partes.add(_municipioController.text.trim());
    partes.add(_selectedParroquia.toString().split('.').last);
    if (_selectedComuna != null) partes.add(_selectedComuna!.nombreComuna);
    if (_selectedConsejoComunal != null) partes.add(_selectedConsejoComunal!.nombreConsejo);
    if (_selectedComunidad.isNotEmpty) partes.add(_selectedComunidad);
    if (_calleController.text.trim().isNotEmpty) partes.add("Calle ${_calleController.text.trim()}");
    if (_numeroCasaController.text.trim().isNotEmpty) partes.add("Casa ${_numeroCasaController.text.trim()}");

    return partes.join(", ");
  }

  @override
  void dispose() {
    _estadoController.dispose();
    _municipioController.dispose();
    _calleController.dispose();
    _numeroCasaController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final isar = await DbHelper().db;
      final habitante = await isar.habitantes.get(widget.habitante.id);

      if (habitante != null) {
        habitante.direccion = _construirDireccion();
        
        if (_selectedConsejoComunal != null) {
          habitante.consejoComunal.value = _selectedConsejoComunal;
        } else {
          habitante.consejoComunal.value = null;
        }
        
        if (_selectedClap != null) {
          habitante.clap.value = _selectedClap;
        } else {
          habitante.clap.value = null;
        }

        await _repo.actualizarHabitante(habitante);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ Dirección actualizada"),
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
        title: const Text("Editar Dirección"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _estadoController,
                decoration: const InputDecoration(
                  labelText: "Estado",
                  prefixIcon: Icon(Icons.map),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _municipioController,
                decoration: const InputDecoration(
                  labelText: "Municipio",
                  prefixIcon: Icon(Icons.location_city),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<Parroquia>(
                value: _selectedParroquia,
                decoration: const InputDecoration(
                  labelText: "Parroquia *",
                  prefixIcon: Icon(Icons.place),
                ),
                items: Parroquia.values.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text(p.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedParroquia = value;
                      _filtrarLocalizaciones();
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              if (_comunasFiltradas.isNotEmpty)
                DropdownButtonFormField<Comuna>(
                  value: _selectedComuna,
                  decoration: const InputDecoration(
                    labelText: "Comuna",
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                  items: [
                    const DropdownMenuItem<Comuna>(
                      value: null,
                      child: Text("Seleccione..."),
                    ),
                    ..._comunasFiltradas.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(c.nombreComuna),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedComuna = value;
                      _filtrarLocalizaciones();
                    });
                  },
                ),
              const SizedBox(height: 16),

              if (_consejosComunalesFiltrados.isNotEmpty)
                DropdownButtonFormField<ConsejoComunal>(
                  value: _selectedConsejoComunal,
                  decoration: const InputDecoration(
                    labelText: "Consejo Comunal",
                    prefixIcon: Icon(Icons.groups),
                  ),
                  items: [
                    const DropdownMenuItem<ConsejoComunal>(
                      value: null,
                      child: Text("Seleccione..."),
                    ),
                    ..._consejosComunalesFiltrados.map((cc) {
                      return DropdownMenuItem(
                        value: cc,
                        child: Text(cc.nombreConsejo),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedConsejoComunal = value);
                  },
                ),
              const SizedBox(height: 16),

              if (_claps.isNotEmpty)
                DropdownButtonFormField<Clap>(
                  value: _selectedClap,
                  decoration: const InputDecoration(
                    labelText: "CLAP",
                    prefixIcon: Icon(Icons.food_bank),
                  ),
                  items: [
                    const DropdownMenuItem<Clap>(
                      value: null,
                      child: Text("Seleccione..."),
                    ),
                    ..._claps.map((clap) {
                      return DropdownMenuItem(
                        value: clap,
                        child: Text(clap.nombreClap),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedClap = value);
                  },
                ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _calleController,
                decoration: const InputDecoration(
                  labelText: "Calle",
                  prefixIcon: Icon(Icons.streetview),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _numeroCasaController,
                decoration: const InputDecoration(
                  labelText: "Número de Casa",
                  prefixIcon: Icon(Icons.home),
                ),
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
