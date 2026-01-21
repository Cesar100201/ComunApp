import 'package:flutter/material.dart';
import 'package:goblafria/models/models.dart';
import 'package:goblafria/core/theme/app_theme.dart';
import 'package:goblafria/features/solicitudes/data/repositories/solicitud_repository.dart';
import 'package:goblafria/features/comunas/data/repositories/comuna_repository.dart';
import 'package:goblafria/features/organizaciones/data/repositories/organizacion_repository.dart';
import 'package:goblafria/features/inhabitants/data/repositories/habitante_repository.dart';
import 'package:goblafria/database/db_helper.dart';

class AddSolicitudPage extends StatefulWidget {
  const AddSolicitudPage({super.key});

  @override
  State<AddSolicitudPage> createState() => _AddSolicitudPageState();
}

class _AddSolicitudPageState extends State<AddSolicitudPage> {
  final _formKey = GlobalKey<FormState>();
  late final SolicitudRepository _solicitudRepo;
  late final ComunaRepository _comunaRepo;
  late final OrganizacionRepository _organizacionRepo;
  late final HabitanteRepository _habitanteRepo;

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

  bool _isSaving = false;

  List<Comuna> _comunas = [];
  List<ConsejoComunal> _consejosComunales = [];
  List<Organizacion> _ubchs = [];

  @override
  void initState() {
    super.initState();
    _initializeRepositoriesAndLoadData();
  }

  Future<void> _initializeRepositoriesAndLoadData() async {
    final isar = await DbHelper().db;
    _solicitudRepo = SolicitudRepository(isar);
    _comunaRepo = ComunaRepository(isar);
    _organizacionRepo = OrganizacionRepository(isar);
    _habitanteRepo = HabitanteRepository(isar);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _comunas = await _comunaRepo.getAllComunas();
    _ubchs = await _organizacionRepo.getOrganizacionesByType(TipoOrganizacion.Politico);
    if (mounted) setState(() {});
  }

  void _onComunaChanged(Comuna? newComuna) async {
    if (!mounted) return;
    setState(() {
      _selectedComuna = newComuna;
      _selectedConsejoComunal = null; // Resetear consejo comunal al cambiar comuna
      _consejosComunales = []; // Limpiar lista de consejos
    });
    if (newComuna != null) {
      _consejosComunales = await _comunaRepo.getConsejosComunalesByComunaId(newComuna.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _guardar() async {
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
      final solicitud = Solicitud()
        ..idSolicitud = 0 // Se asignará automáticamente por Isar si es autoIncrement
        ..comuna.value = _selectedComuna
        ..consejoComunal.value = _selectedConsejoComunal
        ..comunidad = _comunidadController.text.trim()
        ..ubch.value = _selectedUbch
        ..creador.value = _selectedCreador
        ..tipoSolicitud = _selectedTipoSolicitud
        ..otrosTipoSolicitud = null // Inicializar el campo
        ..descripcion = _descripcionController.text.trim();

      if (_selectedTipoSolicitud == TipoSolicitud.Iluminacion) {
        // Parsear valores de los campos de texto y guardarlos por separado
        final lamparasText = _cantidadLamparasController.text.trim();
        final bombillosText = _cantidadBombillosController.text.trim();
        
        // Guardar lámparas y bombillos por separado en la base de datos
        // Si el campo está vacío, se guarda como null
        // Si tiene texto pero no es un número válido, se guarda como null (no como 0)
        solicitud.cantidadLamparas = lamparasText.isEmpty 
            ? null 
            : int.tryParse(lamparasText);
        solicitud.cantidadBombillos = bombillosText.isEmpty 
            ? null 
            : int.tryParse(bombillosText);
      }

      await _solicitudRepo.guardarSolicitud(solicitud);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("✅ Solicitud registrada con éxito"),
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
  void dispose() {
    _comunidadController.dispose();
    _descripcionController.dispose();
    _cedulaCreadorController.dispose();
    _cantidadLamparasController.dispose();
    _cantidadBombillosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan García de Hevia Iluminada 2026')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Datos de la Solicitud",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 24),
              // Dropdown para Comuna
              _buildDropdown<Comuna>(
                "Comuna",
                Icons.location_city,
                _comunas,
                _selectedComuna,
                _onComunaChanged,
                (comuna) => comuna.nombreComuna, // Mostrar nombre de comuna
              ),
              const SizedBox(height: 16),
              // Dropdown para Consejo Comunal (dependiente de Comuna)
              _buildDropdown<ConsejoComunal>(
                "Consejo Comunal",
                Icons.groups,
                _consejosComunales,
                _selectedConsejoComunal,
                (newValue) {
                  setState(() {
                    _selectedConsejoComunal = newValue;
                  });
                },
                (consejo) => consejo.nombreConsejo, // Mostrar nombre de consejo comunal
                isEnabled: _selectedComuna != null, // Habilitar si hay comuna seleccionada
              ),
              const SizedBox(height: 16),
              _buildInput("Comunidad", Icons.place, _comunidadController),
              const SizedBox(height: 16),
              // Dropdown para UBCH
              _buildDropdown<Organizacion>(
                "UBCH",
                Icons.shield,
                _ubchs,
                _selectedUbch,
                (newValue) {
                  setState(() {
                    _selectedUbch = newValue;
                  });
                },
                (organizacion) => organizacion.nombreLargo, // Mostrar nombre de UBCH
              ),
              const SizedBox(height: 16),
              Text(
                "Creado por",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInput("Cédula", Icons.person, _cedulaCreadorController, keyboardType: TextInputType.number),
                  ),
                  const SizedBox(width: 12),
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
              // Campos condicionales para "Cantidad de Luminarias"
              if (_selectedTipoSolicitud == TipoSolicitud.Iluminacion) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildInput("Cantidad de Lámparas", Icons.lightbulb, _cantidadLamparasController, keyboardType: TextInputType.number, required: false),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInput("Cantidad de Bombillos", Icons.lightbulb_outline, _cantidadBombillosController, keyboardType: TextInputType.number, required: false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              _buildInput("Descripción", Icons.description, _descripcionController, maxLines: 3),
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
                      : const Text("GUARDAR SOLICITUD DE LUMINARIAS"),
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
    bool isReadOnly = false,
    int? maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: isReadOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: required
          ? (value) => value == null || value.isEmpty ? "Campo requerido" : null
          : null,
    );
  }

  Widget _buildDropdown<T>(
    String label,
    IconData icon,
    List<T> items,
    T? selectedValue,
    void Function(T?) onChanged,
    String Function(T) itemToString, {
    bool isEnabled = true,
  }) {
    return DropdownButtonFormField<T>(
      value: selectedValue,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      selectedItemBuilder: (BuildContext context) {
        return items.map<Widget>((T value) {
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              itemToString(value),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          );
        }).toList();
      },
      items: items.map((T value) {
        return DropdownMenuItem<T>(
          value: value,
          child: Text(
            itemToString(value),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }).toList(),
      onChanged: isEnabled ? onChanged : null,
      validator: (value) => value == null ? "Campo requerido" : null,
      isExpanded: true, // Permite que el dropdown use todo el ancho disponible
    );
  }
}