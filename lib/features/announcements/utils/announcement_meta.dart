// lib/features/announcements/utils/announcement_meta.dart
// Category/priority display metadata, shared by every announcement widget.
import 'package:flutter/material.dart';
import 'announcement_colors.dart';

const Map<String, String> kAnnouncementCategoryLabels = {
  'announcement': 'Announcement',
  'event': 'Event',
  'activity': 'Activity',
  'resource': 'Resource',
  'achievement': 'Achievement',
  'teacher_update': 'Teacher Update',
  'student_update': 'Student Update',
  'module': 'New Module',
  'emergency': 'Emergency',
  'tip': 'Tip',
};

const Map<String, IconData> kAnnouncementCategoryIcons = {
  'announcement': Icons.campaign_rounded,
  'event': Icons.celebration_rounded,
  'activity': Icons.event_available_rounded,
  'resource': Icons.menu_book_rounded,
  'achievement': Icons.emoji_events_rounded,
  'teacher_update': Icons.person_rounded,
  'student_update': Icons.school_rounded,
  'module': Icons.auto_stories_rounded,
  'emergency': Icons.warning_amber_rounded,
  'tip': Icons.lightbulb_rounded,
};

const Map<String, String> kAnnouncementPriorityLabels = {
  'normal': 'Normal',
  'important': 'Important',
  'critical': 'Critical',
};

Color announcementPriorityColor(String priority) {
  switch (priority) {
    case 'critical':
      return AnnouncementColors.red;
    case 'important':
      return AnnouncementColors.amber;
    default:
      return AnnouncementColors.slateBlue;
  }
}

String announcementCategoryLabel(String category) =>
    kAnnouncementCategoryLabels[category] ?? category;

IconData announcementCategoryIcon(String category) =>
    kAnnouncementCategoryIcons[category] ?? Icons.campaign_rounded;

/// 'Jan 5, 2026' — no `intl` dependency in this project, so months are
/// spelled out by hand the same way the rest of the app hand-formats dates.
String formatAnnouncementDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
