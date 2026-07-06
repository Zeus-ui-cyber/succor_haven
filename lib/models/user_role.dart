import 'package:flutter/material.dart';

enum UserRole { student, teacher, admin }

extension UserRoleX on UserRole {
  // ── Display labels ─────────────────────────────────────────────────────────
  String get label {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.admin:
        return 'Admin';
    }
  }

  String get labelCn {
    switch (this) {
      case UserRole.student:
        return '学生';
      case UserRole.teacher:
        return '老师';
      case UserRole.admin:
        return '管理员';
    }
  }

  // ── Emoji ──────────────────────────────────────────────────────────────────
  String get emoji {
    switch (this) {
      case UserRole.student:
        return '📚';
      case UserRole.teacher:
        return '🎓';
      case UserRole.admin:
        return '🛡️';
    }
  }

  // ── Colors ─────────────────────────────────────────────────────────────────
  Color get accent {
    switch (this) {
      case UserRole.student:
        return const Color(0xFFD64577); // magenta
      case UserRole.teacher:
        return const Color(0xFF3E678A); // slate blue
      case UserRole.admin:
        return const Color(0xFF7D002B); // burgundy
    }
  }

  Color get accentPale {
    switch (this) {
      case UserRole.student:
        return const Color(0xFFF2C6D6); // blush pink
      case UserRole.teacher:
        return const Color(0xFFA7BCCB)
            .withValues(alpha: 0.35); // dusty blue pale
      case UserRole.admin:
        return const Color(0xFFF2C6D6); // blush pink
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  // For teachers, always go to pending first — the pending screen will
  // redirect to '/teacher-dashboard' automatically once approved.
  // Call routeForTeacher(isApproved) instead for runtime routing.
  String get routeOnLogin {
    switch (this) {
      case UserRole.student:
        return '/dashboard';
      case UserRole.teacher:
        return '/teacher-pending';
      case UserRole.admin:
        return '/admin-dashboard';
    }
  }

  /// Use this when you have the teacher's approval status at login time.
  /// Falls back to routeOnLogin for non-teacher roles.
  String routeForTeacher(bool isApproved) {
    if (this == UserRole.teacher) {
      return isApproved ? '/teacher-dashboard' : '/teacher-pending';
    }
    return routeOnLogin;
  }

  // ── API string ─────────────────────────────────────────────────────────── ✅ NEW
  // .name already returns 'student'|'teacher'|'admin' — alias for clarity
  String get apiValue => name;

  // ── From raw API string ────────────────────────────────────────────────── ✅ NEW
  // Usage: UserRole.fromString(json['role'])
  static UserRole fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'teacher':
        return UserRole.teacher;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.student;
    }
  }

  // ── Permission checks ──────────────────────────────────────────────────── ✅ NEW
  bool get canManageUsers => this == UserRole.admin;
  bool get canTeach => this == UserRole.teacher || this == UserRole.admin;
  bool get canBook => this == UserRole.student;

  // ── Bilingual combined label ───────────────────────────────────────────── ✅ NEW
  // e.g. "Student · 学生"
  String get labelBilingual => '$label · $labelCn';
}
