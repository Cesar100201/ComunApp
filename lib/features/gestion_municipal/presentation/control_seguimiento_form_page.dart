import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:goblafria/core/theme/app_theme.dart';
import 'package:goblafria/core/services/settings_service.dart';
import '../data/categorias_control_seguimiento.dart';
import '../data/control_seguimiento_model.dart';
import '../data/repositories/control_seguimiento_repository.dart';
import 'package:intl/intl.dart';

/// Opciones de estatus.
const List<String> _opcionesEstatus = ['En proceso', 'Culminado'];

/// Plan de la Patria 2025 - 2030. Formato: nT - Nombre.
const List<String> _opciones7T = [
  '1T - Económica',
  '2T - Servicios y obras públicas',
  '3T - Seguridad y paz',
  '4T - Social',
  '5T - Política',
  '6T - Ecológica',
  '7T - Geopolítica',
];

/// Plan de Gobierno Municipal 2025-2029.
const List<String> _opcionesPlanGobierno = [
  '1T - Economía Fuerte',
  '2T - Servicios de Calidad',
  '3T - Un Territorio Seguro',
  '4T - Protección Social',
  '5T - El Pueblo Gobierna',
  '6T - Cuidado del Entorno Ambiental',
  '7T - Integración Binacional',
];

/// Formulario para registrar o editar un Control y Seguimiento.
class ControlSeguimientoFormPage extends StatefulWidget {
  const ControlSeguimientoFormPage({super.key, this.registroToEdit});

  /// Si se pasa, el formulario abre en modo edición.
  final ControlSeguimiento? registroToEdit;

  @override
  State<ControlSeguimientoFormPage> createState() => _ControlSeguimientoFormPageState();
}

class _ControlSeguimientoFormPageState extends State<ControlSeguimientoFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ControlSeguimientoRepository _repo = ControlSeguimientoRepository();

  String? _categoriaSeleccionada;
  final _nombreActividadController = TextEditingController();
  final _objetivoController = TextEditingController();
  final _accionesController = TextEditingController();
  final _productoController = TextEditingController();
  final Set<String> _transformacion7TSeleccionadas = {};
  final Set<String> _planGobiernoSeleccionadas = {};
  String? _estatusSeleccionado;

  DateTime _fecha = DateTime.now();
  bool _isSaving = false;

  bool get _isEditing => widget.registroToEdit != null;

  @override
  void initState() {
    super.initState();
    if (widget.registroToEdit != null) {
      final r = widget.registroToEdit!;
      _categoriaSeleccionada = r.categoria;
      _nombreActividadController.text = r.nombreActividad;
      _objetivoController.text = r.objetivo;
      _accionesController.text = r.acciones;
      _productoController.text = r.producto;
      _estatusSeleccionado = r.estatus;
      _fecha = r.fecha;
      if (r.transformacion7T.isNotEmpty) {
        for (final t in r.transformacion7T.split('; ')) {
          final trimmed = t.trim();
          if (trimmed.isNotEmpty) _transformacion7TSeleccionadas.add(trimmed);
        }
      }
      if (r.planGobierno2025.isNotEmpty) {
        for (final t in r.planGobierno2025.split('; ')) {
          final trimmed = t.trim();
          if (trimmed.isNotEmpty) _planGobiernoSeleccionadas.add(trimmed);
        }
      }
    }
  }

  @override
  void dispose() {
    _nombreActividadController.dispose();
    _objetivoController.dispose();
    _accionesController.dispose();
    _productoController.dispose();
    super.dispose();
  }

  String _buildTransformacion7TString() {
    return _transformacion7TSeleccionadas.toList().join('; ');
  }

  String _buildPlanGobiernoString() {
    return _planGobiernoSeleccionadas.toList().join('; ');
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _fecha = picked);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Cédula del perfil vinculado a la cuenta (quien hace la carga), variable oculta
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final cedulaCreador = uid != null ? await SettingsService.getLinkedHabitanteCedula(uid) : null;

      // Rango de la semana (domingo a sábado) a la que pertenece la fecha seleccionada, variable oculta
      final (semanaInicio, semanaFin) = ControlSeguimiento.rangoSemanaPara(_fecha);

      final id = _isEditing ? widget.registroToEdit!.id : 0;
      final mediosVerificacion = _isEditing ? widget.registroToEdit!.mediosVerificacion : '';
      final fotosExistentes = _isEditing ? List<String>.from(widget.registroToEdit!.mediosVerificacionFotos) : <String>[];
      final pdfsExistentes = _isEditing ? List<String>.from(widget.registroToEdit!.mediosVerificacionPdfs) : <String>[];
      final memoriaFotografica = _isEditing ? List<String>.from(widget.registroToEdit!.memoriaFotografica) : <String>[];
      final listasAsistenciaFotos = _isEditing ? List<String>.from(widget.registroToEdit!.listasAsistenciaFotos) : <String>[];
      final listasAsistenciaPdfs = _isEditing ? List<String>.from(widget.registroToEdit!.listasAsistenciaPdfs) : <String>[];
      final actasPdfs = _isEditing ? List<String>.from(widget.registroToEdit!.actasPdfs) : <String>[];

      final registro = ControlSeguimiento(
        id: id,
        categoria: _categoriaSeleccionada!,
        fecha: _fecha,
        nombreActividad: _nombreActividadController.text.trim(),
        objetivo: _objetivoController.text.trim(),
        acciones: _accionesController.text.trim(),
        mediosVerificacion: mediosVerificacion,
        mediosVerificacionFotos: fotosExistentes,
        mediosVerificacionPdfs: pdfsExistentes,
        memoriaFotografica: memoriaFotografica,
        listasAsistenciaFotos: listasAsistenciaFotos,
        listasAsistenciaPdfs: listasAsistenciaPdfs,
        actasPdfs: actasPdfs,
        producto: _productoController.text.trim(),
        estatus: _estatusSeleccionado ?? '',
        transformacion7T: _buildTransformacion7TString(),
        planGobierno2025: _buildPlanGobiernoString(),
        cedulaCreador: _isEditing ? widget.registroToEdit!.cedulaCreador : cedulaCreador,
        semanaInicio: semanaInicio,
        semanaFin: semanaFin,
      );

      await _repo.save(registro);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registro guardado correctamente"),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
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
        title: Text(_isEditing ? "Editar actividad" : "Control y Seguimiento - Nuevo registro"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Datos del registro",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 20),
              _buildCategoriaDropdown(),
              const SizedBox(height: 16),
              _buildDateField(),
              const SizedBox(height: 16),
              _buildInput("Nombre de la actividad", Icons.label_rounded, _nombreActividadController, required: false),
              const SizedBox(height: 16),
              _buildInput("Objetivo", Icons.flag_rounded, _objetivoController, maxLines: 3),
              const SizedBox(height: 16),
              _buildInput("Acciones", Icons.checklist_rounded, _accionesController, maxLines: 3),
              const SizedBox(height: 16),
              _buildTransformacion7TChecklist(),
              const SizedBox(height: 16),
              _buildPlanGobiernoChecklist(),
              const SizedBox(height: 16),
              _buildInput("Producto", Icons.inventory_2_rounded, _productoController),
              const SizedBox(height: 16),
              _buildEstatusDropdown(),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _guardar,
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("Guardar registro"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriaDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _categoriaSeleccionada,
      decoration: InputDecoration(
        labelText: "Categoría",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      hint: const Text("Seleccione una categoría"),
      isExpanded: true,
      selectedItemBuilder: (BuildContext context) {
        return opcionesCategoriaControlSeguimiento.map<Widget>((String value) {
          return Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }).toList();
      },
      items: opcionesCategoriaControlSeguimiento
          .map((String value) => DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              ))
          .toList(),
      onChanged: (String? value) {
        setState(() => _categoriaSeleccionada = value);
      },
      validator: (value) => value == null || value.isEmpty ? "Seleccione una categoría" : null,
    );
  }

  Widget _buildTransformacion7TChecklist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.transform_rounded, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                "Plan de la Patria 2025 - 2030",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
        ..._opciones7T.map((op) => CheckboxListTile(
              value: _transformacion7TSeleccionadas.contains(op),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _transformacion7TSeleccionadas.add(op);
                  } else {
                    _transformacion7TSeleccionadas.remove(op);
                  }
                });
              },
              title: Text(op, style: const TextStyle(fontSize: 14)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            )),
      ],
    );
  }

  Widget _buildPlanGobiernoChecklist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.account_balance_rounded, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                "Plan de Gobierno 2025 - 2029",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
        ..._opcionesPlanGobierno.map((op) => CheckboxListTile(
              value: _planGobiernoSeleccionadas.contains(op),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _planGobiernoSeleccionadas.add(op);
                  } else {
                    _planGobiernoSeleccionadas.remove(op);
                  }
                });
              },
              title: Text(op, style: const TextStyle(fontSize: 14)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            )),
      ],
    );
  }

  Widget _buildEstatusDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _estatusSeleccionado,
      decoration: InputDecoration(
        labelText: "Estatus",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      hint: const Text("Seleccione el estatus"),
      isExpanded: true,
      selectedItemBuilder: (BuildContext context) {
        return _opcionesEstatus.map<Widget>((String value) {
          return Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }).toList();
      },
      items: _opcionesEstatus
          .map((String value) => DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              ))
          .toList(),
      onChanged: (String? value) {
        setState(() => _estatusSeleccionado = value);
      },
      validator: (value) => value == null || value.isEmpty ? "Seleccione el estatus" : null,
    );
  }

  Widget _buildInput(
    String label,
    IconData icon,
    TextEditingController controller, {
    int maxLines = 1,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: required ? (value) => value == null || value.trim().isEmpty ? "Campo requerido" : null : null,
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: "Fecha",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 24, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                DateFormat('dd/MM/yyyy').format(_fecha),
                style: Theme.of(context).textTheme.bodyLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
