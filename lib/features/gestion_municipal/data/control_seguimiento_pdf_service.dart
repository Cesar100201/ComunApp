import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'control_seguimiento_model.dart';
import 'medios_verificacion_service.dart';
import 'informe_constants.dart';

/// Formato carta horizontal (11" x 8.5").
const PdfPageFormat _cartaHorizontal = PdfPageFormat(792, 612);

/// Miniatura memoria fotográfica: relación 4:3 para que la foto se vea entera (BoxFit.contain).
const double _fotoWidth = 64;
const double _fotoHeight = 48;

/// Tipografía y espaciado optimizados para lectura e impresión.
const double _fontSizeHeader = 10;
const double _fontSizeCell = 9;
const double _fontSizePageTitle = 15;
const double _fontSizePageSub = 11;
const double _fontSizeFooter = 10;
const double _cellPaddingV = 3;
const double _cellPaddingH = 4;
const double _marginPage = 20;

/// Colores del informe (paleta consistente).
const PdfColor _colorHeaderBg = PdfColors.blue900;
const PdfColor _colorHeaderText = PdfColors.white;
const PdfColor _colorBorder = PdfColors.blue800;
const PdfColor _colorBorderLight = PdfColors.blue100;
const PdfColor _colorText = PdfColors.grey800;
const PdfColor _colorTextMuted = PdfColors.grey600;
const PdfColor _colorSuccess = PdfColor.fromInt(0xFFE8F5E9);  // Verde muy suave
const PdfColor _colorWarning = PdfColor.fromInt(0xFFFFF8E1);  // Ámbar muy suave

/// Servicio para generar el PDF del informe de Control y Seguimiento.
/// Reporte profesional, compacto y fácil de leer para presentación semanal.
class ControlSeguimientoPdfService {
  ControlSeguimientoPdfService();

  final MediosVerificacionService _mediosService = MediosVerificacionService();

  static String mediosVerificacionTexto(ControlSeguimiento r) {
    final partes = <String>[];
    if (r.memoriaFotografica.isNotEmpty) partes.add('Memoria fotográfica');
    if (r.actasPdfs.isNotEmpty) partes.add('Actas');
    if (r.listasAsistenciaFotos.isNotEmpty || r.listasAsistenciaPdfs.isNotEmpty) {
      partes.add('Planillas de asistencia');
    }
    if (partes.isEmpty) return '—';
    return partes.join(', ');
  }

  Future<pw.Document> buildDocument({
    required List<ControlSeguimiento> registros,
    required DateTime inicio,
    required DateTime fin,
    required String categoria,
    required bool esSemanal,
    String? responsable,
    String? cedula,
  }) async {
    final responsableFinal = responsable ?? InformeConstants.responsableInforme;
    final cedulaFinal = cedula;
    final fmt = DateFormat('dd/MM/yyyy');
    final strInicio = fmt.format(inicio);
    final strFin = fmt.format(fin);
    final totalActividades = registros.length;
    final nCulminadas = registros.where((r) => r.estatus.toLowerCase().contains('culminado')).length;
    final nEnProceso = totalActividades - nCulminadas;

    final titulo = esSemanal
        ? 'INFORME DE GESTIÓN SEMANAL'
        : 'INFORME DE ACTIVIDADES';
    final rangoTexto = esSemanal
        ? 'Semana: $strInicio  al  $strFin'
        : 'Del $strInicio  al  $strFin';

    // Fila de encabezado de columnas (se repetirá en cada página vía header de MultiPage)
    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: _colorHeaderBg),
      children: [
        _cellHeader('N°'),
        _cellHeader('Fecha'),
        _cellHeader('Actividad'),
        _cellHeader('Objetivo'),
        _cellHeader('Acciones'),
        _cellHeader('Plan de la Patria'),
        _cellHeader('Plan de Gestión Municipal'),
        _cellHeader('Producto'),
        _cellHeader('Estatus'),
        _cellHeader('Med. verif.'),
        _cellHeader('Memoria fotográfica'),
      ],
    );

    final tableRows = <pw.TableRow>[];

    int index = 0;
    for (final r in registros) {
      final fotoCell = await _buildMemoriaFotograficaCell(r);
      final isEven = index.isEven;
      final estatusCell = _cellEstatus(r.estatus);
      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isEven ? PdfColors.white : PdfColors.grey50,
          ),
          children: [
            _cellText('${index + 1}', center: true),
            _cellText(fmt.format(r.fecha), center: true),
            _cellText(r.nombreActividad.isNotEmpty ? r.nombreActividad : '—'),
            _cellText(r.objetivo),
            _cellText(r.acciones),
            _cellText(r.transformacion7T),
            _cellText(r.planGobierno2025),
            _cellText(r.producto),
            estatusCell,
            _cellText(mediosVerificacionTexto(r)),
            fotoCell,
          ],
        ),
      );
      index++;
    }

    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(20),
      1: const pw.FixedColumnWidth(54),
      2: const pw.FlexColumnWidth(1.25),
      3: const pw.FlexColumnWidth(1.75),
      4: const pw.FlexColumnWidth(1.75),
      5: const pw.FlexColumnWidth(1.05),
      6: const pw.FlexColumnWidth(1.05),
      7: const pw.FlexColumnWidth(1.2),
      8: const pw.FixedColumnWidth(56),
      9: const pw.FlexColumnWidth(1.05),
      10: const pw.FixedColumnWidth(_fotoWidth + 10),
    };
    const tableBorder = pw.TableBorder(
      left: pw.BorderSide(color: _colorBorder, width: 0.6),
      top: pw.BorderSide(color: _colorBorder, width: 0.6),
      right: pw.BorderSide(color: _colorBorder, width: 0.6),
      bottom: pw.BorderSide(color: _colorBorder, width: 0.6),
      horizontalInside: pw.BorderSide(color: _colorBorderLight, width: 0.35),
      verticalInside: pw.BorderSide(color: _colorBorderLight, width: 0.35),
    );

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: _cartaHorizontal,
        margin: const pw.EdgeInsets.all(_marginPage),
        header: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            _buildHeader(
              titulo: titulo,
              rangoTexto: rangoTexto,
              categoria: categoria,
              totalActividades: totalActividades,
              nCulminadas: nCulminadas,
              nEnProceso: nEnProceso,
            ),
            pw.Table(
              border: tableBorder,
              columnWidths: columnWidths,
              children: [headerRow],
            ),
          ],
        ),
        footer: (pw.Context context) => _buildFooter(
          context: context,
          responsable: responsableFinal,
          cedula: cedulaFinal,
        ),
        build: (pw.Context context) => [
          pw.Table(
            border: tableBorder,
            columnWidths: columnWidths,
            children: tableRows,
          ),
        ],
      ),
    );
    return doc;
  }

  pw.Widget _buildHeader({
    required String titulo,
    required String rangoTexto,
    required String categoria,
    required int totalActividades,
    required int nCulminadas,
    required int nEnProceso,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          decoration: const pw.BoxDecoration(color: _colorHeaderBg),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                InformeConstants.enteRectorReporte,
                style: const pw.TextStyle(
                  fontSize: _fontSizePageSub - 1,
                  color: _colorHeaderText,
                ),
              ),
              pw.Text(
                'Total: $totalActividades actividad${totalActividades == 1 ? '' : 'es'}',
                style: pw.TextStyle(
                  fontSize: _fontSizePageSub - 1,
                  color: _colorHeaderText,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          titulo,
          style: pw.TextStyle(
            fontSize: _fontSizePageTitle,
            fontWeight: pw.FontWeight.bold,
            color: _colorHeaderBg,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Row(
          children: [
            pw.Text(
              rangoTexto,
              style: const pw.TextStyle(
                fontSize: _fontSizePageSub - 1,
                color: _colorText,
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Text(
              'Categoría: ',
              style: const pw.TextStyle(
                fontSize: _fontSizePageSub - 1,
                color: _colorTextMuted,
              ),
            ),
            pw.Text(
              categoria,
              style: pw.TextStyle(
                fontSize: _fontSizePageSub - 1,
                fontWeight: pw.FontWeight.bold,
                color: _colorHeaderBg,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Culminadas: $nCulminadas · En proceso: $nEnProceso',
          style: const pw.TextStyle(
            fontSize: _fontSizePageSub - 2,
            color: _colorTextMuted,
          ),
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildFooter({
    required pw.Context context,
    required String responsable,
    String? cedula,
  }) {
    final pageNum = context.pageNumber;
    final pageCount = context.pagesCount;
    final pageLabel = pageCount > 0 && pageCount >= pageNum
        ? 'Página $pageNum de $pageCount'
        : 'Página $pageNum';
    final cedulaTexto = (cedula != null && cedula.isNotEmpty) ? 'C.I. $cedula' : '—';
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(thickness: 0.6, color: _colorBorder),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    'Responsable: $responsable',
                    style: const pw.TextStyle(
                      fontSize: _fontSizeFooter - 1,
                      color: _colorText,
                    ),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    cedulaTexto,
                    style: const pw.TextStyle(
                      fontSize: _fontSizeFooter - 1,
                      color: _colorText,
                    ),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'INPREABOGADO: 182.045',
                    style: const pw.TextStyle(
                      fontSize: _fontSizeFooter - 1,
                      color: _colorText,
                    ),
                  ),
                ],
              ),
            ),
            pw.Text(
              pageLabel,
              style: const pw.TextStyle(
                fontSize: _fontSizeFooter - 1,
                color: _colorTextMuted,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Firma: _________________________',
          style: const pw.TextStyle(
            fontSize: _fontSizeFooter - 1,
            color: _colorTextMuted,
          ),
        ),
      ],
    );
  }

  pw.Widget _cellHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: _cellPaddingH,
        vertical: _cellPaddingV + 2,
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: _fontSizeHeader,
          fontWeight: pw.FontWeight.bold,
          color: _colorHeaderText,
        ),
      ),
    );
  }

  pw.Widget _cellText(String text, {bool center = false}) {
    final safe = text.trim().isEmpty ? '—' : text;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: _cellPaddingH,
        vertical: _cellPaddingV,
      ),
      child: pw.Align(
        alignment: center ? pw.Alignment.center : pw.Alignment.topLeft,
        child: pw.Text(
          safe,
          style: const pw.TextStyle(
            fontSize: _fontSizeCell,
            color: _colorText,
          ),
        ),
      ),
    );
  }

  pw.Widget _cellEstatus(String estatus) {
    final isCulminado = estatus.toLowerCase().contains('culminado');
    final bg = isCulminado ? _colorSuccess : _colorWarning;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: _cellPaddingH,
        vertical: _cellPaddingV,
      ),
      color: bg,
      alignment: pw.Alignment.center,
      child: pw.Text(
        estatus.isEmpty ? '—' : estatus,
        style: pw.TextStyle(
          fontSize: _fontSizeCell,
          color: _colorText,
          fontWeight: pw.FontWeight.normal,
        ),
      ),
    );
  }

  Future<pw.Widget> _buildMemoriaFotograficaCell(ControlSeguimiento r) async {
    if (r.memoriaFotografica.isEmpty) {
      return _celdaSinFoto();
    }
    try {
      final path = await _mediosService.resolvePath(r.memoriaFotografica.first);
      final file = File(path);
      if (!await file.exists()) return _celdaSinFoto();
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return _celdaSinFoto();
      final image = pw.MemoryImage(bytes);
      return pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Center(
          child: pw.Container(
            width: _fotoWidth,
            height: _fotoHeight,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: _colorBorderLight, width: 1),
            ),
            child: pw.ClipRect(
              child: pw.Image(
                image,
                width: _fotoWidth,
                height: _fotoHeight,
                fit: pw.BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      return _celdaSinFoto();
    }
  }

  pw.Widget _celdaSinFoto() {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Center(
        child: pw.Container(
          width: _fotoWidth,
          height: _fotoHeight,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: _colorBorderLight, width: 0.8),
          ),
          child: pw.Text(
            'Sin foto',
            style: const pw.TextStyle(
              fontSize: _fontSizeCell - 1,
              color: _colorTextMuted,
            ),
          ),
        ),
      ),
    );
  }
}
