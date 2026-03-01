import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/formacion_models.dart';
import '../data/formacion_service.dart';
import 'formacion_submit_page.dart';
import 'formacion_submissions_list_page.dart';

/// Detalle de una tarea: enunciado, fecha límite, estado y botón Entregar / Ver mi entrega.
/// El dueño del grupo puede ver la lista de entregas.
class FormacionAssignmentDetailPage extends StatefulWidget {
  const FormacionAssignmentDetailPage({
    super.key,
    required this.assignment,
    required this.group,
    required this.currentCedula,
  });

  final FormacionAssignment assignment;
  final FormacionGroup group;
  final int currentCedula;

  @override
  State<FormacionAssignmentDetailPage> createState() =>
      _FormacionAssignmentDetailPageState();
}

class _FormacionAssignmentDetailPageState
    extends State<FormacionAssignmentDetailPage> {
  final FormacionService _service = FormacionService();
  bool _loading = true;
  FormacionSubmission? _mySubmission;

  bool get _isOwner =>
      widget.group.ownerUid == FirebaseAuth.instance.currentUser?.uid;
  bool get isPastDue => widget.assignment.dueDate.isBefore(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sub = await _service.getSubmission(
      assignmentId: widget.assignment.id,
      userCedula: widget.currentCedula,
    );
    if (mounted) {
      setState(() {
        _mySubmission = sub;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignment = widget.assignment;
    final group = widget.group;

    return Scaffold(
      appBar: AppBar(
        title: Text(assignment.title),
        actions: [
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.list_rounded),
              tooltip: 'Ver entregas',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FormacionSubmissionsListPage(
                      assignment: assignment,
                      group: group,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (assignment.description.isNotEmpty) ...[
                    Text(
                      assignment.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_rounded,
                            color: AppModulePastel.formacionAccent,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fecha límite',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              Text(
                                DateFormat(
                                  'dd/MM/yyyy',
                                ).format(assignment.dueDate),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_mySubmission != null) ...[
                    Card(
                      color: AppColors.success.withValues(alpha: 0.1),
                      child: const ListTile(
                        leading: Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                        ),
                        title: Text('Ya entregaste esta tarea'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!isPastDue || _mySubmission != null)
                    FilledButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FormacionSubmitPage(
                              assignment: assignment,
                              group: group,
                              currentCedula: widget.currentCedula,
                              existingSubmission: _mySubmission,
                            ),
                          ),
                        );
                        _load();
                      },
                      icon: Icon(
                        _mySubmission != null
                            ? Icons.edit_rounded
                            : Icons.upload_rounded,
                      ),
                      label: Text(
                        _mySubmission != null
                            ? 'Ver o editar mi entrega'
                            : 'Entregar',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Esta tarea ya venció. No se pueden enviar más entregas.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
