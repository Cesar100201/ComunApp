import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/formacion_models.dart';
import '../data/formacion_service.dart';
import 'formacion_assignment_detail_page.dart';
import 'formacion_create_assignment_page.dart';
import 'formacion_edit_assignment_page.dart';
import 'formacion_error_helper.dart';

/// Detalle de una sección (materia): lista de actividades/tareas pendientes.
/// El dueño del grupo puede crear tareas aquí.
class FormacionSectionDetailPage extends StatefulWidget {
  const FormacionSectionDetailPage({
    super.key,
    required this.group,
    required this.section,
    required this.currentCedula,
  });

  final FormacionGroup group;
  final FormacionSection section;
  final int currentCedula;

  @override
  State<FormacionSectionDetailPage> createState() => _FormacionSectionDetailPageState();
}

class _FormacionSectionDetailPageState extends State<FormacionSectionDetailPage> {
  final FormacionService _service = FormacionService();
  bool _loading = true;
  String? _error;
  List<FormacionAssignment> _assignments = [];

  FormacionGroup get group => widget.group;
  FormacionSection get section => widget.section;
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
      final list = await _service.getAssignmentsBySection(section.id);
      if (mounted) {
        setState(() {
          _assignments = list;
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
        title: Text(section.name),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Crear actividad',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FormacionCreateAssignmentPage(
                      group: group,
                      section: section,
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
              if (section.description.isNotEmpty) ...[
                Text(
                  section.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                'Actividades pendientes',
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
              else if (_assignments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      isOwner
                          ? 'Aún no hay actividades. Pulse + para crear una.'
                          : 'Aún no hay actividades en esta materia.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                )
              else
                ..._assignments.map((a) => _AssignmentTile(
                      assignment: a,
                      group: group,
                      section: section,
                      currentCedula: currentCedula,
                      isOwner: isOwner,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FormacionAssignmentDetailPage(
                              assignment: a,
                              group: group,
                              currentCedula: currentCedula,
                            ),
                          ),
                        );
                        _load();
                      },
                      onEdited: _load,
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
                    builder: (context) => FormacionCreateAssignmentPage(
                      group: group,
                      section: section,
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

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.assignment,
    required this.group,
    required this.section,
    required this.currentCedula,
    required this.isOwner,
    required this.onTap,
    this.onEdited,
  });

  final FormacionAssignment assignment;
  final FormacionGroup group;
  final FormacionSection section;
  final int currentCedula;
  final bool isOwner;
  final VoidCallback onTap;
  final VoidCallback? onEdited;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FormacionSubmission?>(
      future: FormacionService().getSubmission(
        assignmentId: assignment.id,
        userCedula: currentCedula,
      ),
      builder: (context, snap) {
        String status = 'Pendiente';
        Color statusColor = AppColors.warning;
        if (snap.hasData && snap.data != null) {
          status = 'Entregado';
          statusColor = AppColors.success;
        } else if (assignment.dueDate.isBefore(DateTime.now())) {
          status = 'Vencido';
          statusColor = AppColors.error;
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppModulePastel.formacion.withValues(alpha: 0.5),
              child: const Icon(Icons.assignment_rounded, color: AppModulePastel.formacionAccent),
            ),
            title: Text(assignment.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Límite: ${DateFormat('dd/MM/yyyy').format(assignment.dueDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOwner)
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    tooltip: 'Editar actividad',
                    onPressed: () async {
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FormacionEditAssignmentPage(
                            group: group,
                            section: section,
                            assignment: assignment,
                            currentCedula: currentCedula,
                          ),
                        ),
                      );
                      if (updated == true) onEdited?.call();
                    },
                  ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            onTap: onTap,
          ),
        );
      },
    );
  }
}
