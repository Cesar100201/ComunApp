import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../../../../models/models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';
import '../../inhabitants/data/repositories/vinculacion_repository.dart';

class EditConsejoVinculacionesPage extends StatefulWidget {
  final ConsejoComunal consejo;

  const EditConsejoVinculacionesPage({
    super.key,
    required this.consejo,
  });

  @override
  State<EditConsejoVinculacionesPage> createState() => _EditConsejoVinculacionesPageState();
}

class _EditConsejoVinculacionesPageState extends State<EditConsejoVinculacionesPage> {
  late VinculacionRepository _vinculacionRepo;
  late final TextEditingController _cedulaController;
  
  List<Vinculacion> _vinculaciones = [];
  String? _cargoSeleccionado;
  final Ambito _ambitoSeleccionado = Ambito.Comunal; // Fijo para consejos comunales

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final isar = await DbHelper().db;
    _vinculacionRepo = VinculacionRepository(isar);
    _cedulaController = TextEditingController();
    
    await _cargarVinculaciones();
  }

  Future<void> _cargarVinculaciones() async {
    setState(() => _isLoading = true);
    
    final isar = await DbHelper().db;
    final todasVinculaciones = await isar.vinculacions.where().findAll();
    
    final vinculacionesConsejo = <Vinculacion>[];
    for (var v in todasVinculaciones) {
      if (v.isDeleted) continue;
      await v.consejoComunal.load();
      await v.persona.load();
      if (v.consejoComunal.value?.id == widget.consejo.id) {
        vinculacionesConsejo.add(v);
      }
    }
    
    if (mounted) {
      setState(() {
        _vinculaciones = vinculacionesConsejo;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _cedulaController.dispose();
    super.dispose();
  }

  Future<void> _agregarVinculacion() async {
    if (_cargoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Seleccione un cargo"),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final cedula = int.tryParse(_cedulaController.text.trim());
    if (cedula == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Ingrese una cédula válida"),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    try {
      final isar = await DbHelper().db;
      
      final habitante = await isar.habitantes.where().cedulaEqualTo(cedula).findFirst();
      
      if (habitante == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("No se encontró ningún habitante con cédula $cedula"),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final cargo = widget.consejo.cargos.firstWhere(
        (c) => c.nombreCargo == _cargoSeleccionado,
        orElse: () => Cargo()..nombreCargo = ''..esUnico = false,
      );
      
      if (cargo.esUnico) {
        // Verificar si ya existe una vinculación activa con este cargo
        if (_vinculaciones.any((v) => v.cargo == _cargoSeleccionado && v.activo)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("El cargo \"$_cargoSeleccionado\" ya está ocupado"),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      await isar.writeTxn(() async {
        final vinculacion = Vinculacion()
          ..cargo = _cargoSeleccionado!
          ..ambito = _ambitoSeleccionado
          ..activo = true
          ..isSynced = false;
        
        vinculacion.persona.value = habitante;
        vinculacion.consejoComunal.value = widget.consejo;
        
        await isar.vinculacions.put(vinculacion);
        await vinculacion.persona.save();
        await vinculacion.consejoComunal.save();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ ${habitante.nombreCompleto} vinculado como $_cargoSeleccionado"),
            backgroundColor: AppColors.success,
          ),
        );
        _cedulaController.clear();
        _cargoSeleccionado = null;
        await _cargarVinculaciones();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al vincular: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _eliminarVinculacion(Vinculacion vinculacion) async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar"),
        content: Text("¿Eliminar vinculación de ${vinculacion.persona.value?.nombreCompleto}?"),
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
        await _cargarVinculaciones();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ Vinculación eliminada"),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: $e"),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleActivoVinculacion(Vinculacion vinculacion) async {
    try {
      final isar = await DbHelper().db;
      await isar.writeTxn(() async {
        final v = await isar.vinculacions.get(vinculacion.id);
        if (v != null) {
          v.activo = !v.activo;
          v.isSynced = false;
          await isar.vinculacions.put(v);
        }
      });
      await _cargarVinculaciones();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vinculaciones"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Gestión de Vinculaciones",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "Asigna personas a los cargos de este consejo comunal.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),

            if (widget.consejo.cargos.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Este consejo comunal no tiene cargos definidos. Debe agregarlos primero en la sección de Estructura Organizativa.",
                        style: TextStyle(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Formulario para agregar vinculación
              Card(
                color: AppColors.primaryUltraLight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Agregar Vinculación",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        value: _cargoSeleccionado,
                        decoration: const InputDecoration(
                          labelText: "Cargo *",
                          prefixIcon: Icon(Icons.work),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: widget.consejo.cargos.map((cargo) {
                          return DropdownMenuItem(
                            value: cargo.nombreCargo,
                            child: Row(
                              children: [
                                Icon(
                                  cargo.esUnico ? Icons.person : Icons.groups,
                                  size: 16,
                                  color: cargo.esUnico ? AppColors.warning : AppColors.info,
                                ),
                                const SizedBox(width: 8),
                                Text(cargo.nombreCargo),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _cargoSeleccionado = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // Ámbito fijo para consejos comunales
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.info.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.info, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Ámbito: Comunal",
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.info,
                                        ),
                                  ),
                                  Text(
                                    "Los consejos comunales operan a nivel comunal",
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cedulaController,
                              decoration: const InputDecoration(
                                labelText: "Cédula del Habitante *",
                                prefixIcon: Icon(Icons.badge),
                                hintText: "12345678",
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _agregarVinculacion,
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text("Vincular"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Lista de vinculaciones
              Text(
                "Personas Vinculadas",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_vinculaciones.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      "No hay vinculaciones creadas",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _vinculaciones.length,
                  itemBuilder: (context, index) {
                    final v = _vinculaciones[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: v.activo 
                              ? AppColors.success.withOpacity(0.1) 
                              : AppColors.textTertiary.withOpacity(0.1),
                          child: Icon(
                            Icons.person,
                            color: v.activo ? AppColors.success : AppColors.textTertiary,
                          ),
                        ),
                        title: Text(
                          v.persona.value?.nombreCompleto ?? "Sin nombre",
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        subtitle: Column(
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                v.activo ? Icons.toggle_on : Icons.toggle_off,
                                color: v.activo ? AppColors.success : AppColors.textTertiary,
                              ),
                              onPressed: () => _toggleActivoVinculacion(v),
                              tooltip: v.activo ? "Desactivar" : "Activar",
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: AppColors.error),
                              onPressed: () => _eliminarVinculacion(v),
                              tooltip: "Eliminar",
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}
