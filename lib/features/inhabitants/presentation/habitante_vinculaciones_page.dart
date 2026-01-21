import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';
import '../data/repositories/vinculacion_repository.dart';
import '../../organizaciones/data/repositories/organizacion_repository.dart';

class HabitanteVinculacionesPage extends StatefulWidget {
  final Habitante habitante;

  const HabitanteVinculacionesPage({
    super.key,
    required this.habitante,
  });

  @override
  State<HabitanteVinculacionesPage> createState() => _HabitanteVinculacionesPageState();
}

class _HabitanteVinculacionesPageState extends State<HabitanteVinculacionesPage> {
  late final VinculacionRepository _vinculacionRepo;
  late final OrganizacionRepository _organizacionRepo;
  List<Vinculacion> _vinculaciones = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
  }

  Future<void> _initializeRepositories() async {
    final isar = await DbHelper().db;
    _vinculacionRepo = VinculacionRepository(isar);
    _organizacionRepo = OrganizacionRepository(isar);
    _cargarVinculaciones();
  }

  Future<void> _cargarVinculaciones() async {
    setState(() => _isLoading = true);
    final vinculaciones = await _vinculacionRepo.getVinculacionesPorHabitante(widget.habitante.id);
    if (mounted) {
      setState(() {
        _vinculaciones = vinculaciones;
        _isLoading = false;
      });
    }
  }

  Future<void> _agregarVinculacion() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _VinculacionDialog(
        vinculacionRepo: _vinculacionRepo,
        organizacionRepo: _organizacionRepo,
        habitante: widget.habitante,
      ),
    );

    if (result == true) {
      _cargarVinculaciones();
    }
  }

  Future<void> _editarVinculacion(Vinculacion vinculacion) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _VinculacionDialog(
        vinculacionRepo: _vinculacionRepo,
        organizacionRepo: _organizacionRepo,
        habitante: widget.habitante,
        vinculacion: vinculacion,
      ),
    );

    if (result == true) {
      _cargarVinculaciones();
    }
  }

  Future<void> _eliminarVinculacion(Vinculacion vinculacion) async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Eliminación"),
        content: const Text("¿Está seguro de que desea eliminar esta vinculación?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );

    if (confirmacion == true) {
      try {
        await _vinculacionRepo.eliminarVinculacion(vinculacion.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ Vinculación eliminada"),
              backgroundColor: AppColors.success,
            ),
          );
          _cargarVinculaciones();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error al eliminar: $e"),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vinculaciones"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _agregarVinculacion,
            tooltip: "Agregar vinculación",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vinculaciones.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _vinculaciones.length,
                  itemBuilder: (context, index) {
                    final v = _vinculaciones[index];
                    return _buildVinculacionCard(v);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_work_outlined,
            size: 80,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            "Sin vinculaciones",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            "Toca el botón + para agregar una vinculación",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildVinculacionCard(Vinculacion v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: v.activo ? AppColors.success.withOpacity(0.1) : AppColors.textTertiary.withOpacity(0.1),
          child: Icon(
            Icons.group_work,
            color: v.activo ? AppColors.success : AppColors.textTertiary,
          ),
        ),
        title: Text(
          v.organizacion.value?.nombreLargo ?? "Sin organización",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Cargo: ${v.cargo}",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              Text(
                "Ámbito: ${v.ambito.toString().split('.').last}",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: AppColors.primary, size: 20),
              onPressed: () => _editarVinculacion(v),
              tooltip: "Editar",
            ),
            IconButton(
              icon: Icon(Icons.delete, color: AppColors.error, size: 20),
              onPressed: () => _eliminarVinculacion(v),
              tooltip: "Eliminar",
            ),
          ],
        ),
      ),
    );
  }
}

class _VinculacionDialog extends StatefulWidget {
  final VinculacionRepository vinculacionRepo;
  final OrganizacionRepository organizacionRepo;
  final Habitante habitante;
  final Vinculacion? vinculacion;

  const _VinculacionDialog({
    required this.vinculacionRepo,
    required this.organizacionRepo,
    required this.habitante,
    this.vinculacion,
  });

  @override
  State<_VinculacionDialog> createState() => _VinculacionDialogState();
}

class _VinculacionDialogState extends State<_VinculacionDialog> {
  final _formKey = GlobalKey<FormState>();
  late Ambito _selectedAmbito;
  late bool _activo;
  Organizacion? _selectedOrganizacion;
  String? _selectedCargo;
  List<Organizacion> _organizaciones = [];
  List<String> _cargosDisponibles = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCargo = widget.vinculacion?.cargo;
    _selectedAmbito = widget.vinculacion?.ambito ?? Ambito.Municipal;
    _activo = widget.vinculacion?.activo ?? true;
    _selectedOrganizacion = widget.vinculacion?.organizacion.value;
    _cargarOrganizaciones();
  }

  Future<void> _cargarOrganizaciones() async {
    final orgs = await widget.organizacionRepo.getAllOrganizaciones();
    if (mounted) {
      setState(() {
        _organizaciones = orgs;
        if (_selectedOrganizacion != null) {
          _cargarCargosDisponibles();
        }
      });
    }
  }

  void _cargarCargosDisponibles() {
    if (_selectedOrganizacion != null) {
      setState(() {
        _cargosDisponibles = _selectedOrganizacion!.cargos.map((c) => c.nombreCargo).toList();
        // Si el cargo actual no está en la lista, limpiar
        if (_selectedCargo != null && !_cargosDisponibles.contains(_selectedCargo)) {
          _selectedCargo = null;
        }
      });
    } else {
      setState(() {
        _cargosDisponibles = [];
        _selectedCargo = null;
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOrganizacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Debe seleccionar una organización"),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (_selectedCargo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Debe seleccionar un cargo"),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Validar si el cargo es único y ya está ocupado
      final cargo = _selectedOrganizacion!.cargos.firstWhere(
        (c) => c.nombreCargo == _selectedCargo,
        orElse: () => Cargo()..nombreCargo = _selectedCargo!..esUnico = false,
      );

      if (cargo.esUnico) {
        // Verificar si ya existe otra vinculación activa con este cargo en esta organización
        final isar = await DbHelper().db;
        final vinculacionesOrg = await isar.vinculacions
            .filter()
            .isDeletedEqualTo(false)
            .findAll();
        
        for (var v in vinculacionesOrg) {
          await v.organizacion.load();
          // Si es otra vinculación (no la que estamos editando) con el mismo cargo y organización y está activa
          if (v.id != widget.vinculacion?.id &&
              v.organizacion.value?.id == _selectedOrganizacion!.id &&
              v.cargo == _selectedCargo &&
              v.activo) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("El cargo \"$_selectedCargo\" ya está ocupado por otra persona en esta organización"),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            setState(() => _isSaving = false);
            return;
          }
        }
      }

      final vinculacion = widget.vinculacion ?? Vinculacion();
      vinculacion.cargo = _selectedCargo!;
      vinculacion.ambito = _selectedAmbito;
      vinculacion.activo = _activo;
      vinculacion.persona.value = widget.habitante;
      vinculacion.organizacion.value = _selectedOrganizacion;

      if (widget.vinculacion == null) {
        await widget.vinculacionRepo.guardarVinculacion(vinculacion);
      } else {
        await widget.vinculacionRepo.actualizarVinculacion(vinculacion);
      }

      if (mounted) {
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
    return AlertDialog(
      title: Text(widget.vinculacion == null ? "Nueva Vinculación" : "Editar Vinculación"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Organizacion>(
                value: _selectedOrganizacion,
                decoration: const InputDecoration(
                  labelText: "Organización *",
                  prefixIcon: Icon(Icons.business),
                ),
                items: _organizaciones.map((org) {
                  return DropdownMenuItem(
                    value: org,
                    child: Text(org.nombreLargo),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedOrganizacion = value;
                    _cargarCargosDisponibles();
                  });
                },
              ),
              const SizedBox(height: 16),

              if (_cargosDisponibles.isEmpty && _selectedOrganizacion != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: AppColors.warning, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Esta organización no tiene cargos definidos. Debe agregarlos primero.",
                          style: TextStyle(color: AppColors.warning, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_cargosDisponibles.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedCargo,
                  decoration: const InputDecoration(
                    labelText: "Cargo *",
                    prefixIcon: Icon(Icons.work),
                  ),
                  items: _cargosDisponibles.map((cargoNombre) {
                    final cargo = _selectedOrganizacion!.cargos.firstWhere((c) => c.nombreCargo == cargoNombre);
                    return DropdownMenuItem(
                      value: cargoNombre,
                      child: Row(
                        children: [
                          Icon(
                            cargo.esUnico ? Icons.person : Icons.groups,
                            size: 16,
                            color: cargo.esUnico ? AppColors.warning : AppColors.info,
                          ),
                          const SizedBox(width: 8),
                          Text(cargoNombre),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCargo = value);
                  },
                  validator: (value) => value == null ? "Debe seleccionar un cargo" : null,
                ),
              const SizedBox(height: 16),

              DropdownButtonFormField<Ambito>(
                value: _selectedAmbito,
                decoration: const InputDecoration(
                  labelText: "Ámbito *",
                  prefixIcon: Icon(Icons.place),
                ),
                items: Ambito.values.map((ambito) {
                  return DropdownMenuItem(
                    value: ambito,
                    child: Text(ambito.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedAmbito = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text("Activo"),
                subtitle: const Text("¿La vinculación está activa?"),
                value: _activo,
                onChanged: (value) {
                  setState(() => _activo = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCELAR"),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _guardar,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("GUARDAR"),
        ),
      ],
    );
  }
}
