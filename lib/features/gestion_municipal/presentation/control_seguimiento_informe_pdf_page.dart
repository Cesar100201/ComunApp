import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:goblafria/core/theme/app_theme.dart';
import 'package:goblafria/core/services/settings_service.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../data/control_seguimiento_model.dart';
import '../data/control_seguimiento_pdf_service.dart';
import '../data/repositories/control_seguimiento_repository.dart';

/// Tipo de periodo para el informe.
enum PeriodoInforme { estaSemana, ultimaSemana, ultimoMes, ultimosTresMeses }

extension PeriodoInformeExt on PeriodoInforme {
  String get label {
    switch (this) {
      case PeriodoInforme.estaSemana:
        return 'Esta semana';
      case PeriodoInforme.ultimaSemana:
        return 'Última semana';
      case PeriodoInforme.ultimoMes:
        return 'Último mes';
      case PeriodoInforme.ultimosTresMeses:
        return 'Últimos 3 meses';
    }
  }

  (DateTime inicio, DateTime fin, bool esSemanal) get rango {
    final now = DateTime.now();
    switch (this) {
      case PeriodoInforme.estaSemana:
        final (inicio, fin) = ControlSeguimiento.rangoSemanaPara(now);
        return (inicio, fin, true);
      case PeriodoInforme.ultimaSemana:
        final (inicio, fin) = ControlSeguimiento.rangoSemanaPara(
          now.subtract(const Duration(days: 7)),
        );
        return (inicio, fin, true);
      case PeriodoInforme.ultimoMes:
        final fin = DateTime(now.year, now.month, now.day);
        final inicio = fin.subtract(const Duration(days: 30));
        return (inicio, fin, false);
      case PeriodoInforme.ultimosTresMeses:
        final fin = DateTime(now.year, now.month, now.day);
        final inicio = fin.subtract(const Duration(days: 90));
        return (inicio, fin, false);
    }
  }
}

/// Pantalla para seleccionar el periodo y generar los PDFs del informe de Control y Seguimiento.
class ControlSeguimientoInformePdfPage extends StatefulWidget {
  const ControlSeguimientoInformePdfPage({super.key});

  @override
  State<ControlSeguimientoInformePdfPage> createState() =>
      _ControlSeguimientoInformePdfPageState();
}

class _ControlSeguimientoInformePdfPageState
    extends State<ControlSeguimientoInformePdfPage> {
  final ControlSeguimientoRepository _repo = ControlSeguimientoRepository();
  final ControlSeguimientoPdfService _pdfService =
      ControlSeguimientoPdfService();

  PeriodoInforme _periodo = PeriodoInforme.estaSemana;
  bool _isGenerating = false;

  Future<void> _generarPdfs() async {
    setState(() => _isGenerating = true);
    try {
      final (inicio, fin, esSemanal) = _periodo.rango;
      final registros = await _repo.getByRangoFechas(inicio, fin);
      if (registros.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay actividades en el periodo seleccionado.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      // Agrupar por categoría (solo categorías con datos).
      final porCategoria = <String, List<ControlSeguimiento>>{};
      for (final r in registros) {
        porCategoria.putIfAbsent(r.categoria, () => []).add(r);
      }
      // Ordenar cada lista por fecha desc.
      for (final list in porCategoria.values) {
        list.sort((a, b) => b.fecha.compareTo(a.fecha));
      }

      final categoriasConDatos = porCategoria.keys.toList();
      categoriasConDatos.sort();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      final cedula = uid != null
          ? await SettingsService.getLinkedHabitanteCedula(uid)
          : null;
      final cedulaStr = cedula?.toString();

      if (categoriasConDatos.length == 1) {
        final categoria = categoriasConDatos.first;
        final doc = await _pdfService.buildDocument(
          registros: porCategoria[categoria]!,
          inicio: inicio,
          fin: fin,
          categoria: categoria,
          esSemanal: esSemanal,
          cedula: cedulaStr,
        );
        if (mounted) {
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => doc.save(),
            name: 'Informe_$categoria.pdf',
            format: PdfPageFormat.letter.landscape,
          );
        }
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF generado correctamente'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          await _mostrarDialogoPdfsGenerados(
            categorias: categoriasConDatos,
            porCategoria: porCategoria,
            inicio: inicio,
            fin: fin,
            esSemanal: esSemanal,
            cedula: cedulaStr,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _mostrarDialogoPdfsGenerados({
    required List<String> categorias,
    required Map<String, List<ControlSeguimiento>> porCategoria,
    required DateTime inicio,
    required DateTime fin,
    required bool esSemanal,
    String? cedula,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Informes generados'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se generó un PDF por cada categoría con actividades en el periodo seleccionado.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ...categorias.map(
                (cat) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final doc = await _pdfService.buildDocument(
                        registros: porCategoria[cat]!,
                        inicio: inicio,
                        fin: fin,
                        categoria: cat,
                        esSemanal: esSemanal,
                        cedula: cedula,
                      );
                      if (mounted) {
                        await Printing.layoutPdf(
                          onLayout: (PdfPageFormat format) async => doc.save(),
                          name: 'Informe_$cat.pdf',
                          format: PdfPageFormat.letter.landscape,
                        );
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text('Ver informe: $cat'),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppModulePastel.gestionMunicipalAccent;

    return Scaffold(
      appBar: AppBar(title: const Text('Informe PDF - Control y Seguimiento')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informe de actividades',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Se generará un PDF por cada categoría que tenga actividades en el periodo seleccionado.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Periodo',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PeriodoInforme.values.map((p) {
              final selected = _periodo == p;
              return FilterChip(
                label: Text(p.label),
                selected: selected,
                onSelected: (v) {
                  if (v) setState(() => _periodo = p);
                },
                selectedColor: AppModulePastel.gestionMunicipal.withValues(
                  alpha: 0.4,
                ),
                checkmarkColor: accent,
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generarPdfs,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(_isGenerating ? 'Generando…' : 'Generar PDFs'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
