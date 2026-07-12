// lib/features/notifications/widgets/notification_bell.dart
// Bell icon + unread badge, dropped into the Student/Teacher dashboard
// headers. Self-contained (fetches its own unread count) so it can be
// added to any header without that screen needing to wire anything up.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../announcements/utils/announcement_colors.dart';
import '../controllers/notification_controller.dart';
import '../screens/notifications_screen.dart';

class NotificationBell extends ConsumerWidget {
  final Color? iconColor;
  const NotificationBell({super.key, this.iconColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadNotificationCountProvider);
    final unread = unreadAsync.valueOrNull ?? 0;

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        ref.invalidate(unreadNotificationCountProvider);
      },
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AnnouncementColors.blushPink,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.notifications_outlined,
              color: iconColor ?? AnnouncementColors.burgundy, size: 19),
        ),
        if (unread > 0)
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 17),
              decoration: BoxDecoration(
                color: AnnouncementColors.magenta,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ]),
    );
  }
}
