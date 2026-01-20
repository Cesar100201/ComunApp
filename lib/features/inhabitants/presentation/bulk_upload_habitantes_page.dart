import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/notification_service.dart';
import '../data/services/bulk_upload_service.dart';

class BulkUploadHabitantesPage extends StatefulWidget {
  const BulkUploadHabitantesPage({super.key});

  @override
  State<BulkUploadHabitantesPage> createState() => _BulkUploadHabitantesPageState();
}

class _BulkUploadHabitantesPageState extends State<BulkUploadHabitantesPage> {
  File? _selectedFile;
  bool _isProcessing = false;
  bool _puedeMinimizar = false;
  
  // Progreso
  int _totalProcessed = 0;
  int _currentProgress = 0;
  String _etiquetaProgreso = '';
  
  // Resultados
  BulkUploadResult? _resultado;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _descargarPlantillaExcel() async {
    try {
      if (!mounted) return;
      setState(() {
        _isProcessing = true;
      });

      // Crear archivo Excel
      final excel = Excel.createExcel();
      final sheet = excel['Habitantes'];
      
      // Encabezados
      final headers = [
        'cedula',
        'nombre completo',
        'nacionalidad',
        'telefono',
        'genero',
        'fecha nacimiento',
        'estado',
        'municipio',
        'PARROQUIA',
        'comuna',
        'consejo comunal',
        'comunidad',
        'calle',
        'numero casa',
        'estatus politico',
        'nivel voto',
        'clap',
        'cedula jefe',
      ];
      
      for (var i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
      }
      
      // Datos de ejemplo
      final datosEjemplo = [
        ['12345678', 'JUAN CARLOS PÉREZ GONZÁLEZ', 'V', '04121234567', 'M', '15/03/1985', 'Táchira', 'García de Hevia', 'LaFria', 'Comuna Central', 'Consejo Central', 'Comunidad El Centro', 'Av. Bolívar', '15', 'Chavista', 'Duro', 'CLAP Centro', ''],
        ['87654321', 'MARÍA JOSÉ GONZÁLEZ LÓPEZ', 'V', '04241234567', 'F', '20/07/1990', 'Táchira', 'García de Hevia', 'LaFria', 'Comuna Norte', 'Consejo Norte', 'Comunidad Los Mangos', 'Calle 5', '23', 'Neutral', 'Blando', 'CLAP Norte', ''],
      ];
      
      for (var i = 0; i < datosEjemplo.length; i++) {
        for (var j = 0; j < datosEjemplo[i].length; j++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1)).value = TextCellValue(datosEjemplo[i][j]);
        }
      }
      
      // Guardar archivo
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/plantilla_carga_masiva_habitantes.xlsx';
      final file = File(path);
      final bytes = excel.save();
      if (bytes != null) {
        final uint8List = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
        await file.writeAsBytes(uint8List);
        
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          
          final result = await FilePicker.platform.saveFile(
            dialogTitle: 'Guardar plantilla Excel',
            fileName: 'plantilla_carga_masiva_habitantes.xlsx',
            bytes: uint8List,
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
          );
          
          if (result != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Plantilla guardada en: $result'),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Plantilla generada en: ${file.path}'),
                backgroundColor: AppColors.info,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        
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
    final extension = file.path.split('.').last.toLowerCase();
    
    if (extension == 'csv') {
      // Convertir CSV a Excel primero para usar el mismo procesador
      await _procesarCSV(file);
    } else if (extension == 'xlsx' || extension == 'xls') {
      await _procesarExcel(file);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Formato de archivo no soportado. Use Excel (.xlsx) o CSV (.csv)'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _procesarCSV(File file) async {
    // Por ahora, mostrar mensaje de que se debe usar Excel para mejor rendimiento
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Para mejor rendimiento, use formato Excel (.xlsx). El CSV se procesará de forma básica.'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 5),
        ),
      );
    }
    
    // Procesar CSV de forma básica (sin isolate para mantener compatibilidad)
    // En producción, sería mejor convertir CSV a Excel primero
    await _procesarExcel(file);
  }

  Future<void> _procesarExcel(File file) async {
    final notificationService = NotificationService();
    
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _puedeMinimizar = true;
      _currentProgress = 0;
      _totalProcessed = 100; // Inicializar con un valor temporal hasta conocer el total real
      _etiquetaProgreso = 'Iniciando procesamiento...';
      _resultado = null;
    });

    // Mostrar notificación inicial
    await notificationService.showProgressNotification(
      progress: 0,
      total: 100,
      title: 'Carga Masiva de Habitantes',
      body: 'Iniciando procesamiento...',
    );

    try {
      // Procesar con callback de progreso
      final resultado = await BulkUploadService.procesarExcelEnSegundoPlano(
        file.path,
        (progreso, total, etiqueta) {
          if (mounted) {
            setState(() {
              _currentProgress = progreso;
              // Actualizar total solo si es mayor que 0 y mayor que el actual
              if (total > 0 && (total > _totalProcessed || _totalProcessed == 100)) {
                _totalProcessed = total;
              }
              _etiquetaProgreso = etiqueta;
            });
          }
          
          // Actualizar notificación con el progreso
          notificationService.showProgressNotification(
            progress: progreso,
            total: total > 0 ? total : _totalProcessed,
            title: 'Carga Masiva de Habitantes',
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
        
        // Mostrar notificación de finalización
        await notificationService.showCompletionNotification(
          total: resultado.totalRows,
          successCount: resultado.successCount,
          errorCount: resultado.errorCount,
        );
        
        // Esperar un momento para que la UI se actualice antes de mostrar el diálogo
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (mounted) {
          _mostrarResultados();
        }
      }
    } catch (e) {
      // Cancelar notificación de progreso en caso de error
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
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryLight, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
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
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _etiquetaProgreso.isNotEmpty ? _etiquetaProgreso : 'Procesando...',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (_isProcessing && _currentProgress > 0 && _totalProcessed > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${pct.toStringAsFixed(1)}% completado',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary.withOpacity(0.7),
                                fontSize: 12,
                              ),
                        ),
                      ],
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
                      if (_resultado!.errorCount > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '⚠ ${_resultado!.errorCount} errores',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ],
                  ),
                ] else if (_isProcessing && _currentProgress > 0) ...[
                  // Mostrar contadores en tiempo real durante el procesamiento
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary.withOpacity(0.7),
                              fontSize: 11,
                            ),
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
                    Icon(Icons.info_outline, size: 18, color: AppColors.primary),
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

  void _mostrarResultados() {
    if (_resultado == null || !mounted) return;
    
    // Usar addPostFrameCallback para asegurar que el diálogo se muestre después de que la UI se actualice
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _resultado!.errorCount == 0 ? Icons.check_circle : Icons.info,
              color: _resultado!.errorCount == 0 ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 10),
            const Text('Proceso Completado'),
          ],
        ),
        content: SingleChildScrollView(
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
                'Habitantes guardados: ${_resultado!.successCount}',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
              ),
              if (_resultado!.errorCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Errores: ${_resultado!.errorCount}',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                ),
              ],
              if (_resultado!.errors.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Errores detallados:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _resultado!.errors.length > 10 ? 10 : _resultado!.errors.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• ${_resultado!.errors[index]}', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
                if (_resultado!.errors.length > 10)
                  Text(
                    '... y ${_resultado!.errors.length - 10} errores más',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
              ],
            ],
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
                if (mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('ACEPTAR'),
            ),
        ],
      ),
    );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carga Masiva de Habitantes'),
      ),
      body: Column(
        children: [
          // Información del formato
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryUltraLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Formato del Archivo',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'El archivo Excel (.xlsx) es el formato recomendado para mejor rendimiento. Los datos se guardan automáticamente en lotes de 500 registros para máxima velocidad:',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Columnas obligatorias:\n• Cédula\n• Nombre Completo\n\nColumnas opcionales:\n• Nacionalidad (V o E)\n• Teléfono\n• Fecha Nacimiento (DD/MM/YYYY o formato Excel)\n• Género (M/F o Masculino/Femenino)\n• Estado, Municipio, Parroquia, Comuna\n• Calle, Número Casa\n• Estatus Político, Nivel Voto\n• CLAP, Consejo Comunal\n• Cédula Jefe (para cargas familiares)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.speed, size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Procesamiento optimizado: Miles de registros en segundos. Puedes minimizar la app durante la carga.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Botón para descargar plantilla Excel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : _descargarPlantillaExcel,
              icon: const Icon(Icons.download),
              label: const Text('DESCARGAR PLANTILLA EXCEL'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          
          const SizedBox(height: 12),

          // Botón de selección de archivo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _seleccionarArchivo,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_selectedFile == null ? 'SELECCIONAR ARCHIVO EXCEL/CSV' : 'CAMBIAR ARCHIVO'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),

          if (_selectedFile != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedFile!.path.split('/').last,
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (_isProcessing) ...[
            const SizedBox(height: 16),
            _buildProgressCard(context),
          ],

          // Mostrar resultados si hay
          if (_resultado != null && !_isProcessing) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _resultado!.errorCount == 0 
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _resultado!.errorCount == 0 
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _resultado!.errorCount == 0 ? Icons.check_circle : Icons.warning,
                          color: _resultado!.errorCount == 0 ? AppColors.success : AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Proceso Finalizado',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _resultado!.errorCount == 0 ? AppColors.success : AppColors.warning,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Total: ${_resultado!.totalRows} | Exitosos: ${_resultado!.successCount} | Errores: ${_resultado!.errorCount}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Espacio flexible
          const Spacer(),
        ],
      ),
    );
  }
}
