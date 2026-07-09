// lib/features/settings/repositories/settings_repository.dart

import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../../core/api/api_service.dart';

class SettingsRepository {
  final ApiService _api = ApiService.instance;

  // ── 1. Edit Profile ─────────────────────────────────────────────────────
  Future<void> updateProfile({
    required String firstName,
    required String lastName,
  }) {
    return _api.patch('/settings/profile', data: {
      'firstName': firstName,
      'lastName': lastName,
    });
  }

  /// Uploads a profile picture and returns the new public URL.
  /// Takes raw bytes + a filename so this works on web, mobile, and desktop
  /// alike (dart:io's File is unavailable on Flutter web).
  Future<String> uploadProfilePicture(Uint8List imageBytes, String filename) async {
    final token = await _api.getAccessToken();
    final uri = Uri.parse('${ApiService.baseUrl}/settings/profile/picture');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes(
        'profilePicture',
        imageBytes,
        filename: filename,
      ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, 'Failed to upload profile picture');
    }

    final decoded = response.body;
    final match = RegExp(r'"profilePictureUrl"\s*:\s*"([^"]+)"').firstMatch(decoded);
    if (match == null) {
      throw ApiException(500, 'Unexpected response from server');
    }
    return match.group(1)!;
  }

  // ── everything else below is unchanged ──────────────────────────────────
  Future<void> sendPasswordChangeOtp() {
    return _api.post('/settings/password/otp/send');
  }

  Future<void> changePassword({
    required String otp,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _api.post('/settings/password/change', data: {
      'otp': otp,
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    });
  }

  Future<Map<String, dynamic>> getPhones() async {
    final data = await _api.get('/settings/phone');
    return data as Map<String, dynamic>;
  }

  Future<void> sendPhoneOtp(String phone) {
    return _api.post('/settings/phone/otp/send', data: {'phone': phone});
  }

  Future<void> updatePrimaryPhone({required String phone, required String otp}) {
    return _api.patch('/settings/phone/primary', data: {'phone': phone, 'otp': otp});
  }

  Future<void> updateBackupPhone({required String phone, required String otp}) {
    return _api.patch('/settings/phone/backup', data: {'phone': phone, 'otp': otp});
  }

  Future<void> updateLanguage(String language) {
    return _api.patch('/settings/language', data: {'language': language});
  }

  Future<Map<String, dynamic>> getNotificationPreferences() async {
    final data = await _api.get('/settings/notifications');
    return data as Map<String, dynamic>;
  }

  Future<void> updateNotificationPreferences({
    required bool upcomingSession,
    required bool sessionReminder,
  }) {
    return _api.patch('/settings/notifications', data: {
      'upcomingSession': upcomingSession,
      'sessionReminder': sessionReminder,
    });
  }

  Future<void> submitConcern({required String subject, required String message}) {
    return _api.post('/settings/concerns', data: {
      'subject': subject,
      'message': message,
    });
  }

  Future<Map<String, dynamic>> getCreditsSummary() async {
    final data = await _api.get('/settings/teacher/credits-summary');
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTeacherProfile() async {
    final data = await _api.get('/settings/teacher/profile');
    return data as Map<String, dynamic>;
  }

  Future<void> updateBio(String bio) {
    return _api.patch('/settings/teacher/bio', data: {'bio': bio});
  }

  Future<void> addSubject(String subject) {
    return _api.post('/settings/teacher/subjects', data: {'subject': subject});
  }

  Future<void> removeSubject(String subjectId) {
    return _api.delete('/settings/teacher/subjects/$subjectId');
  }

  Future<void> updateSubject({
    required String subjectId,
    required String subject,
  }) {
    return _api.patch('/settings/teacher/subjects/$subjectId', data: {
      'subject': subject,
    });
  }

  Future<List<Map<String, dynamic>>> getAvailability() async {
    final data = await _api.get('/settings/teacher/availability');
    return List<Map<String, dynamic>>.from(
      (data as List).map((s) => Map<String, dynamic>.from(s)),
    );
  }

  Future<void> saveAvailabilitySlot({
    required String day,
    required String startTime,
    required String endTime,
    String? slotId,
  }) {
    final data = {
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
    };
    if (slotId == null) {
      return _api.post('/settings/teacher/availability', data: data);
    }
    return _api.patch('/settings/teacher/availability/$slotId', data: data);
  }

  Future<void> deleteAvailabilitySlot(String slotId) {
    return _api.delete('/settings/teacher/availability/$slotId');
  }
}