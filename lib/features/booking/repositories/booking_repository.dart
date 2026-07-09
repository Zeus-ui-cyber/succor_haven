// lib/features/booking/repositories/booking_repository.dart
//
// Phase 1: read-only teacher directory + profile lookup, backed by the
// existing GET /teachers and GET /teachers/:id endpoints. Both already
// filter to role='teacher' AND is_approved=true server-side, so accounts
// that don't exist (or are still pending) never reach the client — no
// backend changes needed for this feature.

import '../../../core/api/api_service.dart';
import '../../../models/teacher_profile.dart';

class BookingRepository {
  final ApiService _api = ApiService.instance;

  /// GET /teachers — approved teacher directory.
  Future<List<TeacherProfileModel>> browseTeachers({
    String? subject,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (subject != null && subject.trim().isNotEmpty) {
      query['subject'] = subject.trim();
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final data = await _api.get('/teachers', query: query);
    final rows = (data as List<dynamic>?) ?? const [];
    return rows
        .map((row) => TeacherProfileModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// GET /teachers/:id — single teacher profile (bio, subjects, availability).
  Future<TeacherProfileModel> getTeacherDetails(String teacherId) async {
    final data = await _api.get('/teachers/$teacherId');
    return TeacherProfileModel.fromJson(data as Map<String, dynamic>);
  }
}