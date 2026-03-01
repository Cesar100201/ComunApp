import 'package:cloud_firestore/cloud_firestore.dart';

/// Grupo (clase) de Formación. Dueño = quien crea; participantes = quienes se unen con código.
class FormacionGroup {
  final String id;
  final String name;
  final String description;
  final String inviteCode;
  final String ownerUid;
  final int ownerCedula;
  final List<int> participantCedulas;
  final DateTime createdAt;

  const FormacionGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.inviteCode,
    required this.ownerUid,
    required this.ownerCedula,
    required this.participantCedulas,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'inviteCode': inviteCode,
      'ownerUid': ownerUid,
      'ownerCedula': ownerCedula,
      'participantCedulas': participantCedulas,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static FormacionGroup fromMap(String id, Map<String, dynamic> map) {
    final part = map['participantCedulas'];
    final list = part is List
        ? (part).map((e) => (e is int) ? e : (e as num).toInt()).toList()
        : <int>[];
    return FormacionGroup(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      inviteCode: map['inviteCode'] as String? ?? '',
      ownerUid: map['ownerUid'] as String? ?? '',
      ownerCedula: (map['ownerCedula'] is int)
          ? map['ownerCedula'] as int
          : (map['ownerCedula'] as num).toInt(),
      participantCedulas: list,
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  bool isOwnerByUid(String uid) => ownerUid == uid;
  bool isParticipant(int cedula) => participantCedulas.contains(cedula);
}

/// Sección (materia) dentro de un grupo. Las tareas/actividades viven dentro de una sección.
class FormacionSection {
  final String id;
  final String groupId;
  final String name;
  final String description;
  final int order;

  const FormacionSection({
    required this.id,
    required this.groupId,
    required this.name,
    this.description = '',
    this.order = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'name': name,
      'description': description,
      'order': order,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  static FormacionSection fromMap(String id, Map<String, dynamic> map) {
    return FormacionSection(
      id: id,
      groupId: map['groupId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      order: (map['order'] is int) ? map['order'] as int : (map['order'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Tarea (actividad) asignada a una sección de un grupo.
class FormacionAssignment {
  final String id;
  final String groupId;
  final String sectionId;
  final String title;
  final String description;
  final DateTime dueDate;
  final String createdByUid;
  final DateTime createdAt;
  final List<String> attachmentUrls;

  const FormacionAssignment({
    required this.id,
    required this.groupId,
    required this.sectionId,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.createdByUid,
    required this.createdAt,
    this.attachmentUrls = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'sectionId': sectionId,
      'title': title,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'createdByUid': createdByUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'attachmentUrls': attachmentUrls,
    };
  }

  static FormacionAssignment fromMap(String id, Map<String, dynamic> map) {
    final att = map['attachmentUrls'];
    final urls = att is List
        ? (att).map((e) => e.toString()).toList()
        : <String>[];
    return FormacionAssignment(
      id: id,
      groupId: map['groupId'] as String? ?? '',
      sectionId: map['sectionId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      dueDate: (map['dueDate'] is Timestamp)
          ? (map['dueDate'] as Timestamp).toDate()
          : DateTime.now(),
      createdByUid: map['createdByUid'] as String? ?? '',
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      attachmentUrls: urls,
    );
  }
}

/// Tipo de entrega: solo texto, solo archivo(s), o ambos.
enum FormacionSubmissionType { text, file, both }

/// Entrega de un usuario a una tarea.
class FormacionSubmission {
  final String id;
  final String assignmentId;
  final String groupId;
  final int userCedula;
  final String userUid;
  final FormacionSubmissionType type;
  final String? textContent;
  final List<String> fileUrls;
  final List<String> fileNames;
  final DateTime submittedAt;
  final DateTime updatedAt;

  const FormacionSubmission({
    required this.id,
    required this.assignmentId,
    required this.groupId,
    required this.userCedula,
    required this.userUid,
    required this.type,
    this.textContent,
    this.fileUrls = const [],
    this.fileNames = const [],
    required this.submittedAt,
    required this.updatedAt,
  });

  static String _typeToString(FormacionSubmissionType t) {
    switch (t) {
      case FormacionSubmissionType.text:
        return 'text';
      case FormacionSubmissionType.file:
        return 'file';
      case FormacionSubmissionType.both:
        return 'both';
    }
  }

  static FormacionSubmissionType _typeFromString(String? s) {
    switch (s) {
      case 'file':
        return FormacionSubmissionType.file;
      case 'both':
        return FormacionSubmissionType.both;
      default:
        return FormacionSubmissionType.text;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'assignmentId': assignmentId,
      'groupId': groupId,
      'userCedula': userCedula,
      'userUid': userUid,
      'type': _typeToString(type),
      'textContent': textContent,
      'fileUrls': fileUrls,
      'fileNames': fileNames,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static FormacionSubmission fromMap(String id, Map<String, dynamic> map) {
    final fu = map['fileUrls'];
    final fn = map['fileNames'];
    return FormacionSubmission(
      id: id,
      assignmentId: map['assignmentId'] as String? ?? '',
      groupId: map['groupId'] as String? ?? '',
      userCedula: (map['userCedula'] is int)
          ? map['userCedula'] as int
          : (map['userCedula'] as num).toInt(),
      userUid: map['userUid'] as String? ?? '',
      type: _typeFromString(map['type'] as String?),
      textContent: map['textContent'] as String?,
      fileUrls: fu is List ? fu.map((e) => e.toString()).toList() : [],
      fileNames: fn is List ? fn.map((e) => e.toString()).toList() : [],
      submittedAt: (map['submittedAt'] is Timestamp)
          ? (map['submittedAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: (map['updatedAt'] is Timestamp)
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  FormacionSubmission copyWith({
    String? id,
    String? assignmentId,
    String? groupId,
    int? userCedula,
    String? userUid,
    FormacionSubmissionType? type,
    String? textContent,
    List<String>? fileUrls,
    List<String>? fileNames,
    DateTime? submittedAt,
    DateTime? updatedAt,
  }) {
    return FormacionSubmission(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      groupId: groupId ?? this.groupId,
      userCedula: userCedula ?? this.userCedula,
      userUid: userUid ?? this.userUid,
      type: type ?? this.type,
      textContent: textContent ?? this.textContent,
      fileUrls: fileUrls ?? this.fileUrls,
      fileNames: fileNames ?? this.fileNames,
      submittedAt: submittedAt ?? this.submittedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
