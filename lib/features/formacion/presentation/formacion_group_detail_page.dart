import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/formacion_models.dart';
import '../data/formacion_service.dart';
import 'formacion_create_section_page.dart';
import 'formacion_edit_section_page.dart';
import 'formacion_error_helper.dart';
import 'formacion_section_detail_page.dart';

/// Detalle de un grupo: secciones (materias). Cada sección contiene las actividades.
/// El dueño puede crear secciones.
class FormacionGroupDetailPage extends StatefulWidget {
  const FormacionGroupDetailPage({
    super.key,
    required this.group,
    required this.currentCedula,
  });

  final FormacionGroup group;
  final int currentCedula;

  @override
  State<FormacionGroupDetailPage> createState() => _FormacionGroupDetailPageState();
}

class _FormacionGroupDetailPageState extends State<FormacionGroupDetailPage> {
  final FormacionService _service = FormacionService();
  bool _loading = true;
  String? _error;
  List<FormacionSection> _sections = [];

  FormacionGroup get group => widget.group;
  int get currentCedula => widget.currentCedula;
  bool get isOwner => group.ownerUid == FirebaseAuth.instance.currentUser?.uid;

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
    try {
      final list = await _service.getSectionsByGroup(group.id);
      if (mounted) {
        setState(() {
          _sections = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final err = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _error = err;
          _loading = false;
        });
        showFormacionErrorAlert(context, error: err, onRetry: _load);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Crear materia',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FormacionCreateSectionPage(
                      group: group,
                      currentCedula: currentCedula,
                    ),
                  ),
                );
                _load();
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (group.description.isNotEmpty) ...[
                Text(
                  group.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
              ],
              if (isOwner) ...[
                Card(
                  color: AppModulePastel.formacion.withValues(alpha: 0.2),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded, color: AppModulePastel.formacionAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Código para invitar',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              SelectableText(
                                group.inviteCode,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                'Materias (secciones)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_sections.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      isOwner
                          ? 'Aún no hay materias. Pulse + para crear una y agregar actividades.'
                          : 'Aún no hay materias en este grupo.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ..._sections.map((section) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppModulePastel.formacion.withValues(alpha: 0.5),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: AppModulePastel.formacionAccent,
                          ),
                        ),
                        title: Text(section.name),
                        subtitle: section.description.isEmpty
                            ? null
                            : Text(
                                section.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isOwner)
                              IconButton(
                                icon: const Icon(Icons.edit_rounded),
                                tooltip: 'Editar materia',
                                onPressed: () async {
                                  final updated = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FormacionEditSectionPage(
                                        group: group,
                                        section: section,
                                        currentCedula: currentCedula,
                                      ),
                                    ),
                                  );
                                  if (updated == true) _load();
                                },
                              ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FormacionSectionDetailPage(
                                group: group,
                                section: section,
                                currentCedula: currentCedula,
                              ),
                            ),
                          ).then((_) => _load());
                        },
                      ),
                    )),
            ],
          ),
        ),
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FormacionCreateSectionPage(
                      group: group,
                      currentCedula: currentCedula,
                    ),
                  ),
                );
                _load();
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}
