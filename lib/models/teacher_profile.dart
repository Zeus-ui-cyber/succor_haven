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

class TeacherProfileModel {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? bio;
  final List<String> subjects;
  final List<String> availability; // e.g. ['Mon','Wed','Fri']
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
              ?.map((e) => e.toString())
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
        'availability': availability,
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
    List<String>? availability,
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