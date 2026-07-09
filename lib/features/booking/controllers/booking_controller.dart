// lib/features/booking/controllers/booking_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/teacher_profile.dart';
import '../repositories/booking_repository.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository();
});

/// Current search text for the teacher directory. Updating this
/// automatically re-fetches [teachersListProvider].
final teacherSearchQueryProvider = StateProvider<String>((ref) => '');

/// The teacher directory list, filtered by [teacherSearchQueryProvider].
final teachersListProvider =
    FutureProvider.autoDispose<List<TeacherProfileModel>>((ref) async {
  final repo = ref.watch(bookingRepositoryProvider);
  final query = ref.watch(teacherSearchQueryProvider);
  return repo.browseTeachers(search: query.isEmpty ? null : query);
});

/// A single teacher's full profile (bio, subjects, availability), fetched
/// fresh per teacherId so the details page never shows stale data.
final teacherDetailsProvider = FutureProvider.autoDispose
    .family<TeacherProfileModel, String>((ref, teacherId) async {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getTeacherDetails(teacherId);
});