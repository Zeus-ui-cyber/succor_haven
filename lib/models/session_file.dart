// lib/models/session_file.dart
class SessionFileModel {
  final String id;
  final String fileUrl;
  final String fileName;
  final String? fileType;
  final int? fileSize;
  final String uploadedByName;
  final DateTime createdAt;

  const SessionFileModel({
    required this.id,
    required this.fileUrl,
    required this.fileName,
    this.fileType,
    this.fileSize,
    required this.uploadedByName,
    required this.createdAt,
  });

  String get sizeLabel {
    final bytes = fileSize;
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory SessionFileModel.fromJson(Map<String, dynamic> json) =>
      SessionFileModel(
        id: json['id'].toString(),
        fileUrl: json['file_url'] as String,
        fileName: json['file_name'] as String,
        fileType: json['file_type'] as String?,
        fileSize: (json['file_size'] as num?)?.toInt(),
        uploadedByName: json['uploaded_by_name'] as String? ?? 'Teacher',
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
