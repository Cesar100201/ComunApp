import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/formacion_models.dart';
import '../data/formacion_service.dart';

/// Pantalla para entregar una tarea: texto y/o archivos (PDF, Word).
class FormacionSubmitPage extends StatefulWidget {
  const FormacionSubmitPage({
    super.key,
    required this.assignment,
    required this.group,
    required this.currentCedula,
    this.existingSubmission,
  });

  final FormacionAssignment assignment;
  final FormacionGroup group;
  final int currentCedula;
  final FormacionSubmission? existingSubmission;

  @override
  State<FormacionSubmitPage> createState() => _FormacionSubmitPageState();
}

class _FormacionSubmitPageState extends State<FormacionSubmitPage> {
  final FormacionService _service = FormacionService();
  final _textController = TextEditingController();

  String _mode = 'both'; // 'text' | 'file' | 'both'
  final List<String> _pickedPaths = [];
  final List<String> _pickedNames = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existingSubmission != null) {
      _textController.text = widget.existingSubmission!.textContent ?? '';
      _pickedNames.addAll(widget.existingSubmission!.fileNames);
      // existing file URLs are already in submission; we only allow adding more or keeping
      _mode = widget.existingSubmission!.fileUrls.isEmpty
          ? (widget.existingSubmission!.textContent?.isNotEmpty == true ? 'text' : 'both')
          : (widget.existingSubmission!.textContent?.isNotEmpty == true ? 'both' : 'file');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      for (final f in result.files) {
        if (f.path != null) {
          _pickedPaths.add(f.path!);
          _pickedNames.add(f.name);
        }
      }
    });
  }

  void _removePickedFile(int index) {
    setState(() {
      _pickedPaths.removeAt(index);
      _pickedNames.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _error = 'Debe iniciar sesión.');
      return;
    }
    final text = _textController.text.trim();
    if (_mode == 'text' && text.isEmpty) {
      setState(() => _error = 'Escriba el contenido de la entrega.');
      return;
    }
    if ((_mode == 'file' || _mode == 'both') && _pickedPaths.isEmpty && widget.existingSubmission?.fileUrls.isEmpty != false) {
      setState(() => _error = 'Agregue al menos un archivo o escriba texto.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      List<String> fileUrls = List.from(widget.existingSubmission?.fileUrls ?? []);
      List<String> fileNames = List.from(widget.existingSubmission?.fileNames ?? []);
      for (int i = 0; i < _pickedPaths.length; i++) {
        final url = await _service.uploadSubmissionFile(
          assignmentId: widget.assignment.id,
          userCedula: widget.currentCedula,
          localFilePath: _pickedPaths[i],
          fileName: _pickedNames[i],
        );
        fileUrls.add(url);
        fileNames.add(_pickedNames[i]);
      }
      FormacionSubmissionType type;
      if (text.isNotEmpty && fileUrls.isNotEmpty) {
        type = FormacionSubmissionType.both;
      } else if (text.isNotEmpty) {
        type = FormacionSubmissionType.text;
      } else {
        type = FormacionSubmissionType.file;
      }
      await _service.saveSubmission(
        assignmentId: widget.assignment.id,
        groupId: widget.group.id,
        userCedula: widget.currentCedula,
        userUid: uid,
        type: type,
        textContent: text.isNotEmpty ? text : null,
        fileUrls: fileUrls,
        fileNames: fileNames,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrega guardada correctamente.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
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
      appBar: AppBar(title: const Text('Entregar tarea')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Cómo desea entregar?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'both', label: Text('Texto y archivo'), icon: Icon(Icons.notes_rounded)),
                ButtonSegment(value: 'text', label: Text('Solo texto'), icon: Icon(Icons.text_fields_rounded)),
                ButtonSegment(value: 'file', label: Text('Solo archivo'), icon: Icon(Icons.attach_file_rounded)),
              ],
              selected: {_mode},
              onSelectionChanged: (Set<String> s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 24),
            if (_mode == 'text' || _mode == 'both') ...[
              Text(
                'Escriba o pegue su respuesta',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'Escriba aquí o pegue el texto...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 12,
                minLines: 4,
              ),
              const SizedBox(height: 20),
            ],
            if (_mode == 'file' || _mode == 'both') ...[
              Text(
                'Archivos (PDF o Word)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              if (widget.existingSubmission?.fileNames.isNotEmpty == true)
                ...widget.existingSubmission!.fileNames.asMap().entries.map((e) => ListTile(
                      leading: const Icon(Icons.picture_as_pdf_rounded),
                      title: Text(e.value),
                      subtitle: const Text('Ya subido'),
                    )),
              ..._pickedPaths.asMap().entries.map((e) => ListTile(
                    leading: const Icon(Icons.insert_drive_file_rounded),
                    title: Text(_pickedNames[e.key]),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => _removePickedFile(e.key),
                    ),
                  )),
              OutlinedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar archivo PDF o Word'),
              ),
              const SizedBox(height: 20),
            ],
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 0),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enviar entrega'),
            ),
          ],
        ),
      ),
    );
  }
}
