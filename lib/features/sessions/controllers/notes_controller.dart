// lib/features/sessions/controllers/notes_controller.dart
//
// Live student notes — autosaves 1.2s after typing stops rather than on
// every keystroke, matching the mockup's "Last saved 2:45 PM" indicator.
// Teacher role gets a permanently-empty, no-op instance (see
// sessions.controller.js's getMyNotes/saveMyNotes — notes are
// student-only; a teacher's separate "Teacher Notes" is the existing
// appointments.teacher_notes field).

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/sessions_repository.dart';
import 'session_list_controller.dart' show sessionsRepositoryProvider;

class NotesState {
  final String content;
  final bool loading;
  final bool saving;
  final DateTime? lastSavedAt;

  const NotesState({
    required this.content,
    required this.loading,
    required this.saving,
    this.lastSavedAt,
  });

  factory NotesState.initial() =>
      const NotesState(content: '', loading: true, saving: false);

  NotesState copyWith({
    String? content,
    bool? loading,
    bool? saving,
    DateTime? lastSavedAt,
  }) =>
      NotesState(
        content: content ?? this.content,
        loading: loading ?? this.loading,
        saving: saving ?? this.saving,
        lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      );
}

class NotesController extends StateNotifier<NotesState> {
  final SessionsRepository _repo;
  final String sessionId;
  final bool enabled; // false for a teacher — read-only empty draft
  Timer? _debounce;

  NotesController(this._repo, this.sessionId, {required this.enabled})
      : super(NotesState.initial()) {
    if (enabled) {
      _load();
    } else {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> _load() async {
    try {
      final content = await _repo.getMyNotes(sessionId);
      state = state.copyWith(content: content, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  void update(String content) {
    if (!enabled) return;
    state = state.copyWith(content: content);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), _save);
  }

  Future<void> _save() async {
    if (!enabled) return;
    state = state.copyWith(saving: true);
    try {
      await _repo.saveMyNotes(sessionId, state.content);
      state = state.copyWith(saving: false, lastSavedAt: DateTime.now());
    } catch (_) {
      state = state.copyWith(saving: false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final notesControllerProvider = StateNotifierProvider.autoDispose
    .family<NotesController, NotesState, ({String sessionId, bool isStudent})>(
        (ref, args) {
  return NotesController(
    ref.read(sessionsRepositoryProvider),
    args.sessionId,
    enabled: args.isStudent,
  );
});
