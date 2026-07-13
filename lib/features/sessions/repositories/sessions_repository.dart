// lib/features/sessions/repositories/sessions_repository.dart
import '../../../core/api/api_service.dart';
import '../../../models/session.dart';

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
}
