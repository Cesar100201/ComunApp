import 'dart:io';
import 'package:flutter/material.dart';
import 'package:goblafria/core/theme/app_theme.dart';
import '../data/control_seguimiento_model.dart';
import '../data/medios_verificacion_service.dart';
import '../data/repositories/control_seguimiento_repository.dart';
import 'control_seguimiento_form_page.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';

/// Reporte detallado de una actividad de Control y Seguimiento (ej. asesoría).
class ControlSeguimientoReportPage extends StatefulWidget {
  const ControlSeguimientoReportPage({
    super.key,
    required this.registro,
    this.nombreCreador,
  });

  final ControlSeguimiento registro;
  final String? nombreCreador;

  @override
  State<ControlSeguimientoReportPage> createState() =>
      _ControlSeguimientoReportPageState();
}

class _ControlSeguimientoReportPageState
    extends State<ControlSeguimientoReportPage> {
  late ControlSeguimiento _registro;
  final ControlSeguimientoRepository _repo = ControlSeguimientoRepository();
  final MediosVerificacionService _mediosService = MediosVerificacionService();

  @override
  void initState() {
    super.initState();
    _registro = widget.registro;
  }

  Future<void> _persistRegistro() async {
    await _repo.save(_registro);
  }

  Future<void> _openEdit() async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ControlSeguimientoFormPage(registroToEdit: _registro),
      ),
    );
    if (guardado == true && mounted) {
      final actualizado = await ControlSeguimientoRepository().getById(
        _registro.id,
      );
      if (actualizado != null) {
        setState(() => _registro = actualizado);
      }
    }
  }

  Future<void> _openMediosSheet() async {
    if (_registro.id == 0) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _MediosVerificacionSheet(
        registro: _registro,
        mediosService: _mediosService,
        onAdded: () async {
          setState(() {});
          await _persistRegistro();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const accent = AppModulePastel.gestionMunicipalAccent;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reporte de actividad"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: "Editar actividad",
            onPressed: _registro.id != 0 ? _openEdit : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(context, colorScheme, accent),
            _buildSection(
              context,
              "Objetivo",
              Icons.flag_rounded,
              _registro.objetivo.isNotEmpty ? _registro.objetivo : "—",
            ),
            _buildSection(
              context,
              "Acciones realizadas",
              Icons.checklist_rounded,
              _registro.acciones.isNotEmpty ? _registro.acciones : "—",
            ),
            if (_registro.transformacion7T.isNotEmpty)
              _buildSection(
                context,
                "Plan de la Patria 2025 - 2030",
                Icons.layers_rounded,
                _registro.transformacion7T.replaceAll('; ', '\n'),
              ),
            if (_registro.planGobierno2025.isNotEmpty)
              _buildSection(
                context,
                "Plan de Gobierno 2025 - 2029",
                Icons.account_balance_rounded,
                _registro.planGobierno2025.replaceAll('; ', '\n'),
              ),
            _buildSection(
              context,
              "Producto",
              Icons.inventory_2_outlined,
              _registro.producto.isNotEmpty ? _registro.producto : "—",
            ),
            _buildMediosCard(context),
            const SizedBox(height: 24),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Registrado por: ${widget.nombreCreador ?? (_registro.cedulaCreador != null ? "Cédula ${_registro.cedulaCreador}" : "Sin vincular")}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    ColorScheme colorScheme,
    Color accent,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _registro.categoria,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _registro.estatus == 'Culminado'
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _registro.estatus,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _registro.estatus == 'Culminado'
                          ? AppColors.success
                          : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              DateFormat('dd/MM/yyyy').format(_registro.fecha),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_registro.nombreActividad.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _registro.nombreActividad,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_registro.semanaInicio != null &&
                _registro.semanaFin != null) ...[
              const SizedBox(height: 4),
              Text(
                "Semana: ${DateFormat('dd/MM').format(_registro.semanaInicio!)} - ${DateFormat('dd/MM/yyyy').format(_registro.semanaFin!)}",
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediosCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const accent = AppModulePastel.gestionMunicipal;
    final nMemoria = _registro.memoriaFotografica.length;
    final nListasF = _registro.listasAsistenciaFotos.length;
    final nListasP = _registro.listasAsistenciaPdfs.length;
    final nActas = _registro.actasPdfs.length;
    final summary = [
      if (nMemoria > 0) 'Memoria: $nMemoria',
      if (nListasF > 0 || nListasP > 0) 'Listas: ${nListasF + nListasP}',
      if (nActas > 0) 'Actas: $nActas',
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: _registro.id != 0 ? _openMediosSheet : null,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 20, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      "Medios de verificación",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_registro.id != 0) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.touch_app_rounded,
                        size: 16,
                        color: colorScheme.outline,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  summary.isEmpty
                      ? "Toca para cargar: memoria fotográfica, listas de asistencia, actas"
                      : summary,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    String content,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    const accent = AppModulePastel.gestionMunicipal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediosVerificacionSheet extends StatefulWidget {
  const _MediosVerificacionSheet({
    required this.registro,
    required this.mediosService,
    required this.onAdded,
  });

  final ControlSeguimiento registro;
  final MediosVerificacionService mediosService;
  final Future<void> Function() onAdded;

  @override
  State<_MediosVerificacionSheet> createState() =>
      _MediosVerificacionSheetState();
}

class _MediosVerificacionSheetState extends State<_MediosVerificacionSheet> {
  late ControlSeguimiento _registro;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _registro = widget.registro;
  }

  Future<void> _pickPhotos(CategoriaMedio category) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = category == CategoriaMedio.memoriaFotografica
          ? _registro.memoriaFotografica.toList()
          : _registro.listasAsistenciaFotos.toList();
      for (final f in result.files) {
        if (f.path == null) continue;
        final rel = await widget.mediosService.savePhoto(
          _registro.id,
          f.path!,
          category: category,
        );
        list.add(rel);
      }
      if (category == CategoriaMedio.memoriaFotografica) {
        _registro.memoriaFotografica = list;
      } else {
        _registro.listasAsistenciaFotos = list;
      }
      await widget.onAdded();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickPdfs(CategoriaMedio category) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = category == CategoriaMedio.actas
          ? _registro.actasPdfs.toList()
          : _registro.listasAsistenciaPdfs.toList();
      for (final f in result.files) {
        if (f.path == null) continue;
        final rel = await widget.mediosService.savePdf(
          _registro.id,
          f.path!,
          category: category,
        );
        list.add(rel);
      }
      if (category == CategoriaMedio.actas) {
        _registro.actasPdfs = list;
      } else {
        _registro.listasAsistenciaPdfs = list;
      }
      await widget.onAdded();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openPhoto(String relativePath, CategoriaMedio category) async {
    final path = await widget.mediosService.resolvePath(relativePath);
    if (!mounted) return;
    if (!File(path).existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Imagen no disponible en este dispositivo. Sincronice para descargar.',
            ),
          ),
        );
      }
      return;
    }
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (ctx) => _FotoViewerPage(
          path: path,
          onDelete: () async {
            if (category == CategoriaMedio.memoriaFotografica) {
              _registro.memoriaFotografica.remove(relativePath);
            } else {
              _registro.listasAsistenciaFotos.remove(relativePath);
            }
            await widget.onAdded();
          },
        ),
      ),
    );
    if (deleted == true && mounted) setState(() {});
  }

  Future<void> _openPdf(String relativePath) async {
    final path = await widget.mediosService.resolvePath(relativePath);
    await OpenFilex.open(path);
  }

  Widget _buildPhotoGrid(List<String> paths, CategoriaMedio category) {
    if (paths.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: paths.length,
      itemBuilder: (context, index) {
        final rel = paths[index];
        return FutureBuilder<String>(
          future: widget.mediosService.resolvePath(rel),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Card(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final path = snap.data!;
            final file = File(path);
            final exists = file.existsSync();
            return InkWell(
              onTap: () => _openPhoto(rel, category),
              borderRadius: BorderRadius.circular(8),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: exists
                    ? Image.file(file, fit: BoxFit.cover)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_download_rounded,
                              size: 32,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No descargada',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSeccionMemoriaFotografica(
    ColorScheme colorScheme,
    Color accent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_camera_rounded, size: 20, color: accent),
            const SizedBox(width: 8),
            Text(
              "Memoria fotográfica",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loading
              ? null
              : () => _pickPhotos(CategoriaMedio.memoriaFotografica),
          icon: const Icon(Icons.photo_library_rounded, size: 18),
          label: const Text("Cargar fotos (JPEG, PNG)"),
        ),
        const SizedBox(height: 8),
        _buildPhotoGrid(
          _registro.memoriaFotografica,
          CategoriaMedio.memoriaFotografica,
        ),
      ],
    );
  }

  Widget _buildSeccionListasAsistencia(ColorScheme colorScheme, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.list_alt_rounded, size: 20, color: accent),
            const SizedBox(width: 8),
            Text(
              "Listas de asistencia",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () => _pickPhotos(CategoriaMedio.listasAsistencia),
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              label: const Text("Cargar fotos"),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () => _pickPdfs(CategoriaMedio.listasAsistencia),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text("Cargar PDF"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildPhotoGrid(
          _registro.listasAsistenciaFotos,
          CategoriaMedio.listasAsistencia,
        ),
        if (_registro.listasAsistenciaPdfs.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._registro.listasAsistenciaPdfs.map((rel) {
            final name = rel.split(RegExp(r'[/\\]')).last;
            return ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.red,
                size: 22,
              ),
              title: Text(name, overflow: TextOverflow.ellipsis),
              onTap: () => _openPdf(rel),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSeccionActas(ColorScheme colorScheme, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description_rounded, size: 20, color: accent),
            const SizedBox(width: 8),
            Text(
              "Actas",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loading ? null : () => _pickPdfs(CategoriaMedio.actas),
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
          label: const Text("Cargar PDF"),
        ),
        const SizedBox(height: 8),
        if (_registro.actasPdfs.isNotEmpty)
          ..._registro.actasPdfs.map((rel) {
            final name = rel.split(RegExp(r'[/\\]')).last;
            return ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.red,
                size: 22,
              ),
              title: Text(name, overflow: TextOverflow.ellipsis),
              onTap: () => _openPdf(rel),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const accent = AppModulePastel.gestionMunicipal;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_rounded, size: 24, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    "Medios de verificación",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: colorScheme.error, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildSeccionMemoriaFotografica(colorScheme, accent),
                    const SizedBox(height: 20),
                    _buildSeccionListasAsistencia(colorScheme, accent),
                    const SizedBox(height: 20),
                    _buildSeccionActas(colorScheme, accent),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Visor de foto a pantalla completa con botón de eliminar.
class _FotoViewerPage extends StatelessWidget {
  const _FotoViewerPage({required this.path, required this.onDelete});

  final String path;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_rounded),
            tooltip: 'Eliminar foto',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Eliminar foto'),
                  content: const Text(
                    '¿Eliminar esta foto de los medios de verificación?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await onDelete();
                if (context.mounted) Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final file = File(path);
          if (!file.existsSync()) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Imagen no disponible en este dispositivo.\nSincronice para descargar.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return InteractiveViewer(
            child: Center(child: Image.file(file, fit: BoxFit.contain)),
          );
        },
      ),
    );
  }
}
