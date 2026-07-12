// lib/features/notifications/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/app_notification.dart';
import '../../announcements/screens/announcement_detail_screen.dart';
import '../../announcements/utils/announcement_colors.dart';
import '../../announcements/utils/announcement_route.dart';
import '../controllers/notification_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, AppNotificationModel n) async {
    if (!n.isRead) {
      ref.read(notificationActionsProvider.notifier).markRead(n.id);
    }
    if (n.announcementId != null) {
      await Navigator.of(context)
          .push(announcementFadeRoute(AnnouncementDetailScreen(announcementId: n.announcementId!)));
      ref.invalidate(notificationsListProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsListProvider);

    return Scaffold(
      backgroundColor: AnnouncementColors.cream,
      appBar: AppBar(
        backgroundColor: AnnouncementColors.cream,
        elevation: 0,
        foregroundColor: AnnouncementColors.ink,
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.w800, color: AnnouncementColors.ink)),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationActionsProvider.notifier).markAllRead();
            },
            child: const Text('Mark all read',
                style: TextStyle(color: AnnouncementColors.magenta, fontSize: 12.5)),
          ),
        ],
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AnnouncementColors.burgundy)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(notificationsListProvider),
                child: const Text('Retry'),
              ),
            ]),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.notifications_none_rounded, size: 44, color: AnnouncementColors.inkSoft),
                SizedBox(height: 12),
                Text('No notifications yet',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AnnouncementColors.ink)),
              ]),
            );
          }
          return RefreshIndicator(
            color: AnnouncementColors.magenta,
            onRefresh: () async => ref.invalidate(notificationsListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _NotificationTile(
                n: items[i],
                onTap: () => _open(context, ref, items[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotificationModel n;
  final VoidCallback onTap;
  const _NotificationTile({required this.n, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.isRead ? AnnouncementColors.paper : AnnouncementColors.softPink,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AnnouncementColors.line),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AnnouncementColors.blushPink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.campaign_rounded, color: AnnouncementColors.burgundy, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AnnouncementColors.ink)),
                if (n.body != null && n.body!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(n.body!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AnnouncementColors.inkSoft)),
                ],
                const SizedBox(height: 4),
                Text(_relativeTime(n.createdAt),
                    style: const TextStyle(fontSize: 10.5, color: AnnouncementColors.inkSoft)),
              ],
            ),
          ),
          if (!n.isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(color: AnnouncementColors.magenta, shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }

  String _relativeTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.month}/${d.day}/${d.year}';
  }
}
