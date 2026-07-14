// lib/features/sessions/repositories/session_room_repository.dart
//
// REST side of the session room (chat history, notes, files, end, TURN
// creds). Live send/receive for chat/whiteboard/presence goes through
// SocketRoomService instead — this repo is deliberately "REST only".

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/api/api_service.dart';
import '../models/session_room_models.dart';

class SessionRoomRepository {
  final ApiService _api;
  SessionRoomRepository([ApiService? api]) : _api = api ?? ApiService.instance;

  Future<List<ChatMessageModel>> getChatHistory(String sessionId) async {
    final data = await _api.get('/sessions/$sessionId/chat') as List;
    return data
        .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// REST fallback send (per sessionRoom.controller.js's comment: used
  /// if the socket connection is momentarily down). The live path is
  /// SocketRoomService.sendChat.
  Future<ChatMessageModel> postChatFallback(
      String sessionId, String body) async {
    final data =
        await _api.post('/sessions/$sessionId/chat', data: {'body': body})
            as Map<String, dynamic>;
    return ChatMessageModel.fromJson(data);
  }

  Future<SessionNoteModel> getNotes(String sessionId) async {
    final data =
        await _api.get('/sessions/$sessionId/notes') as Map<String, dynamic>;
    return SessionNoteModel.fromJson(data);
  }

  Future<SessionNoteModel> patchNotes(String sessionId, String content) async {
    final data = await _api.patch('/sessions/$sessionId/notes',
        data: {'content': content}) as Map<String, dynamic>;
    return SessionNoteModel.fromJson(data);
  }

  Future<List<SessionFileModel>> getFiles(String sessionId) async {
    final data = await _api.get('/sessions/$sessionId/files') as List;
    return data
        .map((e) => SessionFileModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Multipart upload — ApiService doesn't expose one, so this builds
  /// the request directly the same way ApiService attaches auth/base
  /// URL, rather than duplicating a second HTTP client setup.
  Future<SessionFileModel> uploadFile({
    required String sessionId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final token = await _api.getAccessToken();
    final uri = Uri.parse('${ApiService.baseUrl}/sessions/$sessionId/files');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({if (token != null) 'Authorization': 'Bearer $token'})
      ..files
          .add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode >= 400) {
      String message = 'Upload failed (${res.statusCode})';
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['error'] != null) message = body['error'];
      } catch (_) {}
      throw ApiException(res.statusCode, message);
    }
    return SessionFileModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<TurnCredentials> getTurnCredentials(String sessionId) async {
    final data = await _api.get('/sessions/$sessionId/turn-credentials')
        as Map<String, dynamic>;
    return TurnCredentials.fromJson(data);
  }

  /// Returns the raw updated session map ({id, status, ended_at}) per
  /// sessionRoom.service.js's endSession().
  Future<void> endSession(String sessionId) async {
    await _api.patch('/sessions/$sessionId/end');
  }
}
