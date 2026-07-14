// lib/models/session.dart
//
// Mirrors the unified feed returned by GET /sessions/mine
// (session.service.js's listMine()) — a mix of real `sessions` rows
// (kind: 'session') and not-yet-approved appointment requests
// (kind: 'pending_appointment') so the "My Sessions" list can show the
// full lifecycle described in the product spec, from "Pending Approval"
// through to "Completed", from a single endpoint.

import 'package:flutter/material.dart';

enum SessionCardStatus {
  pending,
  declined,
  rescheduled,
  upcoming,
  inProgress,
  completed,
  cancelled,
  missed,
}

extension SessionCardStatusX on SessionCardStatus {
  static SessionCardStatus fromApi(String value) {
    switch (value) {
      case 'pending':
        return SessionCardStatus.pending;
      case 'declined':
        return SessionCardStatus.declined;
      case 'rescheduled':
        return SessionCardStatus.rescheduled;
      case 'upcoming':
        return SessionCardStatus.upcoming;
      case 'in_progress':
        return SessionCardStatus.inProgress;
      case 'completed':
        return SessionCardStatus.completed;
      case 'cancelled':
        return SessionCardStatus.cancelled;
      case 'missed':
        return SessionCardStatus.missed;
      default:
        return SessionCardStatus.upcoming;
    }
  }

  /// Badge text per the product spec's session-state list.
  String get badgeLabel => switch (this) {
        SessionCardStatus.pending => 'Waiting for Teacher Approval · 待批准',
        SessionCardStatus.declined => 'Declined · 已拒绝',
        SessionCardStatus.rescheduled => 'New Schedule Proposed · 改期建议',
        SessionCardStatus.upcoming => 'Upcoming · 即将上课',
        SessionCardStatus.inProgress => 'In Progress · 进行中',
        SessionCardStatus.completed => 'Completed · 已完成',
        SessionCardStatus.cancelled => 'Cancelled · 已取消',
        SessionCardStatus.missed => 'Missed Session · 错过课程',
      };

  /// Same palette family as AppointmentStatusX (appointment.dart), so a
  /// session badge and an appointment badge never clash visually even
  /// though they're rendered side by side in the unified "My Sessions" list.
  Color get color => switch (this) {
        SessionCardStatus.pending => const Color(0xFFE0A800),
        SessionCardStatus.declined => const Color(0xFFD64577),
        SessionCardStatus.rescheduled => const Color(0xFF8E5FD6),
        SessionCardStatus.upcoming => const Color(0xFF3E678A),
        SessionCardStatus.inProgress => const Color(0xFF00C48C),
        SessionCardStatus.completed => const Color(0xFF3E678A),
        SessionCardStatus.cancelled => const Color(0xFF8A6070),
        SessionCardStatus.missed => const Color(0xFFD64577),
      };

  Color get paleColor => switch (this) {
        SessionCardStatus.pending => const Color(0xFFFCF0D2),
        SessionCardStatus.declined => const Color(0xFFF9E1EA),
        SessionCardStatus.rescheduled => const Color(0xFFEBE2FA),
        SessionCardStatus.upcoming => const Color(0xFFDCEBF5),
        SessionCardStatus.inProgress => const Color(0xFFDCF7EE),
        SessionCardStatus.completed => const Color(0xFFDCEBF5),
        SessionCardStatus.cancelled => const Color(0xFFEDE7EA),
        SessionCardStatus.missed => const Color(0xFFF9E1EA),
      };
}

class SessionModel {
  final String id;
  final bool isPendingAppointment; // kind == 'pending_appointment'
  final String subject;
  final String? title;
  final DateTime? scheduledAt; // null only for a still-pending appointment
  final int durationMins;
  final SessionCardStatus status;
  final String teacherId;
  final String studentId;
  final String? teacherName;
  final String? studentName;
  final String? teacherAvatarUrl;
  final String? studentAvatarUrl;
  final String? roomId; // only present once it's a real session

  const SessionModel({
    required this.id,
    required this.isPendingAppointment,
    required this.subject,
    this.title,
    this.scheduledAt,
    required this.durationMins,
    required this.status,
    required this.teacherId,
    required this.studentId,
    this.teacherName,
    this.studentName,
    this.teacherAvatarUrl,
    this.studentAvatarUrl,
    this.roomId,
  });

  DateTime? get scheduledEndAt =>
      scheduledAt?.add(Duration(minutes: durationMins));

  /// Per spec: "The Join Meeting button must remain disabled until the
  /// scheduled meeting time" — exactly at start, not some minutes-before
  /// window like the older `bookings` flow used.
  bool isJoinable({DateTime? now}) {
    if (isPendingAppointment || scheduledAt == null) return false;
    if (status != SessionCardStatus.upcoming &&
        status != SessionCardStatus.inProgress) {
      return false;
    }
    final n = now ?? DateTime.now();
    return !n.isBefore(scheduledAt!) && n.isBefore(scheduledEndAt!);
  }

  Duration? timeUntilJoinable({DateTime? now}) {
    if (isPendingAppointment || scheduledAt == null) return null;
    final n = now ?? DateTime.now();
    final diff = scheduledAt!.difference(n);
    return diff.isNegative ? null : diff;
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Human-readable local schedule, e.g. "Jul 20, 2026 · 9:30 AM" — shared
  /// by session_card.dart and session_detail_screen.dart so the two never
  /// drift into showing different formats (or, worse, different times).
  String? get formattedSchedule {
    final dt = scheduledAt;
    if (dt == null) return null;
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${_months[dt.month - 1]} ${dt.day}, ${dt.year} · '
        '$hour12:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String? ?? 'session';
    final isPending = kind == 'pending_appointment';

    DateTime? scheduledAt;
    if (json['scheduled_at'] != null) {
      // ⚠️ FIXED: the backend returns scheduled_at as a UTC ISO string
      // (TIMESTAMPTZ columns serialize with a 'Z' suffix). Without
      // .toLocal(), every place that reads .hour/.minute/.day off this
      // DateTime (session_card.dart, session_detail_screen.dart) would
      // display the raw UTC digits instead of this device's actual local
      // clock time — right instant, wrong-looking time on screen.
      scheduledAt = DateTime.parse(json['scheduled_at'] as String).toLocal();
    } else if (json['preferred_date'] != null &&
        json['preferred_time'] != null) {
      final date = DateTime.parse(json['preferred_date'] as String);
      final timeParts = (json['preferred_time'] as String).split(':');
      scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
    }

    return SessionModel(
      id: json['id'].toString(),
      isPendingAppointment: isPending,
      subject: json['subject'] as String? ?? 'Session',
      title: json['title'] as String?,
      scheduledAt: scheduledAt,
      durationMins: (json['duration_mins'] as num?)?.toInt() ?? 30,
      status: SessionCardStatusX.fromApi(json['status'] as String? ?? 'upcoming'),
      teacherId: json['teacher_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      teacherName: json['teacher_name'] as String?,
      studentName: json['student_name'] as String?,
      teacherAvatarUrl: json['teacher_avatar_url'] as String?,
      studentAvatarUrl: json['student_avatar_url'] as String?,
      roomId: json['room_id'] as String?,
    );
  }
}
