// lib/features/sessions/controllers/session_list_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session.dart';
import '../repositories/sessions_repository.dart';

final sessionsRepositoryProvider =
    Provider<SessionsRepository>((ref) => SessionsRepository());

/// The unified "My Sessions" feed for the current user (student or
/// teacher — the backend scopes by role). autoDispose + a manual
/// ref.invalidate() after actions (e.g. approving an appointment) is the
/// refresh pattern used everywhere else in this app; there's no
/// real-time push for list updates yet.
final mySessionsProvider =
    FutureProvider.autoDispose<List<SessionModel>>((ref) async {
  final repo = ref.watch(sessionsRepositoryProvider);
  return repo.getMySessions();
});

final sessionDetailProvider = FutureProvider.autoDispose
    .family<SessionModel, String>((ref, sessionId) async {
  final repo = ref.watch(sessionsRepositoryProvider);
  return repo.getSessionById(sessionId);
});
