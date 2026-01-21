import 'package:flutter/material.dart';
import 'package:goblafria/models/models.dart';
import 'package:goblafria/core/theme/app_theme.dart';
import 'package:goblafria/database/db_helper.dart';
import 'package:goblafria/features/solicitudes/data/repositories/solicitud_repository.dart';
import 'package:goblafria/features/comunas/data/repositories/comuna_repository.dart';
import 'package:goblafria/features/organizations/data/repositories/organizacion_repository.dart';
import 'package:goblafria/features/inhabitants/data/repositories/habitante_repository.dart';

class SolicitudProfilePage extends StatefulWidget {
  final Solicitud solicitud;

  const SolicitudProfilePage({
    super.key,
    required this.solicitud,
  });

  @override
  State<SolicitudProfilePage> createState() => _SolicitudProfilePageState();
}

class _SolicitudProfilePageState extends State<SolicitudProfilePage> {
  Solicitud? _solicitudCompleto;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  
  late SolicitudRepository _solicitudRepo;
  late ComunaRepository _comunaRepo;
  late OrganizacionRepository _organizacionRepo;
  late HabitanteRepository _habitanteRepo;
  
  final _formKey = GlobalKey<FormState>();
  final _comunidadController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _cedulaCreadorController = TextEditingController();
  final _cantidadLamparasController = TextEditingController();
  final _cantidadBombillosController = TextEditingController();
  
  Comuna? _selectedComuna;
  ConsejoComunal? _selectedConsejoComunal;
  Organizacion? _selectedUbch;
  Habitante? _selectedCreador;
  TipoSolicitud _selectedTipoSolicitud = TipoSolicitud.Iluminacion;
  
  List<Comuna> _comunas = [];
  List<ConsejoComunal> _consejosComunales = [];
  List<Organizacion> _ubchs = [];

  @override
  void initState() {
    super.initState();
    _inicializarRepositorios();
  }

  Future<void> _inicializarRepositorios() async {
    final isar = await DbHelper().db;
    _solicitudRepo = SolicitudRepository(isar);
    _comunaRepo = ComunaRepository(isar);
    _organizacionRepo = OrganizacionRepository();
    _habitanteRepo = HabitanteRepository(isar);
    await _loadInitialData();
    await _cargarDatosCompletos();
  }

  Future<void> _loadInitialData() async {
    _comunas = await _comunaRepo.getAllComunas();
    _ubchs = await _organizacionRepo.getOrganizacionesByType(TipoOrganizacion.Politico);
    setState(() {});
  }

  void _onComunaChanged(Comuna? newComuna) async {
    setState(() {
      _selectedComuna = newComuna;
      _selectedConsejoComunal = null;
      _consejosComunales = [];
    });
    if (newComuna != null) {
      final consejos = await _comunaRepo.getConsejosComunalesByComunaId(newComuna.id);
      // Eliminar duplicados por ID
      final consejosUnicos = <int, ConsejoComunal>{};
      for (var consejo in consejos) {
        consejosUnicos[consejo.id] = consejo;
      }
      setState(() {
        _consejosComunales = consejosUnicos.values.toList();
      });
    }
  }

  Future<void> _cargarDatosCompletos() async {
    final isar = await DbHelper().db;
    final solicitud = await isar.solicituds.get(widget.solicitud.id);
    
    if (solicitud != null) {
      await solicitud.comuna.load();
      await solicitud.consejoComunal.load();
      await solicitud.ubch.load();
      await solicitud.creador.load();
      
      // Cargar listas primero
      _comunas = await _comunaRepo.getAllComunas();
      _ubchs = await _organizacionRepo.getOrganizacionesByType(TipoOrganizacion.Politico);
      
      // Buscar la comuna en la lista por ID para evitar problemas de referencia
      Comuna? comunaSeleccionada;
      if (solicitud.comuna.value != null) {
        final comunaCargada = solicitud.comuna.value!;
        comunaSeleccionada = _comunas.firstWhere(
          (c) => c.id == comunaCargada.id,
          orElse: () => comunaCargada,
        );
        // Cargar consejos comunales de la comuna seleccionada
        final consejos = await _comunaRepo.getConsejosComunalesByComunaId(comunaSeleccionada.id);
        // Eliminar duplicados por ID
        final consejosUnicos = <int, ConsejoComunal>{};
        for (var consejo in consejos) {
          consejosUnicos[consejo.id] = consejo;
        }
        _consejosComunales = consejosUnicos.values.toList();
      }
      
      // Buscar el consejo comunal en la lista por ID
      ConsejoComunal? consejoSeleccionado;
      if (solicitud.consejoComunal.value != null && _consejosComunales.isNotEmpty) {
        try {
          consejoSeleccionado = _consejosComunales.firstWhere(
            (c) => c.id == solicitud.consejoComunal.value!.id,
          );
        } catch (e) {
          // Si no se encuentra en la lista, dejar como null
          consejoSeleccionado = null;
        }
      }
      
      // Buscar la UBCH en la lista por ID
      Organizacion? ubchSeleccionada;
      if (solicitud.ubch.value != null) {
        ubchSeleccionada = _ubchs.firstWhere(
          (u) => u.id == solicitud.ubch.value!.id,
          orElse: () => solicitud.ubch.value!,
        );
      }
      
      setState(() {
        _solicitudCompleto = solicitud;
        _comunidadController.text = solicitud.comunidad;
        _descripcionController.text = solicitud.descripcion;
        _selectedTipoSolicitud = solicitud.tipoSolicitud;
        _selectedComuna = comunaSeleccionada;
        _selectedConsejoComunal = consejoSeleccionado;
        _selectedUbch = ubchSeleccionada;
        _selectedCreador = solicitud.creador.value;
        if (_selectedCreador != null) {
          _cedulaCreadorController.text = _selectedCreador!.cedula.toString();
        }
        if (solicitud.cantidadLamparas != null) {
          _cantidadLamparasController.text = solicitud.cantidadLamparas.toString();
        }
        if (solicitud.cantidadBombillos != null) {
          _cantidadBombillosController.text = solicitud.cantidadBombillos.toString();
        }
        _isLoading = false;
      });
      
      if (_selectedComuna != null) {
        _consejosComunales = await _comunaRepo.getConsejosComunalesByComunaId(_selectedComuna!.id);
        setState(() {});
      }
    } else {
      setState(() {
        _solicitudCompleto = widget.solicitud;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _comunidadController.dispose();
    _descripcionController.dispose();
    _cedulaCreadorController.dispose();
    _cantidadLamparasController.dispose();
    _cantidadBombillosController.dispose();
    super.dispose();
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCreador == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Por favor, busque y seleccione un creador."),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final isar = await DbHelper().db;
      final solicitudActualizada = await isar.solicituds.get(widget.solicitud.id);
      
      if (solicitudActualizada != null) {
        solicitudActualizada.comuna.value = _selectedComuna;
        solicitudActualizada.consejoComunal.value = _selectedConsejoComunal;
        solicitudActualizada.comunidad = _comunidadController.text.trim();
        solicitudActualizada.ubch.value = _selectedUbch;
        solicitudActualizada.creador.value = _selectedCreador;
        solicitudActualizada.tipoSolicitud = _selectedTipoSolicitud;
        solicitudActualizada.descripcion = _descripcionController.text.trim();
        
        if (_selectedTipoSolicitud == TipoSolicitud.Iluminacion) {
          solicitudActualizada.cantidadLamparas = int.tryParse(_cantidadLamparasController.text.trim());
          solicitudActualizada.cantidadBombillos = int.tryParse(_cantidadBombillosController.text.trim());
        } else {
          solicitudActualizada.cantidadLamparas = null;
          solicitudActualizada.cantidadBombillos = null;
        }
        
        await _solicitudRepo.actualizarSolicitud(solicitudActualizada);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ Solicitud actualizada con éxito"),
              backgroundColor: AppColors.success,
            ),
          );
          setState(() {
            _isEditing = false;
            _isSaving = false;
          });
          _cargarDatosCompletos();
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
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _eliminarSolicitud() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Eliminación"),
        content: const Text("¿Está seguro de que desea eliminar esta solicitud?"),
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
        await _solicitudRepo.eliminarSolicitud(widget.solicitud.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("✅ Solicitud eliminada"),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Perfil de la Solicitud")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final s = _solicitudCompleto ?? widget.solicitud;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Perfil de la Solicitud"),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: "Editar",
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _isEditing = false);
                _cargarDatosCompletos();
              },
              tooltip: "Cancelar",
            ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _eliminarSolicitud,
              tooltip: "Eliminar",
            ),
        ],
      ),
      body: _isEditing ? _buildEditView() : _buildProfileView(s),
    );
  }

  Widget _buildProfileView(Solicitud s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(s),
          const SizedBox(height: 24),
          _buildSection(
            context,
            title: "Información General",
            icon: Icons.info,
            children: [
              _buildInfoRow("Tipo de Solicitud", _getTipoSolicitudText(s.tipoSolicitud)),
              _buildInfoRow("Descripción", s.descripcion),
              if (s.cantidadLamparas != null || s.cantidadBombillos != null) ...[
                if (s.cantidadLamparas != null)
                  _buildInfoRow("Cantidad de Lámparas", s.cantidadLamparas.toString()),
                if (s.cantidadBombillos != null)
                  _buildInfoRow("Cantidad de Bombillos", s.cantidadBombillos.toString()),
                if (s.cantidadLamparas != null || s.cantidadBombillos != null)
                  _buildInfoRow("Total de Luminarias", ((s.cantidadLamparas ?? 0) + (s.cantidadBombillos ?? 0)).toString()),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: "Ubicación",
            icon: Icons.location_on,
            children: [
              if (s.comuna.value != null)
                _buildInfoRow("Comuna", s.comuna.value!.nombreComuna),
              if (s.consejoComunal.value != null)
                _buildInfoRow("Consejo Comunal", s.consejoComunal.value!.nombreConsejo),
              _buildInfoRow("Comunidad", s.comunidad),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: "Organización",
            icon: Icons.business,
            children: [
              if (s.ubch.value != null)
                _buildInfoRow("UBCH", s.ubch.value!.nombreLargo),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: "Creador",
            icon: Icons.person,
            children: [
              if (s.creador.value != null)
                _buildInfoRow("Nombre", s.creador.value!.nombreCompleto)
              else
                _buildInfoRow("Creador", "No asignado", valueColor: AppColors.textTertiary),
              if (s.creador.value != null)
                _buildInfoRow(
                  "Cédula",
                  "${s.creador.value!.nacionalidad.toString().split('.').last}-${s.creador.value!.cedula}",
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: "Estado",
            icon: Icons.cloud,
            children: [
              _buildInfoRow(
                "Sincronización",
                s.isSynced ? "Sincronizado" : "Pendiente",
                valueColor: s.isSynced ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditView() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<TipoSolicitud>(
              value: _selectedTipoSolicitud,
              decoration: const InputDecoration(
                labelText: "Tipo de Solicitud *",
                border: OutlineInputBorder(),
              ),
              items: TipoSolicitud.values.map((tipo) {
                return DropdownMenuItem(
                  value: tipo,
                  child: Text(tipo.toString().split('.').last),
                );
              }).toList(),
              onChanged: (tipo) {
                setState(() => _selectedTipoSolicitud = tipo!);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Comuna>(
              value: _selectedComuna,
              decoration: const InputDecoration(
                labelText: "Comuna",
                border: OutlineInputBorder(),
              ),
              items: _comunas.map((comuna) {
                return DropdownMenuItem(
                  value: comuna,
                  child: Text(comuna.nombreComuna),
                );
              }).toList(),
              onChanged: _onComunaChanged,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ConsejoComunal>(
              value: _getConsejoComunalFromList(_selectedConsejoComunal),
              decoration: const InputDecoration(
                labelText: "Consejo Comunal",
                border: OutlineInputBorder(),
              ),
              items: _consejosComunales.map((consejo) {
                return DropdownMenuItem(
                  value: consejo,
                  child: Text(consejo.nombreConsejo),
                );
              }).toList(),
              onChanged: _selectedComuna != null
                  ? (consejo) {
                      setState(() => _selectedConsejoComunal = consejo);
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _comunidadController,
              decoration: const InputDecoration(
                labelText: "Comunidad *",
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? "Requerido" : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Organizacion>(
              value: _selectedUbch,
              decoration: const InputDecoration(
                labelText: "UBCH",
                border: OutlineInputBorder(),
              ),
              items: _ubchs.map((ubch) {
                return DropdownMenuItem(
                  value: ubch,
                  child: Text(ubch.nombreLargo),
                );
              }).toList(),
              onChanged: (ubch) {
                setState(() => _selectedUbch = ubch);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cedulaCreadorController,
                    decoration: const InputDecoration(
                      labelText: "Cédula del Creador *",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final cedula = int.tryParse(_cedulaCreadorController.text.trim());
                    if (cedula != null) {
                      final habitante = await _habitanteRepo.getHabitanteByCedula(cedula);
                      setState(() {
                        _selectedCreador = habitante;
                        if (habitante == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text("Habitante no encontrado"),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.search),
                  label: const Text("Buscar"),
                ),
              ],
            ),
            if (_selectedCreador != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Nombre: ${_selectedCreador!.nombreCompleto}",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 16),
            if (_selectedTipoSolicitud == TipoSolicitud.Iluminacion)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cantidadLamparasController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Cantidad de Lámparas",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cantidadBombillosController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Cantidad de Bombillos",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descripcionController,
              decoration: const InputDecoration(
                labelText: "Descripción *",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) => value?.isEmpty ?? true ? "Requerido" : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _guardarCambios,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
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
    );
  }

  Widget _buildHeader(Solicitud s) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.shadowMedium,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            child: Icon(
              _getIconForTipoSolicitud(s.tipoSolicitud),
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTipoSolicitudText(s.tipoSolicitud),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.descripcion.length > 40 ? "${s.descripcion.substring(0, 40)}..." : s.descripcion,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForTipoSolicitud(TipoSolicitud tipo) {
    switch (tipo) {
      case TipoSolicitud.Agua:
        return Icons.water_drop_rounded;
      case TipoSolicitud.Electrico:
        return Icons.power_rounded;
      case TipoSolicitud.Iluminacion:
        return Icons.lightbulb_rounded;
      case TipoSolicitud.Otros:
        return Icons.category_rounded;
    }
  }

  String _getTipoSolicitudText(TipoSolicitud tipo) {
    switch (tipo) {
      case TipoSolicitud.Agua:
        return "Agua";
      case TipoSolicitud.Electrico:
        return "Eléctrico";
      case TipoSolicitud.Iluminacion:
        return "Plan García de Hevia Iluminada 2026";
      case TipoSolicitud.Otros:
        return "Otros";
    }
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryUltraLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// Busca el consejo comunal en la lista y devuelve la instancia exacta de la lista
  ConsejoComunal? _getConsejoComunalFromList(ConsejoComunal? consejo) {
    if (consejo == null || _consejosComunales.isEmpty) return null;
    try {
      return _consejosComunales.firstWhere(
        (c) => c.id == consejo.id,
      );
    } catch (e) {
      return null;
    }
  }
}
