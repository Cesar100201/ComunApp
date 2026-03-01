import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/settings_service.dart';
import '../data/formacion_models.dart';
import '../data/formacion_service.dart';
import 'formacion_group_detail_page.dart';

/// Lista de grupos del usuario (donde es dueño o participante).
class FormacionGroupsListPage extends StatefulWidget {
  const FormacionGroupsListPage({super.key});

  @override
  State<FormacionGroupsListPage> createState() =>
      _FormacionGroupsListPageState();
}

class _FormacionGroupsListPageState extends State<FormacionGroupsListPage> {
  final FormacionService _service = FormacionService();
  bool _loading = true;
  String? _error;
  List<FormacionGroup> _groups = [];
  int? _currentCedula;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final cedula = uid != null
        ? await SettingsService.getLinkedHabitanteCedula(uid)
        : null;
    if (uid == null || cedula == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Debe tener la cédula asociada.';
        });
      }
      return;
    }
    try {
      final list = await _service.getMyGroups(uid: uid, cedula: cedula);
      if (mounted) {
        setState(() {
          _groups = list;
          _currentCedula = cedula;
          _loading = false;
        });
      }
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
      appBar: AppBar(title: const Text('Mis grupos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : _groups.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      size: 64,
                      color: AppModulePastel.formacionAccent.withValues(
                        alpha: 0.7,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aún no estás en ningún grupo.',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Crea uno o únete con un código.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _groups.length,
                itemBuilder: (context, index) {
                  final g = _groups[index];
                  final isOwner =
                      g.ownerUid == FirebaseAuth.instance.currentUser?.uid;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppModulePastel.formacion.withValues(
                          alpha: 0.5,
                        ),
                        child: Icon(
                          isOwner ? Icons.person_rounded : Icons.school_rounded,
                          color: AppModulePastel.formacionAccent,
                        ),
                      ),
                      title: Text(g.name),
                      subtitle: Text(
                        isOwner ? 'Eres el responsable' : 'Participante',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        final cedula = _currentCedula;
                        if (cedula == null) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FormacionGroupDetailPage(
                              group: g,
                              currentCedula: cedula,
                            ),
                          ),
                        ).then((_) => _load());
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
