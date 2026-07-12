// lib/features/notifications/repositories/notification_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth/repositories/auth_repository.dart';
import '../../../models/app_notification.dart';

class NotificationRepository {
  final AuthRepository _authRepo;
  NotificationRepository(this._authRepo);

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

  Future<List<AppNotificationModel>> list({int limit = 30}) async {
    final uri = Uri.parse('${AuthRepository.baseUrl}/notifications')
        .replace(queryParameters: {'limit': '$limit'});
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to load notifications.');
    }
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => AppNotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> unreadCount() async {
    final res = await http.get(
      Uri.parse('${AuthRepository.baseUrl}/notifications/unread-count'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) return 0;
    return (jsonDecode(res.body)['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) async {
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/notifications/$id/read'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to update notification.');
    }
  }

  Future<void> markAllRead() async {
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/notifications/read-all'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to update notifications.');
    }
  }
}
