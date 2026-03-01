import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/settings_service.dart';
import '../data/formacion_service.dart';
import 'formacion_group_detail_page.dart';

/// Unirse a un grupo con código de invitación.
class FormacionJoinGroupPage extends StatefulWidget {
  const FormacionJoinGroupPage({super.key});

  @override
  State<FormacionJoinGroupPage> createState() => _FormacionJoinGroupPageState();
}

class _FormacionJoinGroupPageState extends State<FormacionJoinGroupPage> {
  final FormacionService _service = FormacionService();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
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
      _loading = true;
    });
    try {
      final group = await _service.joinGroupByCode(
        code: _codeController.text,
        cedula: cedula,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Te uniste al grupo correctamente.'),
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
        _loading = false;
      });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unirse con código')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ingrese el código de invitación que le hayan compartido.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Código',
                hintText: 'Ej: ABC123',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
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
              onPressed: _loading ? null : _join,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Unirse al grupo'),
            ),
          ],
        ),
      ),
    );
  }
}
