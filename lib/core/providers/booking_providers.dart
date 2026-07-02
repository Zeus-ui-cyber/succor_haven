  // lib/core/providers/booking_providers.dart
//
// Shared providers used across the student dashboard and the teacher
// browse/booking flow. Pulled out of student_dashboard_screen.dart (where
// they used to be private, e.g. `_selectedBookingCourseProvider`) so that
// teacher_browse_screen.dart can read/write the same state instead of
// duplicating it.
//
// ⚠️ MIGRATION NOTE: student_dashboard_screen.dart currently defines its own
// private copies of these (`_selectedBookingCourseProvider`, `_sRepoProvider`,
// `_sTeachersProvider`). Replace those with imports of this file and delete
// the private versions, so there's a single source of truth. See the bottom
// of this file for the exact find/replace list.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../features/auth/repositories/auth_repository.dart';
import '../../../models/course.dart';

/// Shared auth repository instance.
final authRepoProvider = Provider((_) => AuthRepository());

/// Carries the course the student picked in the Book tab across to the Find
/// Teachers tab, so tapping "Book Now" on a teacher card knows which
/// pricingId/creditsPerSession to book at. Cleared after a booking is made.
final selectedBookingCourseProvider = StateProvider<CourseModel?>((ref) => null);

/// Real teacher list from GET /teachers. Kept as raw maps (not a strict
/// model) since teachers.controller.js browse() only returns full_name,
/// subjects, rating, and total_sessions — no bio/certifications/testimonials.
final teachersProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(authRepoProvider);
  final token = await repo.getAccessToken();
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/teachers?limit=6'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (res.statusCode != 200) return [];
  return jsonDecode(res.body) as List;
});

// ─────────────────────────────────────────────────────────────────────────
// MIGRATION: in student_dashboard_screen.dart, delete these three private
// providers and the import block for http/dart:convert if nothing else in
// that file needs them, then import this file:
//
//   import '../../core/providers/booking_providers.dart';
//
// Find/replace throughout student_dashboard_screen.dart:
//   _selectedBookingCourseProvider  →  selectedBookingCourseProvider
//   _sTeachersProvider              →  teachersProvider
//   _sRepoProvider                  →  authRepoProvider   (only where it's
//                                       used for the teacher-related calls;
//                                       leave _sRepoProvider alone if other
//                                       providers in that file still need a
//                                       private copy, or better, replace all
//                                       uses of _sRepoProvider with
//                                       authRepoProvider and delete it)
// ─────────────────────────────────────────────────────────────────────────