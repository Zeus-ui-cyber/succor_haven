// lib/features/modules/repositories/module_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../models/module.dart';

String resolveModuleFileUrl(String rawUrl) {
  if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
    return rawUrl;
  }
  final apiBase = AuthRepository.baseUrl;
  final fileHost = apiBase.replaceFirst(RegExp(r'/api/v\d+/?$'), '');
  final path = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
  return '$fileHost$path';
}

/// Maps a filename's extension to the MIME type the backend's multer
/// fileFilter allowlist expects (modules.controller.js /
/// routes/index.js ALLOWED_MODULE_TYPES). Without this,
/// http.MultipartFile.fromBytes defaults to application/octet-stream,
/// which the server rejects outright regardless of what file was
/// actually picked.
MediaType _mediaTypeFor(String fileName) {
  final ext = fileName.contains('.')
      ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
      : '';
  switch (ext) {
    case 'pdf':
      return MediaType('application', 'pdf');
    case 'doc':
      return MediaType('application', 'msword');
    case 'docx':
      return MediaType('application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document');
    case 'ppt':
      return MediaType('application', 'vnd.ms-powerpoint');
    case 'pptx':
      return MediaType('application',
          'vnd.openxmlformats-officedocument.presentationml.presentation');
    default:
      return MediaType('application', 'octet-stream');
  }
}

class ModuleRepository {
  final AuthRepository _authRepo;
  ModuleRepository(this._authRepo);

  Future<Map<String, String>> _headers() async {
    final token = await _authRepo.getAccessToken();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<ModuleModel>> listModules({String? subject, String? search}) async {
    final query = <String, String>{};
    if (subject != null && subject.trim().isNotEmpty) query['subject'] = subject.trim();
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();

    final uri = Uri.parse('${AuthRepository.baseUrl}/modules')
        .replace(queryParameters: query.isEmpty ? null : query);

    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to load modules.');
    }
    final list = jsonDecode(res.body) as List;
    return list.map((e) => ModuleModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Upload a new module. Takes raw file bytes + filename (not a path —
  /// file_picker's `.path` is unavailable on Flutter web).
  Future<ModuleModel> uploadModule({
    required String title,
    required String subject,
    String? description,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final token = await _authRepo.getAccessToken();
    final uri = Uri.parse('${AuthRepository.baseUrl}/modules');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    request.fields['title'] = title;
    request.fields['subject'] = subject;
    if (description != null && description.trim().isNotEmpty) {
      request.fields['description'] = description.trim();
    }
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: _mediaTypeFor(fileName),
    ));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 201) {
      throw Exception(_extractError(res.body) ?? 'Failed to upload module.');
    }
    return ModuleModel.fromJson(jsonDecode(res.body));
  }

  /// Update a module's metadata and/or replace its file.
  Future<ModuleModel> updateModule({
    required String id,
    String? title,
    String? subject,
    String? description,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    final token = await _authRepo.getAccessToken();
    final uri = Uri.parse('${AuthRepository.baseUrl}/modules/$id');
    final request = http.MultipartRequest('PATCH', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    if (title != null) request.fields['title'] = title;
    if (subject != null) request.fields['subject'] = subject;
    if (description != null) request.fields['description'] = description;
    if (fileBytes != null && fileName != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: _mediaTypeFor(fileName),
      ));
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to update module.');
    }
    return ModuleModel.fromJson(jsonDecode(res.body));
  }

  Future<void> deleteModule(String id) async {
    final res = await http.delete(
      Uri.parse('${AuthRepository.baseUrl}/modules/$id'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to delete module.');
    }
  }

  String? _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? decoded['error'] as String? : null;
    } catch (_) {
      return null;
    }
  }
}