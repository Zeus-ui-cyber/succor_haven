// lib/models/booking.dart
//
// Mirrors the REAL joined shape returned by bookings.controller.js list():
//   b.*, s.full_name AS student_name, t.full_name AS teacher_name,
//   tp.avatar_url AS teacher_avatar, p.name AS pricing_name, p.session_type

enum BookingStatus { pending, confirmed, completed, cancelled }

extension BookingStatusX on BookingStatus {
  String get apiValue => name;

  static BookingStatus fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'pending':
        return BookingStatus.pending;
      case 'confirmed':
        return BookingStatus.confirmed;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
        return BookingStatus.cancelled;
      default:
        return BookingStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class BookingModel {
  final String id;
  final String studentId;
  final String teacherId;
  final String? pricingId;
  final DateTime scheduledAt;
  final int durationMins;
  final int creditsCost;
  final BookingStatus status;
  final String? notes;

  // Joined display fields — ⚠️ CHANGED: full_name, not first/last split
  final String? studentName;
  final String? teacherName;
  final String? teacherAvatarUrl;
  final String? pricingName;   // e.g. "1v1 Standard"
  final String? sessionType;   // pricing.session_type

  const BookingModel({
    required this.id,
    required this.studentId,
    required this.teacherId,
    this.pricingId,
    required this.scheduledAt,
    required this.durationMins,
    required this.creditsCost,
    required this.status,
    this.notes,
    this.studentName,
    this.teacherName,
    this.teacherAvatarUrl,
    this.pricingName,
    this.sessionType,
  });

  // ── Derived / session helpers ─────────────────────────────────────────────

  DateTime get scheduledEndAt => scheduledAt.add(Duration(minutes: durationMins));

  static const int joinWindowMinutes = 10;

  DateTime get joinWindowOpensAt =>
      scheduledAt.subtract(const Duration(minutes: joinWindowMinutes));

  bool isJoinable({DateTime? now}) {
    final n = now ?? DateTime.now();
    if (status != BookingStatus.confirmed) return false;
    return n.isAfter(joinWindowOpensAt) && n.isBefore(scheduledEndAt);
  }

  bool get isUpcoming =>
      status == BookingStatus.confirmed && DateTime.now().isBefore(joinWindowOpensAt);

  bool get isPast =>
      status == BookingStatus.completed || status == BookingStatus.cancelled;

  // ── Serialization ──────────────────────────────────────────────────────────

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        id: json['id'].toString(),
        studentId: json['student_id'].toString(),
        teacherId: json['teacher_id'].toString(),
        pricingId: json['pricing_id']?.toString(),
        scheduledAt: DateTime.parse(json['scheduled_at'] as String),
        durationMins: (json['duration_mins'] as num?)?.toInt() ?? 30,
        creditsCost: (json['credits_cost'] as num?)?.toInt() ?? 0,
        status: BookingStatusX.fromString(json['status'] as String? ?? 'pending'),
        notes: json['notes'] as String?,
        studentName: json['student_name'] as String?,
        teacherName: json['teacher_name'] as String?,
        teacherAvatarUrl: json['teacher_avatar'] as String?,
        pricingName: json['pricing_name'] as String?,
        sessionType: json['session_type'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'student_id': studentId,
        'teacher_id': teacherId,
        'pricing_id': pricingId,
        'scheduled_at': scheduledAt.toIso8601String(),
        'duration_mins': durationMins,
        'credits_cost': creditsCost,
        'status': status.apiValue,
        'notes': notes,
        'student_name': studentName,
        'teacher_name': teacherName,
        'teacher_avatar': teacherAvatarUrl,
        'pricing_name': pricingName,
        'session_type': sessionType,
      };

  BookingModel copyWith({
    String? id,
    String? studentId,
    String? teacherId,
    String? pricingId,
    DateTime? scheduledAt,
    int? durationMins,
    int? creditsCost,
    BookingStatus? status,
    String? notes,
    String? studentName,
    String? teacherName,
    String? teacherAvatarUrl,
    String? pricingName,
    String? sessionType,
  }) =>
      BookingModel(
        id: id ?? this.id,
        studentId: studentId ?? this.studentId,
        teacherId: teacherId ?? this.teacherId,
        pricingId: pricingId ?? this.pricingId,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        durationMins: durationMins ?? this.durationMins,
        creditsCost: creditsCost ?? this.creditsCost,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        studentName: studentName ?? this.studentName,
        teacherName: teacherName ?? this.teacherName,
        teacherAvatarUrl: teacherAvatarUrl ?? this.teacherAvatarUrl,
        pricingName: pricingName ?? this.pricingName,
        sessionType: sessionType ?? this.sessionType,
      );
}