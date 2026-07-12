// lib/features/settings/repositories/settings_repository.dart

import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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
  ///
  /// FIXED: MultipartFile.fromBytes defaults to `application/octet-stream`
  /// when no contentType is given — that's not in the server's
  /// ALLOWED_IMAGE_TYPES list (jpeg/png/webp only), so every single upload
  /// was being rejected by multer's fileFilter regardless of what the
  /// actual image was. Now the content type is set explicitly from the
  /// file extension so the server's mimetype check passes.
  Future<String> uploadProfilePicture(
      Uint8List imageBytes, String filename) async {
    final token = await _api.getAccessToken();
    final uri = Uri.parse('${ApiService.baseUrl}/settings/profile/picture');

    final ext = filename.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg', // covers jpg/jpeg and any unrecognized extension
    };

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes(
        'profilePicture',
        imageBytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 400) {
      throw ApiException(
          response.statusCode, 'Failed to upload profile picture');
    }

    final decoded = response.body;
    final match = RegExp(r'"avatarUrl"\s*:\s*"([^"]+)"').firstMatch(decoded);
    if (match == null) {
      throw ApiException(500, 'Unexpected response from server');
    }
    return match.group(1)!;
  }

  // ── everything below here is unchanged ──────────────────────────────────
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

  Future<void> updatePrimaryPhone(
      {required String phone, required String otp}) {
    return _api
        .patch('/settings/phone/primary', data: {'phone': phone, 'otp': otp});
  }

  Future<void> updateBackupPhone({required String phone, required String otp}) {
    return _api
        .patch('/settings/phone/backup', data: {'phone': phone, 'otp': otp});
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

  Future<void> submitConcern(
      {required String subject, required String message}) {
    return _api.post('/settings/concerns', data: {
      'subject': subject,
      'message': message,
    });
  }

  // ── Teacher settings ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getCreditsSummary() async {
    final data = await _api.get('/teachers/profile/credits');
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTeacherProfile() async {
    final data = await _api.get('/teachers/profile/me');
    return data as Map<String, dynamic>;
  }

  Future<void> updateBio(String bio) {
    return _api.patch('/teachers/profile/bio', data: {'bio': bio});
  }

  Future<void> addSubject(String subject) {
    return _api.post('/teachers/profile/subjects', data: {'subject': subject});
  }

  Future<void> removeSubject(String subjectText) {
    return _api.delete('/teachers/profile/subjects', data: {
      'subject': subjectText,
    });
  }

  Future<void> updateSubject({
    required String subjectId,
    required String subject,
  }) {
    return _api.patch('/teachers/profile/subjects', data: {
      'oldSubject': subjectId,
      'newSubject': subject,
    });
  }

  Future<List<String>> getAvailability() async {
    final data = await _api.get('/teachers/profile/availability');
    return List<String>.from(data as List);
  }

  Future<void> saveAvailabilitySlot({
    required String day,
    String? startTime,
    String? endTime,
    String? slotId,
  }) {
    return _api.post('/teachers/profile/availability', data: {'day': day});
  }

  Future<void> deleteAvailabilitySlot(String slotId) {
    return _api.delete('/teachers/profile/availability/$slotId', data: {
      'day': slotId,
    });
  }
}
