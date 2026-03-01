import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/constants.dart';
import '../../../../database/db_helper.dart';
import '../../../../models/models.dart';
import '../../inhabitants/data/repositories/habitante_repository.dart';

/// Formulario mínimo para registrar un habitante (flujo post-login cuando no existe en BD).
/// Campos: cédula (fija), nombre, teléfono, fecha nacimiento, género, dirección, comuna, consejo comunal.
/// Al guardar: guardar en Isar, vincular cédula al uid y pop(true).
class MinimalHabitanteRegisterPage extends StatefulWidget {
  final int cedula;
  final String uid;

  const MinimalHabitanteRegisterPage({
    super.key,
    required this.cedula,
    required this.uid,
  });

  @override
  State<MinimalHabitanteRegisterPage> createState() => _MinimalHabitanteRegisterPageState();
}

class _MinimalHabitanteRegisterPageState extends State<MinimalHabitanteRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  DateTime _fechaNacimiento = AppConstants.defaultBirthDate;
  Genero _genero = Genero.Masculino;
  List<Comuna> _comunas = [];
  List<ConsejoComunal> _consejosComunales = [];
  Comuna? _selectedComuna;
  ConsejoComunal? _selectedConsejo;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadComunasAndConsejos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  Future<void> _loadComunasAndConsejos() async {
    try {
      final isar = await DbHelper().db;
      final comunasRaw = await isar.comunas.buildQuery<Comuna>().findAll();
      _comunas = comunasRaw.where((c) => !c.isDeleted).toList();
      final consejosRaw = await isar.consejoComunals.buildQuery<ConsejoComunal>().findAll();
      _consejosComunales = consejosRaw.where((c) => !c.isDeleted).toList();
      for (final c in _consejosComunales) {
        await c.comuna.load();
      }
      if (mounted) {
        setState(() {
        _loading = false;
        if (_comunas.isEmpty && _consejosComunales.isEmpty) _loadError = 'No hay comunas ni consejos. Debe sincronizar primero.';
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _loading = false;
        _loadError = e.toString();
      });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _fechaNacimiento = picked);
  }

  List<ConsejoComunal> get _consejosForSelectedComuna {
    if (_selectedComuna == null) return _consejosComunales;
    return _consejosComunales.where((c) {
      final comunaLink = c.comuna.value;
      return comunaLink?.id == _selectedComuna!.id;
    }).toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedConsejo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un consejo comunal'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final h = Habitante()
        ..cedula = widget.cedula
        ..nacionalidad = Nacionalidad.V
        ..nombreCompleto = _nombreController.text.trim()
        ..telefono = _telefonoController.text.trim()
        ..fechaNacimiento = _fechaNacimiento
        ..genero = _genero
        ..direccion = _direccionController.text.trim()
        ..estatusPolitico = EstatusPolitico.Neutral
        ..nivelVoto = NivelVoto.Blando
        ..nivelUsuario = AppConstants.nivelInvitado
        ..isSynced = false
        ..isDeleted = false;

      h.consejoComunal.value = _selectedConsejo;

      final isar = await DbHelper().db;
      final repo = HabitanteRepository(isar);
      await repo.guardarHabitante(h);
      await SettingsService.setLinkedHabitanteCedula(widget.uid, widget.cedula);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Registro mínimo')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Registro mínimo')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Completar datos')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              initialValue: widget.cedula.toString(),
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Cédula',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombreController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre completo *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _telefonoController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Teléfono *',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Fecha de nacimiento *'),
              subtitle: Text(
                '${_fechaNacimiento.day}/${_fechaNacimiento.month}/${_fechaNacimiento.year}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Genero>(
              initialValue: _genero,
              decoration: const InputDecoration(
                labelText: 'Género *',
                prefixIcon: Icon(Icons.wc),
              ),
              items: Genero.values.map((g) {
                return DropdownMenuItem(
                  value: g,
                  child: Text(g.name),
                );
              }).toList(),
              onChanged: (v) => setState(() => _genero = v ?? _genero),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _direccionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Dirección *',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Comuna>(
              initialValue: _selectedComuna,
              decoration: const InputDecoration(
                labelText: 'Comuna *',
                prefixIcon: Icon(Icons.location_city),
              ),
              items: _comunas.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Text(c.nombreComuna),
                );
              }).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedComuna = v;
                  _selectedConsejo = null;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ConsejoComunal>(
              initialValue: _selectedConsejo,
              decoration: const InputDecoration(
                labelText: 'Consejo comunal *',
                prefixIcon: Icon(Icons.groups),
              ),
              items: _consejosForSelectedComuna.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Text(c.nombreConsejo),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedConsejo = v),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar y continuar'),
            ),
          ],
        ),
      ),
    );
  }
}
