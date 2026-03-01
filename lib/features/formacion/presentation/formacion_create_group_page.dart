import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/settings_service.dart';
import '../data/formacion_service.dart';
import 'formacion_group_detail_page.dart';

/// Crear un nuevo grupo de Formación.
class FormacionCreateGroupPage extends StatefulWidget {
  const FormacionCreateGroupPage({super.key});

  @override
  State<FormacionCreateGroupPage> createState() => _FormacionCreateGroupPageState();
}

class _FormacionCreateGroupPageState extends State<FormacionCreateGroupPage> {
  final FormacionService _service = FormacionService();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escriba el nombre del grupo.');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _error = 'Debe iniciar sesión.');
      return;
    }
    final cedula = await SettingsService.getLinkedHabitanteCedula(uid);
    if (cedula == null) {
      setState(() => _error = 'Debe tener la cédula asociada en Perfil.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final group = await _service.createGroup(
        name: name,
        description: _descriptionController.text.trim(),
        ownerUid: uid,
        ownerCedula: cedula,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Grupo creado. Código: ${group.inviteCode}'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => FormacionGroupDetailPage(
            group: group,
            currentCedula: cedula,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear grupo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del grupo',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _create,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crear grupo'),
            ),
          ],
        ),
      ),
    );
  }
}
