// lib/models/user.dart
//
// Defensive fromJson — handles BOTH backend shapes:
//   Shape A (old): { first_name, last_name, ... }
//   Shape B (new): { full_name, ... }
// So the app works whether or not you've migrated the DB column.
//
// ⚠️ FIXED: avatar image was read from `profile_picture_url`, but the
// real column (confirmed against the live Neon schema) is `avatar_url` —
// settings.controller.js and auth.controller.js were already corrected to
// use avatar_url, this model just hadn't been updated to match, so every
// response silently had a null avatar despite the backend sending real
// data under a different key. Property name kept as `profilePictureUrl`
// (in case other files reference it) — only the JSON key it reads from
// changed.

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String languagePref;
  final int credits;
  final int points;
  final DateTime createdAt;
  final bool teacherApproved;
  final String? profilePictureUrl;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.languagePref = 'en',
    this.credits = 0,
    this.points = 0,
    required this.createdAt,
    this.teacherApproved = false,
    this.profilePictureUrl,
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

  bool get isStudent => role == 'student';
  bool get isTeacher => role == 'teacher';
  bool get isAdmin   => role == 'admin';

  // ── Factory ───────────────────────────────────────────────────────────────
  factory UserModel.fromJson(Map<String, dynamic> json) {
    // ① Resolve full name — accept full_name OR first_name + last_name
    final rawFull  = json['full_name']   as String?;
    final rawFirst = json['first_name']  as String? ?? '';
    final rawLast  = json['last_name']   as String? ?? '';
    final resolvedName = (rawFull != null && rawFull.trim().isNotEmpty)
        ? rawFull.trim()
        : '$rawFirst $rawLast'.trim();

    // ② Resolve createdAt — null-safe parse
    DateTime resolvedDate;
    try {
      resolvedDate = DateTime.parse(json['created_at'] as String);
    } catch (_) {
      resolvedDate = DateTime.now();
    }

    return UserModel(
      id:              json['id']?.toString() ?? '',
      email:           json['email']  as String?  ?? '',
      fullName:        resolvedName,
      role:            json['role']   as String?  ?? 'student',
      languagePref:    json['language_pref'] as String? ?? 'en',
      credits:         (json['credits']  as num?)?.toInt() ?? 0,
      points:          (json['points']   as num?)?.toInt() ?? 0,
      createdAt:       resolvedDate,
      teacherApproved: json['teacher_approved'] as bool? ?? false,
      profilePictureUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id':                 id,
        'email':              email,
        'full_name':          fullName,
        'role':               role,
        'language_pref':      languagePref,
        'credits':            credits,
        'points':             points,
        'created_at':         createdAt.toIso8601String(),
        'teacher_approved':   teacherApproved,
        'avatar_url':         profilePictureUrl,
      };

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? languagePref,
    int? credits,
    int? points,
    DateTime? createdAt,
    bool? teacherApproved,
    String? profilePictureUrl,
  }) =>
      UserModel(
        id:              id              ?? this.id,
        email:           email           ?? this.email,
        fullName:        fullName        ?? this.fullName,
        role:            role            ?? this.role,
        languagePref:    languagePref    ?? this.languagePref,
        credits:         credits         ?? this.credits,
        points:          points          ?? this.points,
        createdAt:       createdAt       ?? this.createdAt,
        teacherApproved: teacherApproved ?? this.teacherApproved,
        profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      );
}