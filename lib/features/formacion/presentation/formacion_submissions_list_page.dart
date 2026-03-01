import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/formacion_models.dart';
import '../data/formacion_service.dart';
import 'formacion_error_helper.dart';

/// Lista de entregas de una tarea (para el dueño del grupo).
class FormacionSubmissionsListPage extends StatefulWidget {
  const FormacionSubmissionsListPage({
    super.key,
    required this.assignment,
    required this.group,
  });

  final FormacionAssignment assignment;
  final FormacionGroup group;

  @override
  State<FormacionSubmissionsListPage> createState() => _FormacionSubmissionsListPageState();
}

class _FormacionSubmissionsListPageState extends State<FormacionSubmissionsListPage> {
  final FormacionService _service = FormacionService();
  bool _loading = true;
  String? _error;
  List<FormacionSubmission> _list = [];

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
      final list = await _service.getSubmissionsForAssignment(widget.assignment.id);
      if (mounted) {
        setState(() {
          _list = list;
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
      appBar: AppBar(title: Text('Entregas: ${widget.assignment.title}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Aún no hay entregas.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _list.length,
                      itemBuilder: (context, index) {
                        final sub = _list[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: AppModulePastel.formacion.withValues(alpha: 0.5),
                              child: Text(
                                sub.userCedula.toString().length >= 2
                                    ? sub.userCedula.toString().substring(0, 2)
                                    : sub.userCedula.toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            title: Text('Cédula: ${sub.userCedula}'),
                            subtitle: Text(
                              'Entregado: ${DateFormat('dd/MM/yyyy HH:mm').format(sub.submittedAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            children: [
                              if (sub.textContent != null && sub.textContent!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: SelectableText(
                                      sub.textContent!,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                ),
                              if (sub.fileUrls.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Archivos adjuntos',
                                        style: Theme.of(context).textTheme.labelMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      ...sub.fileUrls.asMap().entries.map((e) {
                                        final name = e.key < sub.fileNames.length
                                            ? sub.fileNames[e.key]
                                            : 'Archivo ${e.key + 1}';
                                        return ListTile(
                                          dense: true,
                                          leading: const Icon(Icons.insert_drive_file_rounded),
                                          title: Text(name),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.open_in_new_rounded),
                                            onPressed: () async {
                                              final uri = Uri.parse(e.value);
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                                              }
                                            },
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
