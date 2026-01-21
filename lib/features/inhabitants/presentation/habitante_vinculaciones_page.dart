import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';
import '../data/repositories/vinculacion_repository.dart';
import '../../organizaciones/data/repositories/organizacion_repository.dart';

// Clase helper para representar tanto organizaciones como consejos comunales
class EntidadVinculable {
  final String nombre;
  final List<Cargo> cargos;
  final Organizacion? organizacion;
  final ConsejoComunal? consejoComunal;
  
  EntidadVinculable({
    required this.nombre,
    required this.cargos,
    this.organizacion,
    this.consejoComunal,
  });
  
  bool get esOrganizacion => organizacion != null;
  bool get esConsejoComun => consejoComunal != null;
}

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
    
    // Cargar relaciones
    for (var v in vinculaciones) {
      await v.organizacion.load();
      await v.consejoComunal.load();
    }
    
    if (mounted) {
      setState(() {
        _vinculaciones = vinculaciones;
        _isLoading = false;
      });
    }
  }

  Future<void> _agregarVinculacion() async {
    // Cargar el habitante completo con sus relaciones
    final isar = await DbHelper().db;
    final habitanteCompleto = await isar.habitantes.get(widget.habitante.id);
    if (habitanteCompleto == null) return;
    
    await habitanteCompleto.consejoComunal.load();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _VinculacionDialog(
        vinculacionRepo: _vinculacionRepo,
        organizacionRepo: _organizacionRepo,
        habitante: habitanteCompleto,
      ),
    );

    if (result == true) {
      _cargarVinculaciones();
    }
  }

  Future<void> _editarVinculacion(Vinculacion vinculacion) async {
    // Cargar el habitante completo con sus relaciones
    final isar = await DbHelper().db;
    final habitanteCompleto = await isar.habitantes.get(widget.habitante.id);
    if (habitanteCompleto == null) return;
    
    await habitanteCompleto.consejoComunal.load();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _VinculacionDialog(
        vinculacionRepo: _vinculacionRepo,
        organizacionRepo: _organizacionRepo,
        habitante: habitanteCompleto,
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
    // Determinar el nombre y tipo de la entidad
    String nombreEntidad = "Sin asignar";
    IconData icono = Icons.group_work;
    Color colorIcono = v.activo ? AppColors.success : AppColors.textTertiary;
    String tipoEntidad = "";
    
    if (v.organizacion.value != null) {
      nombreEntidad = v.organizacion.value!.nombreLargo;
      icono = Icons.business;
      tipoEntidad = "Organización";
    } else if (v.consejoComunal.value != null) {
      nombreEntidad = v.consejoComunal.value!.nombreConsejo;
      icono = Icons.groups;
      colorIcono = v.activo ? AppColors.primaryLight : AppColors.textTertiary;
      tipoEntidad = "Consejo Comunal";
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: v.activo ? colorIcono.withOpacity(0.1) : AppColors.textTertiary.withOpacity(0.1),
          child: Icon(
            icono,
            color: colorIcono,
          ),
        ),
        title: Text(
          nombreEntidad,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tipoEntidad.isNotEmpty)
                Text(
                  tipoEntidad,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                ),
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
  EntidadVinculable? _selectedEntidad;
  String? _selectedCargo;
  List<EntidadVinculable> _entidades = [];
  List<String> _cargosDisponibles = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCargo = widget.vinculacion?.cargo;
    _selectedAmbito = widget.vinculacion?.ambito ?? Ambito.Municipal;
    _activo = widget.vinculacion?.activo ?? true;
    _cargarEntidades();
  }

  Future<void> _cargarEntidades() async {
    final List<EntidadVinculable> entidades = [];
    final isar = await DbHelper().db;
    
    // Cargar organizaciones
    final orgs = await widget.organizacionRepo.getAllOrganizaciones();
    for (var org in orgs) {
      entidades.add(EntidadVinculable(
        nombre: org.nombreLargo,
        cargos: org.cargos,
        organizacion: org,
      ));
    }
    
    // Cargar el habitante completo desde la base de datos para asegurar relaciones actualizadas
    final habitanteCompleto = await isar.habitantes.get(widget.habitante.id);
    if (habitanteCompleto != null) {
      await habitanteCompleto.consejoComunal.load();
      
      if (habitanteCompleto.consejoComunal.value != null) {
        final consejo = habitanteCompleto.consejoComunal.value!;
        entidades.add(EntidadVinculable(
          nombre: "${consejo.nombreConsejo} (Consejo Comunal)",
          cargos: consejo.cargos,
          consejoComunal: consejo,
        ));
      }
    }
    
    if (mounted) {
      setState(() {
        _entidades = entidades;
        // Buscar la entidad seleccionada actual
        if (widget.vinculacion != null) {
          if (widget.vinculacion!.organizacion.value != null) {
            try {
              _selectedEntidad = _entidades.firstWhere(
                (e) => e.organizacion?.id == widget.vinculacion!.organizacion.value!.id,
              );
            } catch (e) {
              _selectedEntidad = null;
            }
          } else if (widget.vinculacion!.consejoComunal.value != null) {
            try {
              _selectedEntidad = _entidades.firstWhere(
                (e) => e.consejoComunal?.id == widget.vinculacion!.consejoComunal.value!.id,
              );
            } catch (e) {
              _selectedEntidad = null;
            }
          }
          if (_selectedEntidad != null) {
            _cargarCargosDisponibles();
          }
        }
      });
    }
  }

  void _cargarCargosDisponibles() {
    if (_selectedEntidad != null) {
      setState(() {
        _cargosDisponibles = _selectedEntidad!.cargos.map((c) => c.nombreCargo).toList();
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
    if (_selectedEntidad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Debe seleccionar una organización o consejo comunal"),
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
      final cargo = _selectedEntidad!.cargos.firstWhere(
        (c) => c.nombreCargo == _selectedCargo,
        orElse: () => Cargo()..nombreCargo = _selectedCargo!..esUnico = false,
      );

      if (cargo.esUnico) {
        // Verificar si ya existe otra vinculación activa con este cargo en esta entidad
        final isar = await DbHelper().db;
        final vinculacionesAll = await isar.vinculacions
            .filter()
            .isDeletedEqualTo(false)
            .findAll();
        
        for (var v in vinculacionesAll) {
          await v.organizacion.load();
          await v.consejoComunal.load();
          
          // Verificar si es la misma entidad
          bool mismaEntidad = false;
          if (_selectedEntidad!.esOrganizacion) {
            mismaEntidad = v.organizacion.value?.id == _selectedEntidad!.organizacion!.id;
          } else if (_selectedEntidad!.esConsejoComun) {
            mismaEntidad = v.consejoComunal.value?.id == _selectedEntidad!.consejoComunal!.id;
          }
          
          // Si es otra vinculación con el mismo cargo en la misma entidad y está activa
          if (v.id != widget.vinculacion?.id &&
              mismaEntidad &&
              v.cargo == _selectedCargo &&
              v.activo) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("El cargo \"$_selectedCargo\" ya está ocupado por otra persona"),
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
      
      // Asignar la organización o consejo comunal correspondiente
      if (_selectedEntidad!.esOrganizacion) {
        vinculacion.organizacion.value = _selectedEntidad!.organizacion;
        vinculacion.consejoComunal.value = null;
      } else if (_selectedEntidad!.esConsejoComun) {
        vinculacion.consejoComunal.value = _selectedEntidad!.consejoComunal;
        vinculacion.organizacion.value = null;
      }

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
              DropdownButtonFormField<EntidadVinculable>(
                value: _selectedEntidad,
                decoration: const InputDecoration(
                  labelText: "Organización / Consejo Comunal *",
                  prefixIcon: Icon(Icons.business),
                ),
                items: _entidades.map((entidad) {
                  return DropdownMenuItem(
                    value: entidad,
                    child: Row(
                      children: [
                        Icon(
                          entidad.esConsejoComun ? Icons.groups : Icons.business,
                          size: 16,
                          color: entidad.esConsejoComun ? AppColors.primaryLight : AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entidad.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedEntidad = value;
                    _cargarCargosDisponibles();
                  });
                },
              ),
              const SizedBox(height: 16),

              if (_cargosDisponibles.isEmpty && _selectedEntidad != null)
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
                          _selectedEntidad!.esConsejoComun 
                              ? "Este consejo comunal no tiene cargos definidos. Debe agregarlos primero."
                              : "Esta organización no tiene cargos definidos. Debe agregarlos primero.",
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
                    final cargo = _selectedEntidad!.cargos.firstWhere((c) => c.nombreCargo == cargoNombre);
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
