// lib/features/announcements/controllers/announcement_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../models/announcement.dart';
import '../../../models/announcement_comment.dart';
import '../../../models/user.dart';
import '../repositories/announcement_repository.dart';

final _announcementAuthRepoProvider = Provider((_) => AuthRepository());

final announcementRepositoryProvider = Provider<AnnouncementRepository>(
  (ref) => AnnouncementRepository(ref.read(_announcementAuthRepoProvider)),
);

// Needed by the comments UI to decide whether to show a delete option on a
// given comment (own comment, or any comment if the viewer is an admin).
// authControllerProvider.state.user is only populated right after a fresh
// login, not on app resume, so this hits /auth/me directly instead — same
// pattern admin_dashboard_screen.dart's _adminMeProvider already uses.
final currentUserProvider = FutureProvider.autoDispose<UserModel>(
  (ref) => ref.read(_announcementAuthRepoProvider).getMe(),
);

final announcementIncludeArchivedProvider = StateProvider<bool>((ref) => false);

final adminAnnouncementsListProvider =
    FutureProvider.autoDispose<List<AnnouncementModel>>((ref) async {
  final repo = ref.watch(announcementRepositoryProvider);
  final includeArchived = ref.watch(announcementIncludeArchivedProvider);
  return repo.adminList(includeArchived: includeArchived);
});

// ── Student/teacher-facing feed (Home Dashboard "School Updates" section
// and the "See all" screen) ─────────────────────────────────────────────────
final announcementSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final announcementCategoryFilterProvider = StateProvider.autoDispose<String>((ref) => '');
// '' | 'important' | 'bookmarked' | 'unread' — 'important' maps to
// priority=important,critical isn't a single query param server-side, so
// it's applied client-side in the feed screen instead of here.
final announcementQuickFilterProvider = StateProvider.autoDispose<String>((ref) => '');

final announcementFeedProvider =
    FutureProvider.autoDispose<List<AnnouncementModel>>((ref) async {
  final repo = ref.watch(announcementRepositoryProvider);
  final search = ref.watch(announcementSearchQueryProvider);
  final category = ref.watch(announcementCategoryFilterProvider);
  final quickFilter = ref.watch(announcementQuickFilterProvider);
  return repo.list(
    search: search.isEmpty ? null : search,
    category: category.isEmpty ? null : category,
    filter: (quickFilter == 'bookmarked' || quickFilter == 'unread') ? quickFilter : null,
    limit: 50,
  );
});

final announcementDetailProvider = FutureProvider.autoDispose
    .family<AnnouncementModel, String>((ref, id) async {
  final repo = ref.watch(announcementRepositoryProvider);
  return repo.getOne(id);
});

// Related strip on the detail screen — same category, excluding itself.
final relatedAnnouncementsProvider = FutureProvider.autoDispose
    .family<List<AnnouncementModel>, ({String id, String category})>((ref, args) async {
  final repo = ref.watch(announcementRepositoryProvider);
  final items = await repo.list(category: args.category, limit: 10);
  return items.where((a) => a.id != args.id).toList();
});

// ── Comments / replies ──────────────────────────────────────────────────────
final announcementCommentsProvider = FutureProvider.autoDispose
    .family<List<AnnouncementCommentModel>, String>((ref, announcementId) async {
  final repo = ref.watch(announcementRepositoryProvider);
  return repo.listComments(announcementId);
});

class CommentActionsController extends StateNotifier<AsyncValue<void>> {
  final AnnouncementRepository _repo;
  final Ref _ref;
  CommentActionsController(this._repo, this._ref) : super(const AsyncData(null));

  Future<bool> add({
    required String announcementId,
    required String body,
    String? parentCommentId,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.addComment(
        announcementId: announcementId,
        body: body,
        parentCommentId: parentCommentId,
      );
      state = const AsyncData(null);
      _ref.invalidate(announcementCommentsProvider(announcementId));
      _ref.invalidate(announcementDetailProvider(announcementId));
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> delete({required String commentId, required String announcementId}) async {
    try {
      await _repo.deleteComment(commentId);
      _ref.invalidate(announcementCommentsProvider(announcementId));
      _ref.invalidate(announcementDetailProvider(announcementId));
      return true;
    } catch (_) {
      return false;
    }
  }
}

final commentActionsProvider =
    StateNotifierProvider<CommentActionsController, AsyncValue<void>>(
  (ref) => CommentActionsController(ref.read(announcementRepositoryProvider), ref),
);

class AnnouncementActionsController extends StateNotifier<AsyncValue<void>> {
  final AnnouncementRepository _repo;
  final Ref _ref;
  AnnouncementActionsController(this._repo, this._ref)
      : super(const AsyncData(null));

  Future<T?> _run<T>(Future<T> Function() action) async {
    state = const AsyncLoading();
    try {
      final result = await action();
      state = const AsyncData(null);
      _ref.invalidate(adminAnnouncementsListProvider);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<bool> create({
    required String title,
    String? subtitle,
    required String description,
    required String category,
    required String priority,
    required String visibility,
    String? targetValue,
    String? coverImageUrl,
    List<String>? galleryUrls,
    String? attachmentUrl,
    String? attachmentName,
    String? externalLink,
    DateTime? publishAt,
    DateTime? expiresAt,
    bool isPinned = false,
    bool commentsEnabled = false,
  }) async {
    final result = await _run(() => _repo.create(
          title: title,
          subtitle: subtitle,
          description: description,
          category: category,
          priority: priority,
          visibility: visibility,
          targetValue: targetValue,
          coverImageUrl: coverImageUrl,
          galleryUrls: galleryUrls,
          attachmentUrl: attachmentUrl,
          attachmentName: attachmentName,
          externalLink: externalLink,
          publishAt: publishAt,
          expiresAt: expiresAt,
          isPinned: isPinned,
          commentsEnabled: commentsEnabled,
        ));
    return result != null;
  }

  Future<bool> update({
    required String id,
    required String title,
    String? subtitle,
    required String description,
    required String category,
    required String priority,
    required String visibility,
    String? targetValue,
    String? coverImageUrl,
    List<String>? galleryUrls,
    String? attachmentUrl,
    String? attachmentName,
    String? externalLink,
    DateTime? publishAt,
    DateTime? expiresAt,
    bool isPinned = false,
    bool commentsEnabled = false,
  }) async {
    final result = await _run(() => _repo.update(
          id: id,
          title: title,
          subtitle: subtitle,
          description: description,
          category: category,
          priority: priority,
          visibility: visibility,
          targetValue: targetValue,
          coverImageUrl: coverImageUrl,
          galleryUrls: galleryUrls,
          attachmentUrl: attachmentUrl,
          attachmentName: attachmentName,
          externalLink: externalLink,
          publishAt: publishAt,
          expiresAt: expiresAt,
          isPinned: isPinned,
          commentsEnabled: commentsEnabled,
        ));
    return result != null;
  }

  Future<bool> delete(String id) async {
    final result = await _run(() async {
      await _repo.delete(id);
      return true;
    });
    return result ?? false;
  }

  Future<bool> togglePin(AnnouncementModel a) async {
    // pin()/unpin() return Future<void> — wrapped in an async lambda that
    // returns true so _run<T> infers T=bool instead of T=void (a bare
    // `() => _repo.pin(a.id)` made `result` void-typed, and `result != null`
    // on a void value is a real analyzer error: use_of_void_result).
    final result = await _run(() async {
      if (a.isPinned) {
        await _repo.unpin(a.id);
      } else {
        await _repo.pin(a.id);
      }
      return true;
    });
    return result ?? false;
  }

  Future<bool> toggleArchive(AnnouncementModel a) async {
    final result = await _run(() async {
      if (a.isArchived) {
        await _repo.restore(a.id);
      } else {
        await _repo.archive(a.id);
      }
      return true;
    });
    return result ?? false;
  }

  Future<UploadedAsset?> uploadAsset({
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      return await _repo.uploadAsset(fileBytes: fileBytes, fileName: fileName);
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  // ── Student/teacher interactions ────────────────────────────────────────
  // Deliberately don't route these through _run — a like/bookmark tap
  // shouldn't flip the whole controller into AsyncLoading (that's shared
  // state other widgets watch) or invalidate the admin list. Just refresh
  // the feed + that one detail view.
  Future<bool> toggleLike(AnnouncementModel a) async {
    try {
      if (a.isLiked) {
        await _repo.unlike(a.id);
      } else {
        await _repo.like(a.id);
      }
      _ref.invalidate(announcementFeedProvider);
      _ref.invalidate(announcementDetailProvider(a.id));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleBookmark(AnnouncementModel a) async {
    try {
      if (a.isBookmarked) {
        await _repo.unbookmarkAnnouncement(a.id);
      } else {
        await _repo.bookmarkAnnouncement(a.id);
      }
      _ref.invalidate(announcementFeedProvider);
      _ref.invalidate(announcementDetailProvider(a.id));
      return true;
    } catch (_) {
      return false;
    }
  }
}

final announcementActionsProvider =
    StateNotifierProvider<AnnouncementActionsController, AsyncValue<void>>(
  (ref) => AnnouncementActionsController(ref.read(announcementRepositoryProvider), ref),
);