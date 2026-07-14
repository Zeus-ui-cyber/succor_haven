// lib/features/sessions/controllers/files_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session_file.dart';
import '../repositories/sessions_repository.dart';
import 'session_list_controller.dart' show sessionsRepositoryProvider;

final sessionFilesProvider = FutureProvider.autoDispose
    .family<List<SessionFileModel>, String>((ref, sessionId) async {
  final repo = ref.watch(sessionsRepositoryProvider);
  final rows = await repo.getSessionFiles(sessionId);
  return rows.map(SessionFileModel.fromJson).toList();
});

/// Teacher-only upload action, separate from the read-only list provider
/// above (same split pattern as AppointmentActionsController elsewhere in
/// this app) so the Files panel can show upload-in-progress state without
/// re-fetching the whole list on every keystroke.
class FilesUploadController extends StateNotifier<AsyncValue<void>> {
  final SessionsRepository _repo;
  final Ref _ref;
  final String sessionId;

  FilesUploadController(this._repo, this._ref, this.sessionId)
      : super(const AsyncData(null));

  Future<bool> upload({
    required List<int> fileBytes,
    required String fileName,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.uploadSessionFile(
        sessionId,
        fileBytes: fileBytes,
        fileName: fileName,
      );
      state = const AsyncData(null);
      _ref.invalidate(sessionFilesProvider(sessionId));
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final filesUploadControllerProvider = StateNotifierProvider.autoDispose
    .family<FilesUploadController, AsyncValue<void>, String>((ref, sessionId) {
  return FilesUploadController(
    ref.read(sessionsRepositoryProvider),
    ref,
    sessionId,
  );
});
