// lib/features/notifications/controllers/notification_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../models/app_notification.dart';
import '../repositories/notification_repository.dart';

final _notificationAuthRepoProvider = Provider((_) => AuthRepository());

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.read(_notificationAuthRepoProvider)),
);

final notificationsListProvider =
    FutureProvider.autoDispose<List<AppNotificationModel>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.list();
});

final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.unreadCount();
});

class NotificationActionsController extends StateNotifier<AsyncValue<void>> {
  final NotificationRepository _repo;
  final Ref _ref;
  NotificationActionsController(this._repo, this._ref) : super(const AsyncData(null));

  Future<void> markRead(String id) async {
    try {
      await _repo.markRead(id);
      _ref.invalidate(notificationsListProvider);
      _ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {
      // Best-effort — a failed mark-as-read shouldn't block navigation.
    }
  }

  Future<void> markAllRead() async {
    try {
      await _repo.markAllRead();
      _ref.invalidate(notificationsListProvider);
      _ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {}
  }
}

final notificationActionsProvider =
    StateNotifierProvider<NotificationActionsController, AsyncValue<void>>(
  (ref) => NotificationActionsController(ref.read(notificationRepositoryProvider), ref),
);