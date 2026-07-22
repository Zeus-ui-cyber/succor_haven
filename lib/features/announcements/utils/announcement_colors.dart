
// lib/features/announcements/utils/announcement_colors.dart
//
// Single source of truth for the palette used across every
// student/teacher-facing announcement widget (feed section, hero banner,
// card, detail screen, list screen). Values match the private `_C` classes
// already duplicated in student_dashboard_screen.dart, teacher_dashboard_
// screen.dart, and admin_dashboard_screen.dart — kept as a shared constant
// here instead of a 4th copy so the announcement feature stays visually
// identical to the rest of the app without touching those existing files.
import 'package:flutter/material.dart';

class AnnouncementColors {
  static const burgundy = Color(0xFF7D002B);
  static const magenta = Color(0xFFD64577);
  static const blushPink = Color(0xFFF2C6D6);
  static const softPink = Color(0xFFF9E1EA);
  static const slateBlue = Color(0xFF3E678A);
  static const bluePale = Color(0xFFDCEBF5);
  static const cream = Color(0xFFFFF5F7);
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
  static const line = Color(0xFFF0DCE5);
  static const paper = Color(0xFFFFFFFF);
  static const green = Color(0xFF00C48C);
  static const greenPale = Color(0xFFDCF7EE);
  static const purple = Color(0xFF8E5FD6);
  static const amber = Color(0xFFB8860B);
  static const amberPale = Color(0xFFFFF3CD);
  static const red = Color(0xFFB00020);
}
