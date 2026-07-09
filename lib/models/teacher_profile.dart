// lib/models/teacher_profile.dart
//
// Mirrors the joined shape actually returned by teachers.controller.js:
//   browse()  -> u.id, full_name, avatar_url,
//                tp.bio, subjects, availability,
//                rating, total_sessions
//   getOne()  -> same + u.created_at
//
// NOTE: the API returns `full_name`, not `first_name`/`last_name` — this
// mirrors the same fix already applied to UserModel. firstName/lastName
// below are derived getters kept only for backward-compat with widgets
// that still reference them.
//
// NOTE: `credits_per_session` does not exist on teacher_profiles and is
// not returned by the controller (see its comment: pricing lives
// elsewhere). It has been removed from this model — do not reintroduce
// it without first confirming where session pricing actually comes from
// (likely a `pricing`/`sessions` table or endpoint).
//
// FIXED: `availability` was previously typed as `List<String>` (e.g.
// ['Mon','Wed','Fri']), but teacher_profiles.availability is actually a
// JSONB array of *slot objects* — { id, day, startTime, endTime } — as
// written by teachers.controller.js's addAvailabilitySlot/updateAvailabilitySlot
// (see VALID_DAYS / validateSlotShape there). The old fromJson called
// `.toString()` on each slot map, which produced garbage strings like
// "{id: ..., day: monday, startTime: 08:00, endTime: 12:00}" instead of a
// real schedule. `availability` is now `List<TeacherAvailabilitySlot>`.

const List<String> kWeekdayOrder = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

/// One recurring weekly availability slot, as configured by the teacher in
/// Settings > Set Availability. `day` is lowercase ('monday'..'sunday');
/// `startTime`/`endTime` are 'HH:MM' 24-hour strings, exactly as stored.
class TeacherAvailabilitySlot {
  final String id;
  final String day;
  final String startTime;
  final String endTime;

  const TeacherAvailabilitySlot({
    required this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  factory TeacherAvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return TeacherAvailabilitySlot(
      id: json['id']?.toString() ?? '',
      day: (json['day'] as String? ?? '').toLowerCase().trim(),
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'day': day,
        'startTime': startTime,
        'endTime': endTime,
      };

  /// 'monday' -> 'Monday'
  String get displayDay =>
      day.isEmpty ? '' : '${day[0].toUpperCase()}${day.substring(1)}';

  static String _to12Hour(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final h = int.tryParse(parts[0]);
    if (h == null) return hhmm;
    final period = h >= 12 ? 'PM' : 'AM';
    var displayHour = h % 12;
    if (displayHour == 0) displayHour = 12;
    return '$displayHour:${parts[1]} $period';
  }

  /// e.g. "8:00 AM – 12:00 PM"
  String get displayRange => '${_to12Hour(startTime)} – ${_to12Hour(endTime)}';
}

class TeacherProfileModel {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? bio;
  final List<String> subjects;
  final List<TeacherAvailabilitySlot> availability;
  final double rating;
  final int totalSessions;
  final DateTime? createdAt; // only present on getOne()

  const TeacherProfileModel({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.bio,
    this.subjects = const [],
    this.availability = const [],
    this.rating = 0,
    this.totalSessions = 0,
    this.createdAt,
  });

  // ── Derived helpers (backward-compat with widgets using firstName/lastName)
  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : '';
  }

  String get lastName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final f = parts.first[0];
    final l = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return '$f$l'.toUpperCase();
  }

  bool get isNewTeacher => totalSessions == 0;
  bool get hasRating => rating > 0;

  /// Availability grouped by day and sorted Monday → Sunday, each day's
  /// slots sorted by start time. Convenience for display widgets.
  Map<String, List<TeacherAvailabilitySlot>> get groupedAvailability {
    final grouped = <String, List<TeacherAvailabilitySlot>>{};
    for (final slot in availability) {
      grouped.putIfAbsent(slot.day, () => []).add(slot);
    }
    for (final slots in grouped.values) {
      slots.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    return {
      for (final day in kWeekdayOrder)
        if (grouped.containsKey(day)) day: grouped[day]!,
    };
  }

  // ── Serialization ───────────────────────────────────────────────────────
  factory TeacherProfileModel.fromJson(Map<String, dynamic> json) {
    // Accept full_name OR first_name + last_name, same defensive pattern
    // as UserModel, in case an older/alternate endpoint is ever wired in.
    final rawFull = json['full_name'] as String?;
    final rawFirst = json['first_name'] as String? ?? '';
    final rawLast = json['last_name'] as String? ?? '';
    final resolvedName = (rawFull != null && rawFull.trim().isNotEmpty)
        ? rawFull.trim()
        : '$rawFirst $rawLast'.trim();

    return TeacherProfileModel(
      id: json['id'].toString(),
      fullName: resolvedName,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      subjects: (json['subjects'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      availability: (json['availability'] as List<dynamic>?)
              ?.map((e) =>
                  TeacherAvailabilitySlot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'bio': bio,
        'subjects': subjects,
        'availability': availability.map((s) => s.toJson()).toList(),
        'rating': rating,
        'total_sessions': totalSessions,
        'created_at': createdAt?.toIso8601String(),
      };

  TeacherProfileModel copyWith({
    String? id,
    String? fullName,
    String? avatarUrl,
    String? bio,
    List<String>? subjects,
    List<TeacherAvailabilitySlot>? availability,
    double? rating,
    int? totalSessions,
    DateTime? createdAt,
  }) =>
      TeacherProfileModel(
        id: id ?? this.id,
        fullName: fullName ?? this.fullName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        subjects: subjects ?? this.subjects,
        availability: availability ?? this.availability,
        rating: rating ?? this.rating,
        totalSessions: totalSessions ?? this.totalSessions,
        createdAt: createdAt ?? this.createdAt,
      );
}