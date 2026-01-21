import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:goblafria/core/theme/app_theme.dart';
import 'package:goblafria/models/models.dart';
import 'package:goblafria/database/db_helper.dart';
import 'package:goblafria/features/solicitudes/data/repositories/solicitud_repository.dart';
import 'package:goblafria/features/reportes/data/repositories/reporte_repository.dart';
import 'package:goblafria/features/comunas/data/repositories/comuna_repository.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PlanEstadisticasPage extends StatefulWidget {
  final String tituloPlan;
  final TipoSolicitud tipoSolicitud;

  const PlanEstadisticasPage({
    super.key,
    required this.tituloPlan,
    required this.tipoSolicitud,
  });

  @override
  State<PlanEstadisticasPage> createState() => _PlanEstadisticasPageState();
}

class _PlanEstadisticasPageState extends State<PlanEstadisticasPage> {
  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  
  int _totalSolicitudes = 0;
  int _totalLuminarias = 0;
  int _totalEntregadas = 0;
  int _totalPendientes = 0;

  List<Solicitud> _solicitudes = [];
  List<Reporte> _reportes = [];
  List<Comuna> _comunas = [];
  
  Comuna? _comunaFiltrada;

  late SolicitudRepository _solicitudRepo;
  late ReporteRepository _reporteRepo;
  late ComunaRepository _comunaRepo;
  
  // GlobalKey para capturar el gráfico como imagen
  final GlobalKey _chartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    final isar = await DbHelper().db;
    _solicitudRepo = SolicitudRepository(isar);
    _reporteRepo = ReporteRepository(isar);
    _comunaRepo = ComunaRepository(isar);
    
    await _cargarDatos();
  }

  Future<void> _cargarDatos({Comuna? comunaFiltro}) async {
    setState(() => _isLoading = true);
    
    // Cargar todas las solicitudes del tipo especificado
    final todasSolicitudes = await _solicitudRepo.getAllSolicitudes();
    _solicitudes = todasSolicitudes
        .where((s) => s.tipoSolicitud == widget.tipoSolicitud)
        .toList();
    
    // Si hay filtro de comuna, aplicarlo
    if (comunaFiltro != null) {
      _solicitudes = _solicitudes.where((s) {
        if (s.comuna.value?.id == comunaFiltro.id) return true;
        return false;
      }).toList();
    }
    
    // Cargar reportes
    _reportes = await _reporteRepo.getAllReportes();
    
    // Cargar comunas para el filtro
    _comunas = await _comunaRepo.getAllComunas();
    
    // Cargar relaciones de solicitudes
    for (var s in _solicitudes) {
      await s.comuna.load();
      await s.consejoComunal.load();
    }
    
    // Cargar relaciones de reportes
    for (var r in _reportes) {
      await r.solicitud.load();
    }
    
    // Calcular estadísticas
    _calcularEstadisticas();
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _calcularEstadisticas() {
    _totalSolicitudes = _solicitudes.length;
    _totalLuminarias = 0;
    _totalEntregadas = 0;
    
    // Calcular total solicitado
    for (var s in _solicitudes) {
      _totalLuminarias += s.cantidadLuminarias ?? 0;
    }
    
    // Calcular total entregado desde los reportes
    for (var r in _reportes) {
      final solicitud = r.solicitud.value;
      if (solicitud != null && _solicitudes.any((s) => s.id == solicitud.id)) {
        _totalEntregadas += r.luminariasEntregadas ?? 0;
      }
    }
    
    _totalPendientes = _totalLuminarias - _totalEntregadas;
  }

  Map<String, Map<String, int>> _calcularEstadisticasPorComuna() {
    final estadisticasPorComuna = <String, Map<String, int>>{};
    
    // Inicializar estadísticas para cada comuna
    for (var solicitud in _solicitudes) {
      final comunaNombre = solicitud.comuna.value?.nombreComuna ?? 'Sin comuna';
      
      if (!estadisticasPorComuna.containsKey(comunaNombre)) {
        estadisticasPorComuna[comunaNombre] = {
          'solicitadas': 0,
          'entregadas': 0,
          'pendientes': 0,
        };
      }
      
      // Sumar luminarias solicitadas
      estadisticasPorComuna[comunaNombre]!['solicitadas'] = 
          (estadisticasPorComuna[comunaNombre]!['solicitadas'] ?? 0) + 
          (solicitud.cantidadLuminarias ?? 0);
    }
    
    // Calcular entregadas por cada reporte
    for (var reporte in _reportes) {
      final solicitud = reporte.solicitud.value;
      if (solicitud != null && _solicitudes.any((s) => s.id == solicitud.id)) {
        final comunaNombre = solicitud.comuna.value?.nombreComuna ?? 'Sin comuna';
        
        if (estadisticasPorComuna.containsKey(comunaNombre)) {
          estadisticasPorComuna[comunaNombre]!['entregadas'] = 
              (estadisticasPorComuna[comunaNombre]!['entregadas'] ?? 0) + 
              (reporte.luminariasEntregadas ?? 0);
        }
      }
    }
    
    // Calcular pendientes
    for (var entry in estadisticasPorComuna.entries) {
      final solicitadas = entry.value['solicitadas'] ?? 0;
      final entregadas = entry.value['entregadas'] ?? 0;
      estadisticasPorComuna[entry.key]!['pendientes'] = solicitadas - entregadas;
    }
    
    return estadisticasPorComuna;
  }

  Future<Uint8List?> _capturarGraficoComoImagen() async {
    try {
      // Esperar varios frames para asegurar que el widget está completamente renderizado
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Forzar un rebuild para asegurar que el gráfico esté visible
      if (mounted) {
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      final BuildContext? context = _chartKey.currentContext;
      if (context == null) {
        debugPrint('Error: No se encontró el contexto del gráfico');
        return null;
      }
      
      final RenderObject? renderObject = context.findRenderObject();
      if (renderObject == null || !renderObject.attached) {
        debugPrint('Error: El render object no está disponible o no está attached');
        return null;
      }
      
      final RenderRepaintBoundary? boundary = renderObject as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('Error: No se pudo obtener el RepaintBoundary');
        return null;
      }
      
      // Capturar la imagen con alta calidad
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        debugPrint('Error: No se pudo convertir la imagen a bytes');
        return null;
      }
      
      debugPrint('Gráfico capturado exitosamente: ${byteData.lengthInBytes} bytes');
      return byteData.buffer.asUint8List();
    } catch (e, stackTrace) {
      debugPrint('Error al capturar gráfico: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<void> _generarPDF() async {
    setState(() => _isGeneratingPdf = true);
    
    try {
      // Capturar el gráfico como imagen ANTES de generar el PDF
      debugPrint('Intentando capturar gráfico...');
      final imagenGrafico = await _capturarGraficoComoImagen();
      
      if (imagenGrafico != null) {
        debugPrint('✅ Gráfico capturado exitosamente: ${imagenGrafico.length} bytes');
      } else {
        debugPrint('⚠️ No se pudo capturar el gráfico, usando método alternativo');
      }
      
      // Crear la imagen del PDF antes de construir el documento
      pw.ImageProvider? imagenPdf;
      if (imagenGrafico != null) {
        try {
          imagenPdf = pw.MemoryImage(imagenGrafico);
          debugPrint('✅ Imagen PDF creada exitosamente');
        } catch (e) {
          debugPrint('❌ Error al crear imagen PDF: $e');
          imagenPdf = null;
        }
      }
      
      final pdf = pw.Document();
      
      // Determinar título según filtro
      final tipoReporte = _comunaFiltrada != null
          ? 'Reporte por Comuna'
          : 'Reporte Municipal';
      
      final subtitulo = _comunaFiltrada != null
          ? _comunaFiltrada!.nombreComuna
          : 'Consolidado General';
      
      final porcentajeAvance = _totalLuminarias > 0 
          ? ((_totalEntregadas / _totalLuminarias) * 100).toStringAsFixed(1)
          : '0';
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Encabezado institucional mejorado
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(24),
                  decoration: pw.BoxDecoration(
                    gradient: const pw.LinearGradient(
                      colors: [PdfColors.blue900, PdfColors.blue800],
                      begin: pw.Alignment.topLeft,
                      end: pw.Alignment.bottomRight,
                    ),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'ALCALDÍA DEL MUNICIPIO GARCÍA DE HEVIA',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              'LA FRÍA - ESTADO TÁCHIRA',
                              style: const pw.TextStyle(
                                fontSize: 11,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.white,
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                              ),
                              child: pw.Text(
                                'DOCUMENTO OFICIAL',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.Container(
                        width: 60,
                        height: 60,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(30)),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            '2026',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 25),
                
                // Título del plan con formato oficial
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.blue700, width: 2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    color: PdfColors.white,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        widget.tituloPlan.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                          letterSpacing: 1.2,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue100,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          '$tipoReporte - $subtitulo',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // Resumen ejecutivo institucional
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.blue300, width: 1.5),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _buildIndicadorPdf(
                        'SOLICITUDES',
                        _totalSolicitudes.toString(),
                        PdfColors.blue700,
                      ),
                      pw.Container(
                        width: 1,
                        height: 40,
                        color: PdfColors.grey400,
                      ),
                      _buildIndicadorPdf(
                        'AVANCE',
                        '$porcentajeAvance%',
                        double.parse(porcentajeAvance) >= 75
                            ? PdfColors.green700
                            : double.parse(porcentajeAvance) >= 50
                                ? PdfColors.orange700
                                : PdfColors.red700,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // Tabla de estadísticas detalladas
                pw.Text(
                  'BALANCE DE LUMINARIAS',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 1,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    // Encabezado
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text(
                            'Concepto',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text(
                            'Cantidad',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              fontSize: 11,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    // Filas de datos
                    _buildPdfTableRow('Luminarias Solicitadas', _totalLuminarias, PdfColors.orange100),
                    _buildPdfTableRow('Luminarias Entregadas', _totalEntregadas, PdfColors.green100),
                    _buildPdfTableRow('Luminarias Pendientes', _totalPendientes, PdfColors.red100),
                  ],
                ),
                pw.SizedBox(height: 25),
                
                // Gráfico de columnas
                pw.Text(
                  'DISTRIBUCIÓN DE LUMINARIAS',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 12),
                // Generar gráfico directamente en el PDF (más confiable)
                _buildGraficoColumnasPdf(),
                pw.SizedBox(height: 25),
                
                // Balance por comuna (solo en reporte municipal)
                if (_comunaFiltrada == null) ...[
                  pw.Text(
                    'BALANCE POR COMUNA',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  _buildTablaComunasPdf(),
                  pw.SizedBox(height: 25),
                ],
                
                // Indicador de progreso visual
                pw.Text(
                  'PROGRESO DE EJECUCIÓN',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints?.maxWidth ?? 500;
                    final progressWidth = _totalLuminarias > 0
                        ? (maxWidth * (_totalEntregadas / _totalLuminarias))
                        : 0.0;
                    
                    return pw.Container(
                      height: 30,
                      width: maxWidth,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Stack(
                        children: [
                          if (progressWidth > 0)
                            pw.Container(
                              width: progressWidth,
                              height: 30,
                              decoration: const pw.BoxDecoration(
                                color: PdfColors.green600,
                                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                              ),
                            ),
                          pw.Center(
                            child: pw.Text(
                              '$porcentajeAvance% Completado',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 11,
                                color: double.parse(porcentajeAvance) > 20
                                    ? PdfColors.white
                                    : PdfColors.grey800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                // Pie de página institucional
                pw.Spacer(),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.blue700, width: 2),
                    ),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Fecha de Generación:',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey800,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                DateTime.now().toString().split('.')[0],
                                style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.grey700,
                                ),
                              ),
                            ],
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.blue900,
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Text(
                              'REPORTE OFICIAL',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Divider(color: PdfColors.grey400),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Sistema de Gestión Municipal - Sala Situacional',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
      
      // Guardar y compartir PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("✅ PDF generado exitosamente"),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al generar PDF: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  pw.TableRow _buildPdfTableRow(String concepto, int cantidad, PdfColor bgColor) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bgColor),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(12),
          child: pw.Text(
            concepto,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(12),
          child: pw.Text(
            cantidad.toString(),
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildGraficoColumnasPdf() {
    final maxValue = [_totalLuminarias, _totalEntregadas, _totalPendientes]
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    
    const chartHeight = 180.0;
    const barWidth = 70.0;
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue200, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        color: PdfColors.white,
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            height: chartHeight + 80,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _buildColumnaPdf(
                  'Solicitadas',
                  _totalLuminarias,
                  maxValue > 0 ? maxValue : 1,
                  chartHeight,
                  barWidth,
                  PdfColors.orange600,
                ),
                _buildColumnaPdf(
                  'Entregadas',
                  _totalEntregadas,
                  maxValue > 0 ? maxValue : 1,
                  chartHeight,
                  barWidth,
                  PdfColors.green600,
                ),
                _buildColumnaPdf(
                  'Pendientes',
                  _totalPendientes,
                  maxValue > 0 ? maxValue : 1,
                  chartHeight,
                  barWidth,
                  PdfColors.red600,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildColumnaPdf(
    String etiqueta,
    int valor,
    double maxValor,
    double alturaMaxima,
    double ancho,
    PdfColor color,
  ) {
    final porcentaje = maxValor > 0 ? (valor / maxValor).clamp(0.0, 1.0) : 0.0;
    var alturaBarra = alturaMaxima * porcentaje;
    
    // Altura mínima visible si el valor es mayor a 0
    if (valor > 0 && alturaBarra < 20) {
      alturaBarra = 20;
    }
    
    alturaBarra = alturaBarra.clamp(10.0, alturaMaxima);
    
    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        // Valor encima de la columna
        pw.Text(
          valor.toString(),
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 8),
        // Columna
        pw.Container(
          width: ancho,
          height: alturaBarra,
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(6),
              topRight: pw.Radius.circular(6),
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        // Etiqueta debajo
        pw.SizedBox(
          width: ancho + 10,
          child: pw.Text(
            etiqueta,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTablaComunasPdf() {
    final estadisticasPorComuna = _calcularEstadisticasPorComuna();
    final comunasOrdenadas = estadisticasPorComuna.keys.toList()..sort();
    
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey400,
        width: 1,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        // Encabezado
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue900),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                'Comuna',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                'Solicitadas',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                'Entregadas',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                'Pendientes',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
        // Filas de datos por comuna
        ...comunasOrdenadas.asMap().entries.map((entry) {
          final index = entry.key;
          final comunaNombre = entry.value;
          final stats = estadisticasPorComuna[comunaNombre]!;
          
          final bgColor = index % 2 == 0 ? PdfColors.grey100 : PdfColors.white;
          
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bgColor),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Text(
                  comunaNombre,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Text(
                  stats['solicitadas'].toString(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange700,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Text(
                  stats['entregadas'].toString(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green700,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Text(
                  stats['pendientes'].toString(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red700,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        }),
        // Fila de totales
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue100),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                'TOTAL',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                _totalLuminarias.toString(),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange700,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                _totalEntregadas.toString(),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green700,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(
                _totalPendientes.toString(),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red700,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildIndicadorPdf(String etiqueta, String valor, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          etiqueta,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          valor,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }


  Future<void> _mostrarDialogoFiltro() async {
    final comunaSeleccionada = await showDialog<Comuna>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Filtrar por Comuna"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _comunas.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  title: const Text("Todas las comunas"),
                  onTap: () => Navigator.pop(context, null),
                );
              }
              final comuna = _comunas[index - 1];
              return ListTile(
                title: Text(comuna.nombreComuna),
                onTap: () => Navigator.pop(context, comuna),
              );
            },
          ),
        ),
      ),
    );
    
    // Si el diálogo no fue cancelado
    if (!mounted) return;
    
    setState(() {
      _comunaFiltrada = comunaSeleccionada;
    });
    
    await _cargarDatos(comunaFiltro: comunaSeleccionada);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.tituloPlan)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tituloPlan),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título de la sección
            Text(
              _comunaFiltrada != null
                  ? "Reporte por Comuna: ${_comunaFiltrada!.nombreComuna}"
                  : "Balance Municipal",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),

            // Tarjetas de estadísticas
            _buildEstadisticaCard(
              "Total de Solicitudes",
              _totalSolicitudes.toString(),
              Icons.assignment,
              AppColors.info,
            ),
            const SizedBox(height: 12),
            _buildEstadisticaCard(
              "Luminarias Solicitadas",
              _totalLuminarias.toString(),
              Icons.lightbulb_outline,
              AppColors.warning,
            ),
            const SizedBox(height: 12),
            _buildEstadisticaCard(
              "Luminarias Entregadas",
              _totalEntregadas.toString(),
              Icons.check_circle,
              AppColors.success,
            ),
            const SizedBox(height: 12),
            _buildEstadisticaCard(
              "Luminarias Pendientes",
              _totalPendientes.toString(),
              Icons.pending,
              AppColors.error,
            ),
            const SizedBox(height: 32),

            // Gráfico de columnas
            Text(
              "Gráfico de Distribución",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildGraficoColumnas(),
            const SizedBox(height: 32),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGeneratingPdf ? null : _generarPDF,
                    icon: _isGeneratingPdf
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: const Text("Generar PDF"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _mostrarDialogoFiltro,
                    icon: const Icon(Icons.filter_list),
                    label: const Text("Filtrar"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildEstadisticaCard(
    String titulo,
    String valor,
    IconData icono,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    valor,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoColumnas() {
    final maxValue = [_totalLuminarias, _totalEntregadas, _totalPendientes]
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    
    return RepaintBoundary(
      key: _chartKey,
      child: Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              AppColors.primaryUltraLight.withOpacity(0.3),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.bar_chart,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "Comparativa de Luminarias",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceEvenly,
                  maxY: maxValue + (maxValue * 0.15),
                  minY: 0,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 80,
                        getTitlesWidget: (value, meta) {
                          String label;
                          int cantidad;
                          Color color;
                          
                          switch (value.toInt()) {
                            case 0:
                              label = 'Solicitadas';
                              cantidad = _totalLuminarias;
                              color = AppColors.warning;
                              break;
                            case 1:
                              label = 'Entregadas';
                              cantidad = _totalEntregadas;
                              color = AppColors.success;
                              break;
                            case 2:
                              label = 'Pendientes';
                              cantidad = _totalPendientes;
                              color = AppColors.error;
                              break;
                            default:
                              return const Text('');
                          }
                          
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cantidad.toString(),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: maxValue > 0 ? (maxValue / 5).ceilToDouble() : 10,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxValue > 0 ? (maxValue / 5).ceilToDouble() : 10,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppColors.border.withOpacity(0.3),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      );
                    },
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 1.5),
                      left: BorderSide(color: AppColors.border, width: 1.5),
                    ),
                  ),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: _totalLuminarias.toDouble(),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.warning,
                              AppColors.warning.withOpacity(0.7),
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: _totalEntregadas.toDouble(),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.success,
                              AppColors.success.withOpacity(0.7),
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 2,
                      barRods: [
                        BarChartRodData(
                          toY: _totalPendientes.toDouble(),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.error,
                              AppColors.error.withOpacity(0.7),
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
