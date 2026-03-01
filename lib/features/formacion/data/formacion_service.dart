import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'formacion_models.dart';

const String _groupsCollection = 'formacion_groups';
const String _sectionsCollection = 'formacion_sections';
const String _assignmentsCollection = 'formacion_assignments';
const String _submissionsCollection = 'formacion_submissions';

const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sin 0,O,1,I
const int _codeLength = 6;

/// Servicio de Firestore para el módulo Formación (grupos, tareas, entregas).
/// No usa Isar ni sync_service.
class FormacionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _generateInviteCode() {
    final r = Random();
    return List.generate(_codeLength, (_) => _codeChars[r.nextInt(_codeChars.length)]).join();
  }

  /// Genera un código único comprobando en Firestore.
  Future<String> _generateUniqueInviteCode() async {
    for (int i = 0; i < 20; i++) {
      final code = _generateInviteCode();
      final snap = await _firestore
          .collection(_groupsCollection)
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return code;
    }
    throw StateError('No se pudo generar código único');
  }

  /// Crea un grupo. [ownerUid] y [ownerCedula] del usuario actual.
  Future<FormacionGroup> createGroup({
    required String name,
    required String description,
    required String ownerUid,
    required int ownerCedula,
  }) async {
    final inviteCode = await _generateUniqueInviteCode();
    final ref = _firestore.collection(_groupsCollection).doc();
    final group = FormacionGroup(
      id: ref.id,
      name: name,
      description: description,
      inviteCode: inviteCode,
      ownerUid: ownerUid,
      ownerCedula: ownerCedula,
      participantCedulas: [],
      createdAt: DateTime.now(),
    );
    await ref.set(group.toMap());
    return group;
  }

  /// Grupos donde el usuario es dueño o está en participantes (por cédula).
  Future<List<FormacionGroup>> getMyGroups({
    required String uid,
    required int cedula,
  }) async {
    final ownerSnap = await _firestore
        .collection(_groupsCollection)
        .where('ownerUid', isEqualTo: uid)
        .get();
    final participantSnap = await _firestore
        .collection(_groupsCollection)
        .where('participantCedulas', arrayContains: cedula)
        .get();
    final seen = <String>{};
    final list = <FormacionGroup>[];
    for (final doc in ownerSnap.docs) {
      if (seen.add(doc.id)) list.add(FormacionGroup.fromMap(doc.id, doc.data()));
    }
    for (final doc in participantSnap.docs) {
      if (seen.add(doc.id)) list.add(FormacionGroup.fromMap(doc.id, doc.data()));
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Unirse a un grupo con el código. Lanza si el código no existe o ya está en el grupo.
  Future<FormacionGroup> joinGroupByCode({
    required String code,
    required int cedula,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) throw ArgumentError('Código vacío');
    final snap = await _firestore
        .collection(_groupsCollection)
        .where('inviteCode', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) throw Exception('Código inválido o grupo no encontrado');
    final doc = snap.docs.first;
    final data = doc.data();
    final list = List<int>.from(
      (data['participantCedulas'] as List?)?.map((e) => (e is int) ? e : (e as num).toInt()) ?? [],
    );
    if (list.contains(cedula)) throw Exception('Ya perteneces a este grupo');
    list.add(cedula);
    await doc.reference.update({'participantCedulas': list});
    return FormacionGroup.fromMap(doc.id, {...data, 'participantCedulas': list});
  }

  /// Obtiene un grupo por id.
  Future<FormacionGroup?> getGroup(String groupId) async {
    final doc = await _firestore.collection(_groupsCollection).doc(groupId).get();
    if (doc.data() == null) return null;
    return FormacionGroup.fromMap(doc.id, doc.data()!);
  }

  /// Secciones (materias) de un grupo, ordenadas por [order].
  /// Sin orderBy en Firestore para no requerir índice compuesto; se ordena en memoria.
  Future<List<FormacionSection>> getSectionsByGroup(String groupId) async {
    final snap = await _firestore
        .collection(_sectionsCollection)
        .where('groupId', isEqualTo: groupId)
        .get();
    final list = snap.docs
        .map((d) => FormacionSection.fromMap(d.id, d.data()))
        .toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// Crea una sección (materia) en el grupo. Solo el dueño debe llamar.
  Future<FormacionSection> createSection({
    required String groupId,
    required String name,
    String description = '',
  }) async {
    final sections = await getSectionsByGroup(groupId);
    final order = sections.isEmpty ? 0 : (sections.map((s) => s.order).reduce((a, b) => a > b ? a : b) + 1);
    final ref = _firestore.collection(_sectionsCollection).doc();
    final section = FormacionSection(
      id: ref.id,
      groupId: groupId,
      name: name,
      description: description,
      order: order,
    );
    await ref.set(section.toMap());
    return section;
  }

  /// Obtiene una sección por id.
  Future<FormacionSection?> getSection(String sectionId) async {
    final doc = await _firestore.collection(_sectionsCollection).doc(sectionId).get();
    if (doc.data() == null) return null;
    return FormacionSection.fromMap(doc.id, doc.data()!);
  }

  /// Actualiza nombre y descripción de una sección (materia). Solo el dueño del grupo.
  Future<void> updateSection({
    required String sectionId,
    required String name,
    String description = '',
  }) async {
    await _firestore.collection(_sectionsCollection).doc(sectionId).update({
      'name': name,
      'description': description,
    });
  }

  /// Tareas de un grupo (todas), ordenadas por fecha límite. Mantenido por compatibilidad.
  /// Sin orderBy en Firestore para no requerir índice compuesto; se ordena en memoria.
  Future<List<FormacionAssignment>> getAssignments(String groupId) async {
    final snap = await _firestore
        .collection(_assignmentsCollection)
        .where('groupId', isEqualTo: groupId)
        .get();
    final list = snap.docs
        .map((d) => FormacionAssignment.fromMap(d.id, d.data()))
        .toList();
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  /// Actividades (tareas) de una sección, ordenadas por fecha límite.
  /// Sin orderBy en Firestore para no requerir índice compuesto; se ordena en memoria.
  Future<List<FormacionAssignment>> getAssignmentsBySection(String sectionId) async {
    final snap = await _firestore
        .collection(_assignmentsCollection)
        .where('sectionId', isEqualTo: sectionId)
        .get();
    final list = snap.docs
        .map((d) => FormacionAssignment.fromMap(d.id, d.data()))
        .toList();
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  /// Crea una tarea en una sección (solo el dueño debe llamar).
  Future<FormacionAssignment> createAssignment({
    required String groupId,
    required String sectionId,
    required String title,
    required String description,
    required DateTime dueDate,
    required String createdByUid,
  }) async {
    final ref = _firestore.collection(_assignmentsCollection).doc();
    final assignment = FormacionAssignment(
      id: ref.id,
      groupId: groupId,
      sectionId: sectionId,
      title: title,
      description: description,
      dueDate: dueDate,
      createdByUid: createdByUid,
      createdAt: DateTime.now(),
    );
    await ref.set(assignment.toMap());
    return assignment;
  }

  /// Obtiene una tarea por id.
  Future<FormacionAssignment?> getAssignment(String assignmentId) async {
    final doc = await _firestore.collection(_assignmentsCollection).doc(assignmentId).get();
    if (doc.data() == null) return null;
    return FormacionAssignment.fromMap(doc.id, doc.data()!);
  }

  /// Actualiza título, descripción y fecha límite de una actividad (evaluación). Solo el dueño del grupo.
  Future<void> updateAssignment({
    required String assignmentId,
    required String title,
    required String description,
    required DateTime dueDate,
  }) async {
    await _firestore.collection(_assignmentsCollection).doc(assignmentId).update({
      'title': title,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
    });
  }

  /// Entrega del usuario para una tarea (si existe).
  Future<FormacionSubmission?> getSubmission({
    required String assignmentId,
    required int userCedula,
  }) async {
    final snap = await _firestore
        .collection(_submissionsCollection)
        .where('assignmentId', isEqualTo: assignmentId)
        .where('userCedula', isEqualTo: userCedula)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return FormacionSubmission.fromMap(d.id, d.data());
  }

  /// Guarda o actualiza la entrega (texto y/o URLs de archivos ya subidos).
  Future<FormacionSubmission> saveSubmission({
    required String assignmentId,
    required String groupId,
    required int userCedula,
    required String userUid,
    required FormacionSubmissionType type,
    String? textContent,
    List<String> fileUrls = const [],
    List<String> fileNames = const [],
  }) async {
    final now = DateTime.now();
    final existing = await getSubmission(assignmentId: assignmentId, userCedula: userCedula);
    final submission = FormacionSubmission(
      id: existing?.id ?? '',
      assignmentId: assignmentId,
      groupId: groupId,
      userCedula: userCedula,
      userUid: userUid,
      type: type,
      textContent: textContent?.trim().isEmpty == true ? null : textContent,
      fileUrls: fileUrls,
      fileNames: fileNames,
      submittedAt: existing?.submittedAt ?? now,
      updatedAt: now,
    );
    if (existing != null) {
      await _firestore
          .collection(_submissionsCollection)
          .doc(existing.id)
          .update(submission.toMap());
      return submission.copyWith(id: existing.id);
    } else {
      final ref = _firestore.collection(_submissionsCollection).doc();
      await ref.set(submission.copyWith(id: ref.id).toMap());
      return submission.copyWith(id: ref.id);
    }
  }

  /// Lista de entregas de una tarea (para el dueño del grupo).
  /// Sin orderBy en Firestore para no requerir índice compuesto; se ordena en memoria.
  Future<List<FormacionSubmission>> getSubmissionsForAssignment(String assignmentId) async {
    final snap = await _firestore
        .collection(_submissionsCollection)
        .where('assignmentId', isEqualTo: assignmentId)
        .get();
    final list = snap.docs
        .map((d) => FormacionSubmission.fromMap(d.id, d.data()))
        .toList();
    list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return list;
  }

  static const String _storagePrefix = 'formacion_submissions';

  /// Sube un archivo de entrega a Storage y devuelve la URL de descarga.
  /// [assignmentId], [userCedula], [localFilePath], [fileName] nombre para guardar.
  Future<String> uploadSubmissionFile({
    required String assignmentId,
    required int userCedula,
    required String localFilePath,
    required String fileName,
  }) async {
    final file = File(localFilePath);
    if (!await file.exists()) throw Exception('Archivo no encontrado');
    final safeName = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    final path = '$_storagePrefix/$assignmentId/$userCedula/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}
