import 'dart:io';
import 'package:flutter/material.dart';
import 'package:goblafria/models/models.dart';
import 'package:goblafria/core/theme/app_theme.dart';
import 'package:goblafria/database/db_helper.dart';
import 'package:goblafria/features/reportes/data/repositories/reporte_repository.dart';
import 'package:goblafria/features/organizations/data/repositories/organizacion_repository.dart';
import 'package:image_picker/image_picker.dart';

class GenerarReportePage extends StatefulWidget {
  final Solicitud solicitud;

  const GenerarReportePage({
    super.key,
    required this.solicitud,
  });

  @override
  State<GenerarReportePage> createState() => _GenerarReportePageState();
}

class _GenerarReportePageState extends State<GenerarReportePage> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();
  final _luminariasController = TextEditingController();

  EstatusReporte _estatusReporte = EstatusReporte.Completo;
  final List<String> _fotosUrls = [];
  List<Organizacion> _organizacionesSeleccionadas = [];
  List<Organizacion> _todasOrganizaciones = [];
  
  bool _isLoading = true;
  bool _isSaving = false;
  
  late ReporteRepository _reporteRepo;
  late OrganizacionRepository _organizacionRepo;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _inicializarRepositorios();
  }

  Future<void> _inicializarRepositorios() async {
    final isar = await DbHelper().db;
    _reporteRepo = ReporteRepository(isar);
    _organizacionRepo = OrganizacionRepository();
    
    await _cargarOrganizaciones();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarOrganizaciones() async {
    _todasOrganizaciones = await _organizacionRepo.obtenerTodas();
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _luminariasController.dispose();
    super.dispose();
  }

  Future<void> _tomarFotoConCamara() async {
    if (_fotosUrls.length >= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Máximo 3 fotos permitidas"),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _fotosUrls.add(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al tomar foto: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _seleccionarFotoDeGaleria() async {
    if (_fotosUrls.length >= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Máximo 3 fotos permitidas"),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _fotosUrls.add(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al seleccionar foto: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _eliminarFoto(int index) {
    setState(() {
      _fotosUrls.removeAt(index);
    });
  }

  Future<void> _mostrarDialogoOrganizaciones() async {
    final seleccionadas = await showDialog<List<Organizacion>>(
      context: context,
      builder: (context) => _DialogoSeleccionOrganizaciones(
        organizaciones: _todasOrganizaciones,
        seleccionadas: _organizacionesSeleccionadas,
      ),
    );

    if (seleccionadas != null) {
      setState(() {
        _organizacionesSeleccionadas = seleccionadas;
      });
    }
  }

  Future<void> _guardarReporte() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fotosUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Debe agregar al menos una foto"),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // TODO: Obtener el usuario actual del sistema (por ahora usamos el creador de la solicitud)
      final creador = widget.solicitud.creador.value;

      final nuevoReporte = Reporte()
        ..fechaReporte = DateTime.now()
        ..estatusReporte = _estatusReporte
        ..descripcion = _descripcionController.text.trim()
        ..fotosUrls = _fotosUrls
        ..luminariasEntregadas = _luminariasController.text.trim().isNotEmpty
            ? int.tryParse(_luminariasController.text.trim())
            : null;

      nuevoReporte.solicitud.value = widget.solicitud;
      nuevoReporte.creador.value = creador;

      // Agregar organizaciones vinculadas
      for (var org in _organizacionesSeleccionadas) {
        nuevoReporte.organizacionesVinculadas.add(org);
      }

      await _reporteRepo.guardarReporte(nuevoReporte);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("✅ Reporte creado con éxito"),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al guardar reporte: $e"),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Generar Reporte")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Generar Reporte"),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con info de la solicitud
              _buildSolicitudHeader(),
              const SizedBox(height: 24),

              // Estatus del Reporte
              _buildSectionTitle("Estatus de la Solución"),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    RadioListTile<EstatusReporte>(
                      title: const Text("Completado"),
                      subtitle: const Text("La solicitud fue resuelta completamente"),
                      value: EstatusReporte.Completo,
                      groupValue: _estatusReporte,
                      onChanged: (value) {
                        setState(() => _estatusReporte = value!);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<EstatusReporte>(
                      title: const Text("Parcial"),
                      subtitle: const Text("La solicitud fue resuelta parcialmente"),
                      value: EstatusReporte.Parcial,
                      groupValue: _estatusReporte,
                      onChanged: (value) {
                        setState(() => _estatusReporte = value!);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Luminarias Entregadas
              if (widget.solicitud.tipoSolicitud == TipoSolicitud.Iluminacion) ...[
                _buildSectionTitle("Luminarias Entregadas"),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _luminariasController,
                  decoration: InputDecoration(
                    labelText: "Cantidad de luminarias entregadas *",
                    hintText: "Ej: 10",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lightbulb_outline),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Requerido";
                    }
                    final numero = int.tryParse(value.trim());
                    if (numero == null || numero < 0) {
                      return "Ingrese un número válido";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Organizaciones Vinculadas
              _buildSectionTitle("Organizaciones Vinculadas"),
              const SizedBox(height: 12),
              Card(
                child: InkWell(
                  onTap: _mostrarDialogoOrganizaciones,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.business, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Organizaciones participantes",
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _organizacionesSeleccionadas.isEmpty
                                    ? "Seleccionar organizaciones"
                                    : "${_organizacionesSeleccionadas.length} organizacion(es) seleccionada(s)",
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              if (_organizacionesSeleccionadas.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _organizacionesSeleccionadas.map((org) {
                    return Chip(
                      label: Text(org.nombreLargo),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        setState(() {
                          _organizacionesSeleccionadas.remove(org);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),

              // Reporte Fotográfico
              _buildSectionTitle("Reporte Fotográfico (1-3 fotos) *"),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _tomarFotoConCamara,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Tomar Foto"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _seleccionarFotoDeGaleria,
                      icon: const Icon(Icons.photo_library),
                      label: const Text("Galería"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_fotosUrls.isEmpty)
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.primaryUltraLight,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate,
                            size: 40, color: AppColors.textTertiary),
                        const SizedBox(height: 8),
                        Text(
                          "No hay fotos agregadas",
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _fotosUrls.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(_fotosUrls[index]),
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close,
                                      size: 16, color: Colors.white),
                                  onPressed: () => _eliminarFoto(index),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),

              // Descripción
              _buildSectionTitle("Descripción Detallada *"),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcionController,
                decoration: InputDecoration(
                  labelText: "Descripción",
                  hintText: "Describa lo que se hizo y lo que no se pudo completar",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "La descripción es requerida";
                  }
                  if (value.trim().length < 10) {
                    return "La descripción debe tener al menos 10 caracteres";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Botón Guardar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _guardarReporte,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          "GUARDAR REPORTE",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSolicitudHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _getIconForTipoSolicitud(widget.solicitud.tipoSolicitud),
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Solicitud",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getTipoSolicitudText(widget.solicitud.tipoSolicitud),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.solicitud.comunidad.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.solicitud.comunidad,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
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
}

// Diálogo para seleccionar organizaciones
class _DialogoSeleccionOrganizaciones extends StatefulWidget {
  final List<Organizacion> organizaciones;
  final List<Organizacion> seleccionadas;

  const _DialogoSeleccionOrganizaciones({
    required this.organizaciones,
    required this.seleccionadas,
  });

  @override
  State<_DialogoSeleccionOrganizaciones> createState() =>
      _DialogoSeleccionOrganizacionesState();
}

class _DialogoSeleccionOrganizacionesState
    extends State<_DialogoSeleccionOrganizaciones> {
  late List<Organizacion> _seleccionadas;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _seleccionadas = List.from(widget.seleccionadas);
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = widget.organizaciones.where((org) {
      return org.nombreLargo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (org.abreviacion?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Seleccionar Organizaciones",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Buscar organizaciones...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtradas.isEmpty
                  ? Center(
                      child: Text(
                        "No se encontraron organizaciones",
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtradas.length,
                      itemBuilder: (context, index) {
                        final org = filtradas[index];
                        final isSelected = _seleccionadas.any((o) => o.id == org.id);
                        
                        return CheckboxListTile(
                          title: Text(org.nombreLargo),
                          subtitle: org.abreviacion != null
                              ? Text(org.abreviacion!)
                              : null,
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _seleccionadas.add(org);
                              } else {
                                _seleccionadas.removeWhere((o) => o.id == org.id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("CANCELAR"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, _seleccionadas),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text("SELECCIONAR (${_seleccionadas.length})"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
