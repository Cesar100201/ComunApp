import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../database/db_helper.dart';
import '../../../../models/models.dart';
import '../../inhabitants/data/repositories/habitante_repository.dart';
import '../../home/presentation/home_page.dart';
import '../../inhabitants/presentation/add_habitante_page.dart';

/// Flujo post-login: valida si existe habitante con la cédula (solo Isar).
/// Si existe y no está eliminado → vincula y va a Home.
/// Si no existe → sincronización rápida; si falla → alerta y cierra sesión; si ok → formulario mínimo de habitante.
class CedulaValidationFlowPage extends StatefulWidget {
  /// Si viene del registro, la cédula ya fue ingresada.
  final int? initialCedula;
  final VoidCallback? onSettingsChanged;

  const CedulaValidationFlowPage({
    super.key,
    this.initialCedula,
    this.onSettingsChanged,
  });

  @override
  State<CedulaValidationFlowPage> createState() =>
      _CedulaValidationFlowPageState();
}

class _CedulaValidationFlowPageState extends State<CedulaValidationFlowPage> {
  final _cedulaController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _showCedulaForm = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCedula != null) {
      _cedulaController.text = widget.initialCedula.toString();
      _runValidation(widget.initialCedula!);
    } else {
      setState(() => _showCedulaForm = true);
    }
  }

  @override
  void dispose() {
    _cedulaController.dispose();
    super.dispose();
  }

  Future<void> _runValidation(int cedula) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _showCedulaForm = false;
    });

    try {
      final isar = await DbHelper().db;
      final repo = HabitanteRepository(isar);
      final h = await repo.getHabitanteByCedula(cedula);

      if (!mounted) return;
      if (h != null && !h.isDeleted) {
        await SettingsService.setLinkedHabitanteCedula(uid, cedula);
        if (!mounted) return;
        _navigateToHome();
        return;
      }

      // 1. Buscar en Firebase
      setState(() => _error = null);
      final firestore = FirebaseFirestore.instance;
      print('Buscando cédula en Firestore: $cedula');

      final querySnapshot = await firestore
          .collection('habitantes')
          .where('cedula', isEqualTo: cedula)
          .limit(1)
          .get();

      print(
        'Resultados encontrados en Firestore: ${querySnapshot.docs.length}',
      );

      if (querySnapshot.docs.isNotEmpty) {
        // Existe en Firebase -> descargar este documento específico e insertarlo localmente
        print('Habitante encontrado en remoto. Insertando en BD local...');
        final doc = querySnapshot.docs.first;
        final data = doc.data();

        // Convertir y guardar en local
        final nuevoHabitante = Habitante()
          ..cedula = cedula
          ..nombreCompleto = data['nombreCompleto'] ?? 'Desconocido'
          ..telefono = data['telefono'] ?? ''
          ..nacionalidad = Nacionalidad.values.firstWhere(
            (e) => e.name == data['nacionalidad'],
            orElse: () => Nacionalidad.V,
          )
          ..genero = Genero.values.firstWhere(
            (e) => e.name == data['genero'],
            orElse: () => Genero.Masculino,
          )
          ..fechaNacimiento = data['fechaNacimiento'] != null
              ? (data['fechaNacimiento'] as Timestamp).toDate()
              : DateTime(1990, 1, 1)
          ..direccion = data['direccion'] ?? ''
          ..estatusPolitico = EstatusPolitico.values.firstWhere(
            (e) => e.name == data['estatusPolitico'],
            orElse: () => EstatusPolitico.Neutral,
          )
          ..nivelVoto = NivelVoto.values.firstWhere(
            (e) => e.name == data['nivelVoto'],
            orElse: () => NivelVoto.Blando,
          )
          ..nivelUsuario = data['nivelUsuario'] ?? 3
          ..fotoUrl = data['fotoUrl']
          ..isSynced = true;

        if (!mounted) return;
        await repo.guardarHabitante(nuevoHabitante);
        print('Habitante guardado localmente: ${nuevoHabitante.id}');

        await SettingsService.setLinkedHabitanteCedula(uid, cedula);
        if (!mounted) return;
        _navigateToHome();
        return;
      }

      // 2. No existe en Firebase ni local -> Alerta y Redirigir a AddHabitantePage
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Habitante no registrado',
            style: TextStyle(color: AppColors.error),
          ),
          content: const Text(
            'El número de cédula ingresado no se encuentra en nuestra base de datos. Por favor, complete el registro correspondiente.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddHabitantePage(initialCedula: cedula),
        ),
      );

      // Al regresar, mostramos la forma de nuevo para que avance o intente otra vez
      if (mounted) {
        setState(() {
          _loading = false;
          _showCedulaForm = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
          _showCedulaForm = true;
        });
      }
    }
  }

  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) =>
            HomePage(onSettingsChanged: widget.onSettingsChanged),
      ),
      (route) => false,
    );
  }

  void _onSubmitCedula() {
    final raw = _cedulaController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    final cedula = int.tryParse(raw);
    if (cedula == null || cedula <= 0) {
      setState(() => _error = 'Ingrese un número de cédula válido.');
      return;
    }
    _runValidation(cedula);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vinculación de cuenta')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text('Validando...'),
            ],
          ),
        ),
      );
    }

    if (_showCedulaForm) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vincular cuenta')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Para vincular su cuenta, ingrese su número de cédula.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _cedulaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cédula',
                  hintText: 'Ej. 12345678',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                onSubmitted: (_) => _onSubmitCedula(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 14),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _onSubmitCedula,
                child: const Text('Continuar'),
              ),
            ],
          ),
        ),
      );
    }

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
