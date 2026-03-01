import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/notification_service.dart';
import '../data/services/bulk_upload_extranjeros_service.dart';

class BulkUploadExtranjerosPage extends StatefulWidget {
  const BulkUploadExtranjerosPage({super.key});

  @override
  State<BulkUploadExtranjerosPage> createState() =>
      _BulkUploadExtranjerosPageState();
}

class _BulkUploadExtranjerosPageState extends State<BulkUploadExtranjerosPage> {
  File? _selectedFile;
  bool _isProcessing = false;
  bool _puedeMinimizar = false;

  int _totalProcessed = 0;
  int _currentProgress = 0;
  String _etiquetaProgreso = '';

  BulkUploadResult? _resultado;

  Future<void> _descargarPlantillaExcel() async {
    try {
      if (!mounted) return;
      setState(() => _isProcessing = true);

      final excel = Excel.createExcel();
      final sheet = excel['Extranjeros'];

      final headers = [
        'Cedula Colombiana',
        'Nombre Completo',
        'Telefono',
        'Direccion',
        'Email',
        'Es Nacionalizado',
        'Cedula Venezolana',
        'Departamento',
        'Municipio',
        'Sisben',
      ];

      for (var i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = TextCellValue(
          headers[i],
        );
      }

      final datosEjemplo = [
        [
          '1002345678',
          'PABLO ESCOBAR GAVIRIA',
          '04121234567',
          'Barrio El Centro, Casa 15',
          'pablo.escobar@correo.com',
          'SI',
          '25123456',
          'Norte de Santander',
          'Cúcuta',
          'B4',
        ],
        [
          '1098765432',
          'CARMEN RAMÍREZ OVIEDO',
          '04241234567',
          'Sector La Paz',
          '',
          'NO',
          '',
          'Antioquia',
          'Medellín',
          'NO',
        ],
      ];

      for (var i = 0; i < datosEjemplo.length; i++) {
        for (var j = 0; j < datosEjemplo[i].length; j++) {
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1))
              .value = TextCellValue(
            datosEjemplo[i][j],
          );
        }
      }

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/plantilla_carga_masiva_extranjeros.xlsx';
      final file = File(path);
      final bytes = excel.save();

      if (bytes != null) {
        final uint8List = bytes is Uint8List
            ? bytes
            : Uint8List.fromList(bytes);
        await file.writeAsBytes(uint8List);

        if (mounted) {
          setState(() => _isProcessing = false);

          final result = await FilePicker.platform.saveFile(
            dialogTitle: 'Guardar plantilla Excel de Extranjeros',
            fileName: 'plantilla_carga_masiva_extranjeros.xlsx',
            bytes: uint8List,
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
          );

          if (result != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Plantilla guardada en: $result'),
                backgroundColor: AppColors.success,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Plantilla generada en: ${file.path}'),
                backgroundColor: AppColors.info,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar plantilla: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _seleccionarArchivo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result != null && result.files.single.path != null) {
        if (!mounted) return;
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _resultado = null;
        });
        await _procesarArchivo(_selectedFile!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar archivo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _procesarArchivo(File file) async {
    final notificationService = NotificationService();

    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _puedeMinimizar = true;
      _currentProgress = 0;
      _totalProcessed = 100;
      _etiquetaProgreso = 'Iniciando procesamiento...';
      _resultado = null;
    });

    await notificationService.showProgressNotification(
      progress: 0,
      total: 100,
      title: 'Carga Masiva de Extranjeros',
      body: 'Iniciando procesamiento...',
    );

    try {
      final resultado =
          await BulkUploadExtranjerosService.procesarExcelEnSegundoPlano(
            file.path,
            (progreso, total, etiqueta) {
              if (mounted) {
                setState(() {
                  _currentProgress = progreso;
                  if (total > 0 &&
                      (total > _totalProcessed || _totalProcessed == 100)) {
                    _totalProcessed = total;
                  }
                  _etiquetaProgreso = etiqueta;
                });
              }

              notificationService.showProgressNotification(
                progress: progreso,
                total: total > 0 ? total : _totalProcessed,
                title: 'Carga Masiva de Extranjeros',
                body: etiqueta,
              );
            },
          );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _puedeMinimizar = false;
          _resultado = resultado;
          _currentProgress = resultado.totalRows;
          _totalProcessed = resultado.totalRows > 0 ? resultado.totalRows : 1;
          _etiquetaProgreso = 'Proceso completado';
        });

        await notificationService.showCompletionNotification(
          total: resultado.totalRows,
          successCount: resultado.successCount,
          errorCount: resultado.errorCount,
        );

        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          _mostrarResultados();
        }
      }
    } catch (e) {
      await notificationService.cancelProgressNotification();
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _puedeMinimizar = false;
          _etiquetaProgreso = 'Error en el procesamiento';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar archivo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _mostrarResultados() {
    if (_resultado == null || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final List<Widget> errorWidgets = [];
      if (_resultado!.errors.isNotEmpty) {
        for (var error in _resultado!.errors.take(10)) {
          errorWidgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $error', style: const TextStyle(fontSize: 12)),
            ),
          );
        }
      }

      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              Icon(
                _resultado!.errorCount == 0 ? Icons.check_circle : Icons.info,
                color: _resultado!.errorCount == 0
                    ? AppColors.success
                    : AppColors.warning,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Proceso Completado',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total procesado: ${_resultado!.totalRows}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Extranjeros guardados: ${_resultado!.successCount}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  if (_resultado!.errorCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Errores: ${_resultado!.errorCount}',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  if (_resultado!.errors.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Errores detallados:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...errorWidgets,
                    if (_resultado!.errors.length > 10)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '... y ${_resultado!.errors.length - 10} errores más',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('CERRAR'),
            ),
            if (_resultado!.successCount > 0)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (mounted) Navigator.of(context).pop(true);
                },
                child: const Text('ACEPTAR'),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildProgressCard(BuildContext context) {
    final total = _totalProcessed > 0 ? _totalProcessed : 1;
    final pct = (100.0 * _currentProgress / total).clamp(0.0, 100.0);
    final value = (_currentProgress / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryLight, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _etiquetaProgreso.isNotEmpty
                              ? _etiquetaProgreso
                              : 'Procesando...',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 14,
                backgroundColor: AppColors.primaryUltraLight,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progreso: $_currentProgress / $_totalProcessed registros',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_resultado != null) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '✓ ${_resultado!.successCount} guardados',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_resultado!.errorCount > 0)
                        Text(
                          '⚠ ${_resultado!.errorCount} errores',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                    ],
                  ),
                ] else if (_isProcessing && _currentProgress > 0) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Procesados: $_currentProgress',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Restantes: ${_totalProcessed - _currentProgress}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            if (_puedeMinimizar) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryUltraLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryLight),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Puedes minimizar la app. El proceso continuará en segundo plano.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carga Masiva de Extranjeros')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryUltraLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Formato del Archivo',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '📌 CSV es 10-50x más rápido que Excel para archivos grandes. En Excel: Guardar como → CSV UTF-8.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Columnas obligatorias:\n• Cedula Colombiana\n• Nombre Completo\n\nColumnas opcionales:\n• Telefono\n• Es Nacionalizado (SI/NO)\n• Departamento\n• Municipio\n• Direccion\n• Email\n• Sisben\n• Cedula Venezolana (Obligatoria si es Nacionalizado)',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : _descargarPlantillaExcel,
                      icon: const Icon(Icons.download),
                      label: const Text('Descargar Plantilla Excel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_isProcessing || _resultado != null)
              _buildProgressCard(context)
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.upload_file,
                      size: 80,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Selecciona un archivo Excel (.xlsx) o CSV',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _seleccionarArchivo,
                        icon: const Icon(Icons.folder_open),
                        label: const Text(
                          'Explorar Archivos',
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
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
