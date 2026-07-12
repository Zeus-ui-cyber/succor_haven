// lib/features/announcements/repositories/announcement_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../models/announcement.dart';
import '../../../models/announcement_comment.dart';

String resolveAnnouncementFileUrl(String rawUrl) {
  if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
    return rawUrl;
  }
  final apiBase = AuthRepository.baseUrl;
  final fileHost = apiBase.replaceFirst(RegExp(r'/api/v\d+/?$'), '');
  final path = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
  return '$fileHost$path';
}

/// Maps a filename's extension to the MIME type the backend's multer
/// fileFilter allowlist expects (announcements.controller.js /
/// routes/index.js ALLOWED_ANNOUNCEMENT_TYPES). Without this,
/// http.MultipartFile.fromBytes defaults to application/octet-stream,
/// which the server rejects outright regardless of what file was picked.
MediaType _mediaTypeFor(String fileName) {
  final ext = fileName.contains('.')
      ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
      : '';
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return MediaType('image', 'jpeg');
    case 'png':
      return MediaType('image', 'png');
    case 'webp':
      return MediaType('image', 'webp');
    case 'pdf':
      return MediaType('application', 'pdf');
    case 'doc':
      return MediaType('application', 'msword');
    case 'docx':
      return MediaType('application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document');
    default:
      return MediaType('application', 'octet-stream');
  }
}

class UploadedAsset {
  final String url;
  final String name;
  final String type;
  const UploadedAsset({required this.url, required this.name, required this.type});
}

class AnnouncementRepository {
  final AuthRepository _authRepo;
  AnnouncementRepository(this._authRepo);

  Future<Map<String, String>> _headers() async {
    final token = await _authRepo.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String? _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? decoded['error'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  // ── Student/teacher-facing: visibility-filtered feed ───────────────────────
  // Backend (announcements.controller.js's list()) already restricts results
  // to what req.user's role/course/year_level are allowed to see — this just
  // forwards the optional query params it understands.
  Future<List<AnnouncementModel>> list({
    String? category,
    String? priority,
    String? search,
    String? filter, // 'bookmarked' | 'unread'
    int page = 1,
    int limit = 20,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (category != null && category.isNotEmpty) 'category': category,
      if (priority != null && priority.isNotEmpty) 'priority': priority,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (filter != null && filter.isNotEmpty) 'filter': filter,
    };
    final uri = Uri.parse('${AuthRepository.baseUrl}/announcements')
        .replace(queryParameters: query);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to load announcements.');
    }
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Detail — also marks the announcement as read server-side ──────────────
  Future<AnnouncementModel> getOne(String id) async {
    final res = await http.get(
      Uri.parse('${AuthRepository.baseUrl}/announcements/$id'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to load announcement.');
    }
    return AnnouncementModel.fromJson(jsonDecode(res.body));
  }

  Future<void> like(String id) async {
    final res = await http.post(
      Uri.parse('${AuthRepository.baseUrl}/announcements/$id/like'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to like announcement.');
    }
  }

  Future<void> unlike(String id) async {
    final res = await http.delete(
      Uri.parse('${AuthRepository.baseUrl}/announcements/$id/like'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to unlike announcement.');
    }
  }

  Future<void> bookmarkAnnouncement(String id) async {
    final res = await http.post(
      Uri.parse('${AuthRepository.baseUrl}/announcements/$id/bookmark'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to bookmark announcement.');
    }
  }

  Future<void> unbookmarkAnnouncement(String id) async {
    final res = await http.delete(
      Uri.parse('${AuthRepository.baseUrl}/announcements/$id/bookmark'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to unbookmark announcement.');
    }
  }

  // ── Comments / replies ─────────────────────────────────────────────────────
  Future<List<AnnouncementCommentModel>> listComments(String announcementId) async {
    final res = await http.get(
      Uri.parse('${AuthRepository.baseUrl}/announcements/$announcementId/comments'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to load comments.');
    }
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => AnnouncementCommentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AnnouncementCommentModel> addComment({
    required String announcementId,
    required String body,
    String? parentCommentId,
  }) async {
    final res = await http.post(
      Uri.parse('${AuthRepository.baseUrl}/announcements/$announcementId/comments'),
      headers: await _headers(),
      body: jsonEncode({
        'body': body,
        if (parentCommentId != null) 'parentCommentId': parentCommentId,
      }),
    );
    if (res.statusCode != 201) {
      throw Exception(_extractError(res.body) ?? 'Failed to post comment.');
    }
    return AnnouncementCommentModel.fromJson(jsonDecode(res.body));
  }

  Future<void> deleteComment(String commentId) async {
    final res = await http.delete(
      Uri.parse('${AuthRepository.baseUrl}/announcements/comments/$commentId'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to delete comment.');
    }
  }

  // ── Admin: unfiltered list, includes archived when asked ──────────────────
  Future<List<AnnouncementModel>> adminList({bool includeArchived = false}) async {
    final uri = Uri.parse('${AuthRepository.baseUrl}/admin/announcements')
        .replace(queryParameters: includeArchived ? {'includeArchived': 'true'} : null);
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to load announcements.');
    }
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UploadedAsset> uploadAsset({
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final token = await _authRepo.getAccessToken();
    final uri = Uri.parse('${AuthRepository.baseUrl}/announcements/upload');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: _mediaTypeFor(fileName),
    ));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 201) {
      throw Exception(_extractError(res.body) ?? 'Failed to upload file.');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return UploadedAsset(
      url: body['url'] as String,
      name: body['name'] as String,
      type: body['type'] as String,
    );
  }

  Future<AnnouncementModel> create({
    required String title,
    String? subtitle,
    required String description,
    required String category,
    required String priority,
    required String visibility,
    String? targetValue,
    String? coverImageUrl,
    List<String>? galleryUrls,
    String? attachmentUrl,
    String? attachmentName,
    String? externalLink,
    DateTime? publishAt,
    DateTime? expiresAt,
    bool isPinned = false,
    bool commentsEnabled = false,
  }) async {
    final res = await http.post(
      Uri.parse('${AuthRepository.baseUrl}/announcements'),
      headers: await _headers(),
      body: jsonEncode({
        'title': title,
        if (subtitle != null && subtitle.trim().isNotEmpty) 'subtitle': subtitle.trim(),
        'description': description,
        'category': category,
        'priority': priority,
        'visibility': visibility,
        if (targetValue != null && targetValue.trim().isNotEmpty) 'targetValue': targetValue.trim(),
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        if (galleryUrls != null) 'galleryUrls': galleryUrls,
        if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
        if (attachmentName != null) 'attachmentName': attachmentName,
        if (externalLink != null && externalLink.trim().isNotEmpty) 'externalLink': externalLink.trim(),
        // .toUtc() first — DateTime.now()/picker values are local time, and
        // .toIso8601String() on a non-UTC DateTime omits the offset (no
        // trailing 'Z'), so Postgres would interpret it in its own session
        // timezone instead of the device's, silently shifting publish_at by
        // however many hours off UTC the device is.
        if (publishAt != null) 'publishAt': publishAt.toUtc().toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
        'isPinned': isPinned,
        'commentsEnabled': commentsEnabled,
      }),
    );
    if (res.statusCode != 201) {
      throw Exception(_extractError(res.body) ?? 'Failed to create announcement.');
    }
    return AnnouncementModel.fromJson(jsonDecode(res.body));
  }

  Future<AnnouncementModel> update({
    required String id,
    required String title,
    String? subtitle,
    required String description,
    required String category,
    required String priority,
    required String visibility,
    String? targetValue,
    String? coverImageUrl,
    List<String>? galleryUrls,
    String? attachmentUrl,
    String? attachmentName,
    String? externalLink,
    DateTime? publishAt,
    DateTime? expiresAt,
    bool isPinned = false,
    bool commentsEnabled = false,
  }) async {
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/announcements/$id'),
      headers: await _headers(),
      body: jsonEncode({
        'title': title,
        'subtitle': (subtitle != null && subtitle.trim().isNotEmpty) ? subtitle.trim() : null,
        'description': description,
        'category': category,
        'priority': priority,
        'visibility': visibility,
        'targetValue': (targetValue != null && targetValue.trim().isNotEmpty) ? targetValue.trim() : null,
        'coverImageUrl': coverImageUrl,
        if (galleryUrls != null) 'galleryUrls': galleryUrls,
        'attachmentUrl': attachmentUrl,
        'attachmentName': attachmentName,
        'externalLink': (externalLink != null && externalLink.trim().isNotEmpty) ? externalLink.trim() : null,
        if (publishAt != null) 'publishAt': publishAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
        'isPinned': isPinned,
        'commentsEnabled': commentsEnabled,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to update announcement.');
    }
    return AnnouncementModel.fromJson(jsonDecode(res.body));
  }

  Future<void> delete(String id) async {
    final res = await http.delete(
      Uri.parse('${AuthRepository.baseUrl}/announcements/$id'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to delete announcement.');
    }
  }

  Future<void> _setFlag(String id, String action) async {
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/announcements/$id/$action'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to update announcement.');
    }
  }

  Future<void> archive(String id) => _setFlag(id, 'archive');
  Future<void> restore(String id) => _setFlag(id, 'restore');
  Future<void> pin(String id) => _setFlag(id, 'pin');
  Future<void> unpin(String id) => _setFlag(id, 'unpin');
}