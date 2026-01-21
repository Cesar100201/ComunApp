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
  int _totalLamparas = 0;
  int _totalBombillos = 0;
  int _lamparasEntregadas = 0;
  int _lamparasPendientes = 0;
  int _bombillosEntregados = 0;
  int _bombillosPendientes = 0;

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
    _totalLamparas = 0;
    _totalBombillos = 0;
    _lamparasEntregadas = 0;
    _lamparasPendientes = 0;
    _bombillosEntregados = 0;
    _bombillosPendientes = 0;
    
    // Calcular total solicitado
    for (var s in _solicitudes) {
      final lamparas = s.cantidadLamparas ?? 0;
      final bombillos = s.cantidadBombillos ?? 0;
      final totalSolicitud = lamparas + bombillos;
      
      _totalLamparas += lamparas;
      _totalBombillos += bombillos;
      _totalLuminarias += totalSolicitud;
    }
    
    // Calcular total entregado desde los reportes (proporcionalmente)
    for (var r in _reportes) {
      final solicitud = r.solicitud.value;
      if (solicitud != null && _solicitudes.any((s) => s.id == solicitud.id)) {
        final luminariasEntregadas = r.luminariasEntregadas ?? 0;
        _totalEntregadas += luminariasEntregadas;
        
        // Calcular proporción de lámparas y bombillos entregados
        final lamparasSolicitud = solicitud.cantidadLamparas ?? 0;
        final bombillosSolicitud = solicitud.cantidadBombillos ?? 0;
        final totalSolicitud = lamparasSolicitud + bombillosSolicitud;
        
        if (totalSolicitud > 0) {
          // Calcular proporción de lámparas
          final proporcionLamparas = lamparasSolicitud / totalSolicitud;
          
          // Calcular entregas proporcionales (redondeando para lámparas)
          final lamparasEntregadas = (luminariasEntregadas * proporcionLamparas).round();
          final bombillosEntregados = luminariasEntregadas - lamparasEntregadas; // El resto son bombillos
          
          _lamparasEntregadas += lamparasEntregadas;
          _bombillosEntregados += bombillosEntregados;
        }
      }
    }
    
    // Calcular pendientes
    _totalPendientes = _totalLuminarias - _totalEntregadas;
    // Asegurar que los pendientes no sean negativos
    if (_totalPendientes < 0) _totalPendientes = 0;
    
    _lamparasPendientes = _totalLamparas - _lamparasEntregadas;
    if (_lamparasPendientes < 0) _lamparasPendientes = 0;
    
    _bombillosPendientes = _totalBombillos - _bombillosEntregados;
    if (_bombillosPendientes < 0) _bombillosPendientes = 0;
  }

  Map<String, Map<String, int>> _calcularEstadisticasPorComuna() {
    final estadisticasPorComuna = <String, Map<String, int>>{};
    
    // Inicializar estadísticas para cada comuna
    for (var solicitud in _solicitudes) {
      final comunaNombre = solicitud.comuna.value?.nombreComuna ?? 'Sin comuna';
      
      if (!estadisticasPorComuna.containsKey(comunaNombre)) {
        estadisticasPorComuna[comunaNombre] = {
          'lamparas': 0,
          'bombillos': 0,
          'solicitadas': 0,
          'entregadas': 0,
          'pendientes': 0,
        };
      }
      
      // Sumar lámparas y bombillos por separado
      final lamparas = solicitud.cantidadLamparas ?? 0;
      final bombillos = solicitud.cantidadBombillos ?? 0;
      final totalSolicitud = lamparas + bombillos;
      
      estadisticasPorComuna[comunaNombre]!['lamparas'] = 
          (estadisticasPorComuna[comunaNombre]!['lamparas'] ?? 0) + lamparas;
      estadisticasPorComuna[comunaNombre]!['bombillos'] = 
          (estadisticasPorComuna[comunaNombre]!['bombillos'] ?? 0) + bombillos;
      // Total solicitadas (suma de ambos)
      estadisticasPorComuna[comunaNombre]!['solicitadas'] = 
          (estadisticasPorComuna[comunaNombre]!['solicitadas'] ?? 0) + totalSolicitud;
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


  Future<void> _generarPDF() async {
    setState(() => _isGeneratingPdf = true);
    
    try {
      final pdf = pw.Document();
      
      // Determinar título según filtro
      final tipoReporte = _comunaFiltrada != null
          ? 'REPORTE POR COMUNA'
          : 'REPORTE MUNICIPAL';
      
      final subtitulo = _comunaFiltrada != null
          ? _comunaFiltrada!.nombreComuna.toUpperCase()
          : 'CONSOLIDADO GENERAL';
      
      final porcentajeAvance = _totalLuminarias > 0 
          ? ((_totalEntregadas / _totalLuminarias) * 100).toStringAsFixed(1)
          : '0';
      
      final fechaActual = DateTime.now();
      final fechaFormateada = '${fechaActual.day.toString().padLeft(2, '0')}/${fechaActual.month.toString().padLeft(2, '0')}/${fechaActual.year}';
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 40),
          header: (pw.Context context) {
            return pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.only(bottom: 25),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.blue900, width: 4),
                ),
                gradient: const pw.LinearGradient(
                  colors: [PdfColors.blue50, PdfColors.white],
                  begin: pw.Alignment.topCenter,
                  end: pw.Alignment.bottomCenter,
                ),
              ),
              child: pw.Column(
                children: [
                  pw.SizedBox(height: 5),
                  // Línea decorativa superior
                  pw.Container(
                    width: double.infinity,
                    height: 3,
                    decoration: const pw.BoxDecoration(
                      gradient: pw.LinearGradient(
                        colors: [PdfColors.blue900, PdfColors.blue700, PdfColors.blue900],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  // Texto principal
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'REPÚBLICA BOLIVARIANA DE VENEZUELA',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'ALCALDÍA DEL MUNICIPIO GARCÍA DE HEVIA',
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'LA FRÍA - ESTADO TÁCHIRA',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  // Banner oficial mejorado
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(vertical: 10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue900,
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'DOCUMENTO OFICIAL',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.only(top: 18),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.blue900, width: 2),
                ),
                gradient: const pw.LinearGradient(
                  colors: [PdfColors.white, PdfColors.grey50],
                  begin: pw.Alignment.topCenter,
                  end: pw.Alignment.bottomCenter,
                ),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 3,
                            height: 12,
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Text(
                            'Fecha de Emisión: $fechaFormateada',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue900,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                        ),
                        child: pw.Text(
                          'Página ${context.pageNumber} de ${context.pagesCount}',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Center(
                    child: pw.Text(
                      'Sistema de Gestión Municipal - Sala Situacional',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            return [
              // Título del documento mejorado
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 25),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Línea decorativa superior
                    pw.Container(
                      width: 100,
                      height: 4,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Text(
                      widget.tituloPlan.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                        letterSpacing: 1.5,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 10),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue100,
                        border: pw.Border.all(color: PdfColors.blue700, width: 1.5),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            tipoReporte,
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            subtitulo,
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    // Línea decorativa inferior
                    pw.Container(
                      width: 100,
                      height: 4,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue900,
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 25),
              
              // Resumen ejecutivo mejorado
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(25),
                decoration: pw.BoxDecoration(
                  gradient: const pw.LinearGradient(
                    colors: [PdfColors.blue50, PdfColors.grey50],
                    begin: pw.Alignment.topLeft,
                    end: pw.Alignment.bottomRight,
                  ),
                  border: pw.Border.all(color: PdfColors.blue900, width: 2.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(vertical: 10),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue900,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'RESUMEN EJECUTIVO',
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildIndicadorMejorado(
                          'TOTAL\nSOLICITUDES',
                          _totalSolicitudes.toString(),
                          PdfColors.blue900,
                        ),
                        pw.Container(
                          width: 2,
                          height: 70,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue300,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1)),
                          ),
                        ),
                        _buildIndicadorMejorado(
                          'LÁMPARAS\nSOLICITADAS',
                          _totalLamparas.toString(),
                          PdfColors.orange700,
                        ),
                        pw.Container(
                          width: 2,
                          height: 70,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue300,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1)),
                          ),
                        ),
                        _buildIndicadorMejorado(
                          'BOMBILLOS\nSOLICITADOS',
                          _totalBombillos.toString(),
                          PdfColors.yellow700,
                        ),
                        pw.Container(
                          width: 2,
                          height: 70,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue300,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1)),
                          ),
                        ),
                        _buildIndicadorMejorado(
                          'LUMINARIAS\nENTREGADAS',
                          _totalEntregadas.toString(),
                          PdfColors.green700,
                        ),
                        pw.Container(
                          width: 2,
                          height: 70,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue300,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1)),
                          ),
                        ),
                        _buildIndicadorMejorado(
                          'PORCENTAJE\nDE AVANCE',
                          '$porcentajeAvance%',
                          double.parse(porcentajeAvance) >= 75
                              ? PdfColors.green700
                              : double.parse(porcentajeAvance) >= 50
                                  ? PdfColors.orange700
                                  : PdfColors.red700,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 25),
              
              // Tabla de balance detallado mejorada
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.only(bottom: 15),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 5,
                      height: 25,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Text(
                      'BALANCE DETALLADO DE LUMINARIAS',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue900, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Table(
                  border: pw.TableBorder(
                    left: const pw.BorderSide(color: PdfColors.blue900, width: 1.5),
                    right: const pw.BorderSide(color: PdfColors.blue900, width: 1.5),
                    top: const pw.BorderSide(color: PdfColors.blue900, width: 1.5),
                    bottom: const pw.BorderSide(color: PdfColors.blue900, width: 1.5),
                    horizontalInside: const pw.BorderSide(color: PdfColors.blue900, width: 1),
                    verticalInside: const pw.BorderSide(color: PdfColors.blue900, width: 1),
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    // Encabezado
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue900,
                        borderRadius: const pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(2),
                          topRight: pw.Radius.circular(2),
                        ),
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(16),
                          child: pw.Text(
                            'CONCEPTO',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(16),
                          child: pw.Text(
                            'CANTIDAD',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(16),
                          child: pw.Text(
                            'PORCENTAJE',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  // Filas de datos
                  _buildFilaInstitucional(
                    'Lámparas Solicitadas',
                    _totalLamparas,
                    _totalLuminarias > 0 
                        ? ((_totalLamparas / _totalLuminarias) * 100)
                        : 0.0,
                    PdfColors.orange50,
                  ),
                  _buildFilaInstitucional(
                    'Bombillos Solicitados',
                    _totalBombillos,
                    _totalLuminarias > 0 
                        ? ((_totalBombillos / _totalLuminarias) * 100)
                        : 0.0,
                    PdfColors.yellow50,
                  ),
                  _buildFilaInstitucional(
                    'Total Luminarias Solicitadas',
                    _totalLuminarias,
                    _totalLuminarias > 0 ? 100.0 : 0.0,
                    PdfColors.white,
                  ),
                  _buildFilaInstitucional(
                    'Lámparas Entregadas',
                    _lamparasEntregadas,
                    _totalLamparas > 0 
                        ? ((_lamparasEntregadas / _totalLamparas) * 100)
                        : 0.0,
                    PdfColors.green50,
                  ),
                  _buildFilaInstitucional(
                    'Lámparas Pendientes',
                    _lamparasPendientes,
                    _totalLamparas > 0 
                        ? ((_lamparasPendientes / _totalLamparas) * 100)
                        : 0.0,
                    PdfColors.red50,
                  ),
                  _buildFilaInstitucional(
                    'Bombillos Entregados',
                    _bombillosEntregados,
                    _totalBombillos > 0 
                        ? ((_bombillosEntregados / _totalBombillos) * 100)
                        : 0.0,
                    PdfColors.green50,
                  ),
                  _buildFilaInstitucional(
                    'Bombillos Pendientes',
                    _bombillosPendientes,
                    _totalBombillos > 0 
                        ? ((_bombillosPendientes / _totalBombillos) * 100)
                        : 0.0,
                    PdfColors.red50,
                  ),
                  _buildFilaInstitucional(
                    'Luminarias Entregadas',
                    _totalEntregadas,
                    _totalLuminarias > 0 
                        ? ((_totalEntregadas / _totalLuminarias) * 100)
                        : 0.0,
                    PdfColors.green50,
                  ),
                  _buildFilaInstitucional(
                    'Luminarias Pendientes',
                    _totalPendientes,
                    _totalLuminarias > 0 
                        ? ((_totalPendientes / _totalLuminarias) * 100)
                        : 0.0,
                    PdfColors.red50,
                  ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 30),
              
              // Tabla de desglose por tipo de luminaria
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.only(bottom: 15),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 5,
                      height: 25,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Text(
                      'DESGLOSE POR TIPO DE LUMINARIA',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue900, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Table(
                  border: pw.TableBorder(
                    left: const pw.BorderSide(color: PdfColors.blue900, width: 1.5),
                    right: const pw.BorderSide(color: PdfColors.blue900, width: 1.5),
                    top: const pw.BorderSide(color: PdfColors.blue900, width: 1.5),
                    bottom: const pw.BorderSide(color: PdfColors.blue900, width: 1.5),
                    horizontalInside: const pw.BorderSide(color: PdfColors.blue900, width: 1),
                    verticalInside: const pw.BorderSide(color: PdfColors.blue900, width: 1),
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.5),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    // Encabezado
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue900,
                        borderRadius: const pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(2),
                          topRight: pw.Radius.circular(2),
                        ),
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(16),
                          child: pw.Text(
                            'TIPO DE LUMINARIA',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(16),
                          child: pw.Text(
                            'CANTIDAD',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(16),
                          child: pw.Text(
                            'PORCENTAJE',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    // Filas de datos
                    _buildFilaInstitucional(
                      'Lámparas Solicitadas',
                      _totalLamparas,
                      _totalLuminarias > 0 
                          ? ((_totalLamparas / _totalLuminarias) * 100)
                          : 0.0,
                      PdfColors.orange50,
                    ),
                    _buildFilaInstitucional(
                      'Bombillos Solicitados',
                      _totalBombillos,
                      _totalLuminarias > 0 
                          ? ((_totalBombillos / _totalLuminarias) * 100)
                          : 0.0,
                      PdfColors.yellow50,
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 30),
              
              // Balance por comuna (solo en reporte municipal)
              if (_comunaFiltrada == null) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.only(bottom: 15),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 5,
                        height: 25,
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Text(
                        'DISTRIBUCIÓN POR COMUNAS',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                _buildTablaComunasInstitucional(),
                pw.SizedBox(height: 30),
              ],
              
              // Indicador de progreso mejorado
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.only(bottom: 15),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 5,
                      height: 25,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Text(
                      'PROGRESO DE EJECUCIÓN DEL PLAN',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue900, width: 2),
                  color: PdfColors.grey50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Estado de Ejecución:',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: double.parse(porcentajeAvance) >= 75
                                ? PdfColors.green700
                                : double.parse(porcentajeAvance) >= 50
                                    ? PdfColors.orange700
                                    : PdfColors.red700,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            '$porcentajeAvance%',
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 15),
                    pw.LayoutBuilder(
                      builder: (context, constraints) {
                        final maxWidth = constraints?.maxWidth ?? 500;
                        final progressWidth = _totalLuminarias > 0
                            ? (maxWidth * (_totalEntregadas / _totalLuminarias))
                            : 0.0;
                        
                        return pw.Container(
                          height: 32,
                          width: maxWidth,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.blue900, width: 1.5),
                            color: PdfColors.white,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Stack(
                            children: [
                              if (progressWidth > 0)
                                pw.Container(
                                  width: progressWidth,
                                  height: 32,
                                  decoration: pw.BoxDecoration(
                                    color: double.parse(porcentajeAvance) >= 75
                                        ? PdfColors.green700
                                        : double.parse(porcentajeAvance) >= 50
                                            ? PdfColors.orange700
                                            : PdfColors.red700,
                                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                                  ),
                                ),
                              pw.Center(
                                child: pw.Text(
                                  '${_totalEntregadas} de ${_totalLuminarias} luminarias entregadas',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 10,
                                    color: double.parse(porcentajeAvance) > 20
                                        ? PdfColors.black
                                        : PdfColors.grey800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Pendientes: ${_totalPendientes}',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                        pw.Text(
                          'Total: $_totalLuminarias',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 30),
              
              // Nota final mejorada
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  gradient: const pw.LinearGradient(
                    colors: [PdfColors.blue50, PdfColors.grey50],
                    begin: pw.Alignment.topLeft,
                    end: pw.Alignment.bottomRight,
                  ),
                  border: pw.Border.all(color: PdfColors.blue400, width: 1.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 4,
                          height: 20,
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          'NOTA IMPORTANTE',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Este documento ha sido generado automáticamente por el Sistema de Gestión Municipal - Sala Situacional. '
                      'Los datos presentados reflejan el estado actualizado al momento de su emisión y han sido verificados '
                      'según los registros oficiales del municipio.',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                        height: 1.4,
                      ),
                      textAlign: pw.TextAlign.justify,
                    ),
                  ],
                ),
              ),
            ];
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

  pw.Widget _buildIndicadorMejorado(String etiqueta, String valor, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: color, width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            etiqueta,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
              letterSpacing: 0.4,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              valor,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.TableRow _buildFilaInstitucional(
    String concepto,
    int cantidad,
    double porcentaje,
    PdfColor bgColor,
  ) {
    // Determinar color del texto según el concepto
    PdfColor textColor = PdfColors.grey800;
    if (concepto.contains('Entregadas')) {
      textColor = PdfColors.green800;
    } else if (concepto.contains('Pendientes')) {
      textColor = PdfColors.red800;
    } else if (concepto.contains('Solicitadas')) {
      textColor = PdfColors.orange800;
    }
    
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bgColor),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(14),
          child: pw.Row(
            children: [
              pw.Container(
                width: 4,
                height: 4,
                decoration: pw.BoxDecoration(
                  color: textColor,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Text(
                  concepto.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: textColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(14),
          child: pw.Text(
            cantidad.toString(),
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(14),
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: textColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              '${porcentaje.toStringAsFixed(1)}%',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTablaComunasInstitucional() {
    final estadisticasPorComuna = _calcularEstadisticasPorComuna();
    final comunasOrdenadas = estadisticasPorComuna.keys.toList()..sort();
    
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.blue900,
        width: 1.5,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(1),
      },
      children: [
        // Encabezado
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue900),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                'COMUNA',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                'LÁMPARAS',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                'BOMBILLOS',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                'TOTAL',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                'ENTREGADAS',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                'PENDIENTES',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                  letterSpacing: 0.5,
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
          
          final bgColor = index % 2 == 0 ? PdfColors.grey50 : PdfColors.white;
          
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bgColor),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(11),
                child: pw.Text(
                  comunaNombre.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.normal,
                    color: PdfColors.grey800,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(11),
                child: pw.Text(
                  stats['lamparas'].toString(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange700,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(11),
                child: pw.Text(
                  stats['bombillos'].toString(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.yellow700,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(11),
                child: pw.Text(
                  stats['solicitadas'].toString(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(11),
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
                padding: const pw.EdgeInsets.all(11),
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
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                'TOTAL GENERAL',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                _totalLamparas.toString(),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange700,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                _totalBombillos.toString(),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.yellow700,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                _totalLuminarias.toString(),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
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
              padding: const pw.EdgeInsets.all(12),
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

            // Tarjetas de estadísticas generales
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
            
            // Título de sección de desglose
            Text(
              "Desglose por Tipo de Luminaria",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            
            // Tarjetas de lámparas
            _buildEstadisticaCard(
              "Lámparas Solicitadas",
              _totalLamparas.toString(),
              Icons.lightbulb,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildEstadisticaCard(
              "Lámparas Entregadas",
              _lamparasEntregadas.toString(),
              Icons.check_circle,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildEstadisticaCard(
              "Lámparas Pendientes",
              _lamparasPendientes.toString(),
              Icons.pending,
              Colors.red,
            ),
            const SizedBox(height: 16),
            
            // Tarjetas de bombillos
            _buildEstadisticaCard(
              "Bombillos Solicitados",
              _totalBombillos.toString(),
              Icons.lightbulb_outline,
              Colors.amber,
            ),
            const SizedBox(height: 12),
            _buildEstadisticaCard(
              "Bombillos Entregados",
              _bombillosEntregados.toString(),
              Icons.check_circle,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildEstadisticaCard(
              "Bombillos Pendientes",
              _bombillosPendientes.toString(),
              Icons.pending,
              Colors.red,
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
    final maxValue = [
      _totalLamparas, _lamparasEntregadas, _lamparasPendientes,
      _totalBombillos, _bombillosEntregados, _bombillosPendientes
    ].reduce((a, b) => a > b ? a : b).toDouble();
    
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
                  "Comparativa de Lámparas y Bombillos",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 350,
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
                        reservedSize: 100,
                        getTitlesWidget: (value, meta) {
                          String label;
                          int cantidad;
                          Color color;
                          
                          switch (value.toInt()) {
                            case 0:
                              label = 'Lámparas\nSolicitadas';
                              cantidad = _totalLamparas;
                              color = Colors.orange;
                              break;
                            case 1:
                              label = 'Lámparas\nEntregadas';
                              cantidad = _lamparasEntregadas;
                              color = Colors.green;
                              break;
                            case 2:
                              label = 'Lámparas\nPendientes';
                              cantidad = _lamparasPendientes;
                              color = Colors.red;
                              break;
                            case 3:
                              label = 'Bombillos\nSolicitados';
                              cantidad = _totalBombillos;
                              color = Colors.amber;
                              break;
                            case 4:
                              label = 'Bombillos\nEntregados';
                              cantidad = _bombillosEntregados;
                              color = Colors.green;
                              break;
                            case 5:
                              label = 'Bombillos\nPendientes';
                              cantidad = _bombillosPendientes;
                              color = Colors.red;
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
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
                    // Lámparas solicitadas
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: _totalLamparas.toDouble(),
                          gradient: LinearGradient(
                            colors: [Colors.orange, Colors.orange.withOpacity(0.7)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 40,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    // Lámparas entregadas
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: _lamparasEntregadas.toDouble(),
                          gradient: LinearGradient(
                            colors: [Colors.green, Colors.green.withOpacity(0.7)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 40,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    // Lámparas pendientes
                    BarChartGroupData(
                      x: 2,
                      barRods: [
                        BarChartRodData(
                          toY: _lamparasPendientes.toDouble(),
                          gradient: LinearGradient(
                            colors: [Colors.red, Colors.red.withOpacity(0.7)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 40,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    // Bombillos solicitados
                    BarChartGroupData(
                      x: 3,
                      barRods: [
                        BarChartRodData(
                          toY: _totalBombillos.toDouble(),
                          gradient: LinearGradient(
                            colors: [Colors.amber, Colors.amber.withOpacity(0.7)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 40,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    // Bombillos entregados
                    BarChartGroupData(
                      x: 4,
                      barRods: [
                        BarChartRodData(
                          toY: _bombillosEntregados.toDouble(),
                          gradient: LinearGradient(
                            colors: [Colors.green, Colors.green.withOpacity(0.7)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 40,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    // Bombillos pendientes
                    BarChartGroupData(
                      x: 5,
                      barRods: [
                        BarChartRodData(
                          toY: _bombillosPendientes.toDouble(),
                          gradient: LinearGradient(
                            colors: [Colors.red, Colors.red.withOpacity(0.7)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 40,
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
