// lib/features/appointments/repositories/appointment_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth/repositories/auth_repository.dart';
import '../../../models/appointment.dart';

class AppointmentRepository {
  final AuthRepository _authRepo;
  AppointmentRepository(this._authRepo);

  Future<Map<String, String>> _headers() async {
    final token = await _authRepo.getAccessToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // ── STUDENT ────────────────────────────────────────────────────────────

  /// Student: submit a new appointment request.
  Future<AppointmentModel> createAppointment({
    required String teacherId,
    required String title,
    required String purpose,
    required String subject,
    required DateTime preferredDate,
    required String preferredTime, // 'HH:MM'
    required int durationMins, // 30 | 60 | 90 | 120
    String? description,
    String? attachmentUrl,
  }) async {
    final res = await http.post(
      Uri.parse('${AuthRepository.baseUrl}/appointments'),
      headers: await _headers(),
      body: jsonEncode({
        'teacherId': teacherId,
        'title': title,
        'purpose': purpose,
        'subject': subject,
        'preferredDate':
            '${preferredDate.year.toString().padLeft(4, '0')}-'
            '${preferredDate.month.toString().padLeft(2, '0')}-'
            '${preferredDate.day.toString().padLeft(2, '0')}',
        'preferredTime': preferredTime,
        // The device's real UTC offset right now, e.g. 480 for UTC+8 —
        // this is what lets the backend correctly figure out what
        // real-world instant "9:30" actually means (see
        // 0008_appointment_timezone.sql). Without it, the session this
        // request eventually creates could unlock at the wrong clock time.
        'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        'durationMins': durationMins,
        'description': description,
        'attachmentUrl': attachmentUrl,
      }),
    );

    if (res.statusCode != 201) {
      throw Exception(_extractError(res.body) ?? 'Failed to submit appointment request.');
    }
    return AppointmentModel.fromJson(jsonDecode(res.body));
  }

  /// Student: list all of my appointment requests, any status.
  Future<List<AppointmentModel>> getMyAppointments() async {
    final res = await http.get(
      Uri.parse('${AuthRepository.baseUrl}/appointments/mine'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to load appointments.');
    }
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => AppointmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Student: cancel a pending / approved / rescheduled request.
  Future<AppointmentModel> cancelAppointment(String id) async {
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/appointments/$id/cancel'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to cancel appointment.');
    }
    return AppointmentModel.fromJson(jsonDecode(res.body));
  }

  /// Student: accept or decline a teacher's proposed reschedule.
  Future<AppointmentModel> respondToReschedule(String id, {required bool accept}) async {
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/appointments/$id/respond-reschedule'),
      headers: await _headers(),
      body: jsonEncode({'accept': accept}),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to respond to the proposed schedule.');
    }
    return AppointmentModel.fromJson(jsonDecode(res.body));
  }

  // ── TEACHER ────────────────────────────────────────────────────────────

  /// Teacher: list all appointment requests submitted to me, any status.
  Future<List<AppointmentModel>> getTeacherAppointments() async {
    final res = await http.get(
      Uri.parse('${AuthRepository.baseUrl}/appointments/teacher/mine'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to load appointments.');
    }
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => AppointmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Teacher: approve a pending/rescheduled request.
  Future<AppointmentModel> approveAppointment(String id) async {
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/appointments/$id/approve'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to approve appointment.');
    }
    return AppointmentModel.fromJson(jsonDecode(res.body));
  }

  /// Teacher: decline a pending/rescheduled request, with an optional reason.
  Future<AppointmentModel> declineAppointment(String id, {String? reason}) async {
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/appointments/$id/decline'),
      headers: await _headers(),
      body: jsonEncode({'reason': reason}),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to decline appointment.');
    }
    return AppointmentModel.fromJson(jsonDecode(res.body));
  }

  /// Teacher: propose a new date/time for a pending request.
  Future<AppointmentModel> proposeReschedule(
    String id, {
    required DateTime proposedDate,
    required String proposedTime, // 'HH:MM'
  }) async {
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/appointments/$id/propose-reschedule'),
      headers: await _headers(),
      body: jsonEncode({
        'proposedDate':
            '${proposedDate.year.toString().padLeft(4, '0')}-'
            '${proposedDate.month.toString().padLeft(2, '0')}-'
            '${proposedDate.day.toString().padLeft(2, '0')}',
        'proposedTime': proposedTime,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to propose new schedule.');
    }
    return AppointmentModel.fromJson(jsonDecode(res.body));
  }

  /// Teacher: mark an approved appointment as completed.
  Future<AppointmentModel> completeAppointment(String id) async {
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/appointments/$id/complete'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(_extractError(res.body) ?? 'Failed to mark as completed.');
    }
    return AppointmentModel.fromJson(jsonDecode(res.body));
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