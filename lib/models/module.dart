// lib/models/module.dart
//
// Mirrors modules.controller.js's joined shape:
//   list()/getOne() -> m.*, uploaded_by_name, uploaded_by_role
//
// uploaded_by is INTEGER on the live schema (users.id is INTEGER, not
// UUID — confirmed this session), parsed defensively via .toString() the
// same way AppointmentModel and TeacherProfileModel handle their id
// fields, so a numeric JSON value never throws an `as String` cast error.

class ModuleModel {
  final String id;
  final String title;
  final String subject;
  final String? description;
  final String fileUrl;
  final String fileName;
  final String? fileType;
  final String uploadedBy; // user id, as string
  final String? uploadedByName;
  final String? uploadedByRole; // 'admin' | 'teacher'
  final DateTime createdAt;
  final DateTime updatedAt;

  const ModuleModel({
    required this.id,
    required this.title,
    required this.subject,
    this.description,
    required this.fileUrl,
    required this.fileName,
    this.fileType,
    required this.uploadedBy,
    this.uploadedByName,
    this.uploadedByRole,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isUploadedByAdmin => uploadedByRole == 'admin';

  /// File extension in lowercase, e.g. 'pdf', 'docx' — derived from
  /// fileName since the backend doesn't send a separate extension field.
  String get extension {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  factory ModuleModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v, {DateTime? fallback}) {
      if (v == null) return fallback ?? DateTime.now();
      final parsed = DateTime.tryParse(v.toString());
      return parsed ?? (fallback ?? DateTime.now());
    }

    return ModuleModel(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String?,
      fileUrl: json['file_url'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      fileType: json['file_type'] as String?,
      uploadedBy: json['uploaded_by'].toString(),
      uploadedByName: json['uploaded_by_name'] as String?,
      uploadedByRole: json['uploaded_by_role'] as String?,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }
}