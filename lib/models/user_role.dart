import 'package:flutter/material.dart';

enum UserRole { student, teacher, admin }

extension UserRoleX on UserRole {
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
        return const Color(0xFFA7BCCB).withOpacity(0.35); // dusty blue pale
      case UserRole.admin:
        return const Color(0xFFF2C6D6); // blush pink
    }
  }

  String get routeOnLogin {
    switch (this) {
      case UserRole.student:
        return '/dashboard';
      case UserRole.teacher:
        return '/teacher-dashboard';
      case UserRole.admin:
        return '/admin-dashboard';
    }
  }
}
