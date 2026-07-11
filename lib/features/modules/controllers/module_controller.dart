// lib/features/modules/controllers/module_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../models/module.dart';
import '../repositories/module_repository.dart';

final _moduleAuthRepoProvider = Provider((_) => AuthRepository());

final moduleRepositoryProvider = Provider<ModuleRepository>(
  (ref) => ModuleRepository(ref.read(_moduleAuthRepoProvider)),
);

final moduleSearchQueryProvider = StateProvider<String>((ref) => '');
final moduleSubjectFilterProvider = StateProvider<String>((ref) => '');

final modulesListProvider =
    FutureProvider.autoDispose<List<ModuleModel>>((ref) async {
  final repo = ref.watch(moduleRepositoryProvider);
  final search = ref.watch(moduleSearchQueryProvider);
  final subject = ref.watch(moduleSubjectFilterProvider);
  return repo.listModules(
    search: search.isEmpty ? null : search,
    subject: subject.isEmpty ? null : subject,
  );
});

class ModuleActionsController extends StateNotifier<AsyncValue<void>> {
  final ModuleRepository _repo;
  final Ref _ref;
  ModuleActionsController(this._repo, this._ref)
      : super(const AsyncData(null));

  Future<bool> upload({
    required String title,
    required String subject,
    String? description,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.uploadModule(
        title: title,
        subject: subject,
        description: description,
        fileBytes: fileBytes,
        fileName: fileName,
      );
      state = const AsyncData(null);
      _ref.invalidate(modulesListProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> update({
    required String id,
    String? title,
    String? subject,
    String? description,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.updateModule(
        id: id,
        title: title,
        subject: subject,
        description: description,
        fileBytes: fileBytes,
        fileName: fileName,
      );
      state = const AsyncData(null);
      _ref.invalidate(modulesListProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> delete(String id) async {
    state = const AsyncLoading();
    try {
      await _repo.deleteModule(id);
      state = const AsyncData(null);
      _ref.invalidate(modulesListProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final moduleActionsProvider =
    StateNotifierProvider<ModuleActionsController, AsyncValue<void>>(
  (ref) => ModuleActionsController(ref.read(moduleRepositoryProvider), ref),
);