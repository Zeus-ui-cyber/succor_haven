// lib/features/sessions/repositories/sessions_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../core/api/api_service.dart';
import '../../../models/session.dart';

/// Maps a filename's extension to the MIME type routes/index.js's
/// uploadSessionFile fileFilter (ALLOWED_SESSION_FILE_TYPES) expects.
/// Same reasoning as module_repository.dart's _mediaTypeFor — without
/// this, MultipartFile.fromBytes defaults to application/octet-stream
/// and the server rejects the upload outright.
MediaType _sessionFileMediaType(String fileName) {
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
    case 'jpg':
    case 'jpeg':
      return MediaType('image', 'jpeg');
    case 'png':
      return MediaType('image', 'png');
    case 'webp':
      return MediaType('image', 'webp');
    case 'mp4':
      return MediaType('video', 'mp4');
    case 'mov':
      return MediaType('video', 'quicktime');
    case 'webm':
      return MediaType('video', 'webm');
    default:
      return MediaType('application', 'octet-stream');
  }
}

class SessionsRepository {
  final ApiService _api;
  SessionsRepository([ApiService? api]) : _api = api ?? ApiService.instance;

  /// Unified "My Sessions" feed — confirmed bookings + approved
  /// appointments (as real sessions) plus still-pending appointment
  /// requests, newest first within each group. Same list for both
  /// students and teachers; the backend scopes by req.user.
  Future<List<SessionModel>> getMySessions() async {
    final data = await _api.get('/sessions/mine') as List;
    return data
        .map((e) => SessionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SessionModel> getSessionById(String id) async {
    final data = await _api.get('/sessions/$id') as Map<String, dynamic>;
    return SessionModel.fromJson(data);
  }

  /// Short-lived STUN/TURN ICE server config, ready to pass straight into
  /// flutter_webrtc's createPeerConnection({'iceServers': [...]}).
  Future<List<Map<String, dynamic>>> getTurnCredentials(String id) async {
    final data =
        await _api.get('/sessions/$id/turn-credentials') as Map<String, dynamic>;
    return (data['iceServers'] as List).cast<Map<String, dynamic>>();
  }

  Future<SessionModel> endSession(String id) async {
    final data = await _api.patch('/sessions/$id/end') as Map<String, dynamic>;
    return SessionModel.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> getChatHistory(String id) async {
    final data = await _api.get('/sessions/$id/chat') as List;
    return data.cast<Map<String, dynamic>>();
  }

  Future<String> getMyNotes(String id) async {
    final data = await _api.get('/sessions/$id/notes') as Map<String, dynamic>;
    return data['content'] as String? ?? '';
  }

  Future<void> saveMyNotes(String id, String content) async {
    await _api.patch('/sessions/$id/notes', data: {'content': content});
  }

  Future<List<Map<String, dynamic>>> getSessionFiles(String id) async {
    final data = await _api.get('/sessions/$id/files') as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// Takes raw bytes + filename (not a path — file_picker's `.path` is
  /// unavailable on Flutter web), same convention as module_repository.dart.
  Future<Map<String, dynamic>> uploadSessionFile(
    String id, {
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final token = await _api.getAccessToken();
    final uri = Uri.parse('${ApiService.baseUrl}/sessions/$id/files');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: _sessionFileMediaType(fileName),
    ));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 201) {
      String message = 'Failed to upload file.';
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['error'] != null) message = body['error'] as String;
      } catch (_) {}
      throw ApiException(res.statusCode, message);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
