// lib/models/appointment.dart
import 'package:flutter/material.dart';

enum AppointmentStatus {
  pending,
  approved,
  declined,
  completed,
  cancelled,
  rescheduled,
}

extension AppointmentStatusX on AppointmentStatus {
  static AppointmentStatus fromApi(String value) {
    switch (value) {
      case 'pending':
        return AppointmentStatus.pending;
      case 'approved':
        return AppointmentStatus.approved;
      case 'declined':
        return AppointmentStatus.declined;
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      case 'rescheduled':
        return AppointmentStatus.rescheduled;
      default:
        return AppointmentStatus.pending;
    }
  }

  String get apiValue => switch (this) {
        AppointmentStatus.pending => 'pending',
        AppointmentStatus.approved => 'approved',
        AppointmentStatus.declined => 'declined',
        AppointmentStatus.completed => 'completed',
        AppointmentStatus.cancelled => 'cancelled',
        AppointmentStatus.rescheduled => 'rescheduled',
      };

  /// English / Chinese label, matching the Taglish-friendly bilingual UI
  /// used across the rest of the app.
  String get label => switch (this) {
        AppointmentStatus.pending => 'Pending Approval · 待批准',
        AppointmentStatus.approved => 'Approved · 已批准',
        AppointmentStatus.declined => 'Declined · 已拒绝',
        AppointmentStatus.completed => 'Completed · 已完成',
        AppointmentStatus.cancelled => 'Cancelled · 已取消',
        AppointmentStatus.rescheduled => 'New Schedule Proposed · 改期建议',
      };

  String get shortLabel => switch (this) {
        AppointmentStatus.pending => 'Pending',
        AppointmentStatus.approved => 'Approved',
        AppointmentStatus.declined => 'Declined',
        AppointmentStatus.completed => 'Completed',
        AppointmentStatus.cancelled => 'Cancelled',
        AppointmentStatus.rescheduled => 'Rescheduled',
      };

  /// 🟡 Pending 🟢 Approved 🔵 Completed 🔴 Declined ⚪ Cancelled
  Color get color => switch (this) {
        AppointmentStatus.pending => const Color(0xFFE0A800),
        AppointmentStatus.approved => const Color(0xFF00C48C),
        AppointmentStatus.completed => const Color(0xFF3E678A),
        AppointmentStatus.declined => const Color(0xFFD64577),
        AppointmentStatus.cancelled => const Color(0xFF8A6070),
        AppointmentStatus.rescheduled => const Color(0xFF8E5FD6),
      };

  Color get paleColor => switch (this) {
        AppointmentStatus.pending => const Color(0xFFFCF0D2),
        AppointmentStatus.approved => const Color(0xFFDCF7EE),
        AppointmentStatus.completed => const Color(0xFFDCEBF5),
        AppointmentStatus.declined => const Color(0xFFF9E1EA),
        AppointmentStatus.cancelled => const Color(0xFFEDE7EA),
        AppointmentStatus.rescheduled => const Color(0xFFEBE2FA),
      };
}

class AppointmentModel {
  final String id;
  final String studentId;
  final String teacherId;
  final String? teacherName;
  final String? studentName;
  // ⚠️ NEW: appointments.controller.js's shared join now selects
  // t.avatar_url / s.avatar_url as teacher_avatar_url / student_avatar_url
  // — without these, every appointment card fell back to initials-only
  // even for users with an uploaded profile photo.
  final String? teacherAvatarUrl;
  final String? studentAvatarUrl;
  final String title;
  final String purpose;
  final String subject;
  final DateTime preferredDate;
  final String preferredTime; // 'HH:MM' as returned by the API
  final String? description;
  final String? attachmentUrl;
  final AppointmentStatus status;
  final String? teacherNotes;
  final String? declineReason;
  final DateTime? proposedDate;
  final String? proposedTime;
  final DateTime requestDate;

  const AppointmentModel({
    required this.id,
    required this.studentId,
    required this.teacherId,
    this.teacherName,
    this.studentName,
    this.teacherAvatarUrl,
    this.studentAvatarUrl,
    required this.title,
    required this.purpose,
    required this.subject,
    required this.preferredDate,
    required this.preferredTime,
    this.description,
    this.attachmentUrl,
    required this.status,
    this.teacherNotes,
    this.declineReason,
    this.proposedDate,
    this.proposedTime,
    required this.requestDate,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      // ⚠️ FIXED: id/student_id/teacher_id were cast with `as String`,
      // which throws if the JSON value arrives as a number. users.id is
      // INTEGER on the live schema (confirmed while running the
      // 0004_appointments.sql migration — it originally assumed UUID and
      // had to be corrected), so student_id/teacher_id come back as JSON
      // numbers, not strings. .toString() handles either shape safely —
      // same pattern TeacherProfileModel already uses for its own `id`.
      id: json['id'].toString(),
      studentId: json['student_id'].toString(),
      teacherId: json['teacher_id'].toString(),
      teacherName: json['teacher_name'] as String?,
      studentName: json['student_name'] as String?,
      teacherAvatarUrl: json['teacher_avatar_url'] as String?,
      studentAvatarUrl: json['student_avatar_url'] as String?,
      title: json['title'] as String,
      purpose: json['purpose'] as String,
      subject: json['subject'] as String,
      preferredDate: DateTime.parse(json['preferred_date'] as String),
      // Postgres TIME comes back like "14:30:00" — keep just HH:MM for display.
      preferredTime: (json['preferred_time'] as String).substring(0, 5),
      description: json['description'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      status: AppointmentStatusX.fromApi(json['status'] as String),
      teacherNotes: json['teacher_notes'] as String?,
      declineReason: json['decline_reason'] as String?,
      proposedDate: json['proposed_date'] != null
          ? DateTime.parse(json['proposed_date'] as String)
          : null,
      proposedTime: json['proposed_time'] != null
          ? (json['proposed_time'] as String).substring(0, 5)
          : null,
      requestDate: DateTime.parse(json['request_date'] as String),
    );
  }
}
