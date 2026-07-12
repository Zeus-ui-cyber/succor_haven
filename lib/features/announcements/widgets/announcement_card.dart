// lib/features/announcements/widgets/announcement_card.dart
// Compact announcement card — used in the Home Dashboard feed carousel,
// the "See all" list screen, and the "Related" strip on the detail screen.
import 'package:flutter/material.dart';
import '../../../models/announcement.dart';
import '../repositories/announcement_repository.dart';
import '../utils/announcement_colors.dart';
import '../utils/announcement_meta.dart';

class AnnouncementCard extends StatelessWidget {
  final AnnouncementModel a;
  final VoidCallback onTap;
  final double width;
  const AnnouncementCard({
    super.key,
    required this.a,
    required this.onTap,
    this.width = 220,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = announcementPriorityColor(a.priority);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AnnouncementColors.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AnnouncementColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              SizedBox(
                height: 90,
                width: double.infinity,
                child: a.coverImageUrl != null
                    ? Hero(
                        tag: 'announcement-cover-${a.id}',
                        child: Image.network(
                          resolveAnnouncementFileUrl(a.coverImageUrl!),
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) =>
                              progress == null
                                  ? child
                                  : Container(color: AnnouncementColors.softPink),
                          errorBuilder: (_, __, ___) => _placeholder(),
                        ),
                      )
                    : _placeholder(),
              ),
              if (!a.isRead)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AnnouncementColors.magenta,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(announcementCategoryLabel(a.category),
                      style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (a.priority != 'normal') ...[
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 5),
                        decoration:
                            BoxDecoration(color: priorityColor, shape: BoxShape.circle),
                      ),
                    ],
                    Expanded(
                      child: Text(a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AnnouncementColors.ink)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(a.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AnnouncementColors.inkSoft, height: 1.3)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.favorite_rounded,
                        size: 11,
                        color: a.isLiked ? AnnouncementColors.magenta : AnnouncementColors.inkSoft),
                    const SizedBox(width: 3),
                    Text('${a.likeCount}',
                        style: const TextStyle(fontSize: 10, color: AnnouncementColors.inkSoft)),
                    const Spacer(),
                    if (a.isBookmarked)
                      const Icon(Icons.bookmark_rounded,
                          size: 13, color: AnnouncementColors.magenta),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AnnouncementColors.softPink,
        child: Center(
          child: Icon(announcementCategoryIcon(a.category),
              color: AnnouncementColors.magenta, size: 28),
        ),
      );
}

/// Pulsing placeholder shown while the feed loads — hand-rolled (no
/// shimmer dependency in this project) via a looping opacity tween.
class AnnouncementSkeletonCard extends StatefulWidget {
  final double width;
  const AnnouncementSkeletonCard({super.key, this.width = 220});

  @override
  State<AnnouncementSkeletonCard> createState() => _AnnouncementSkeletonCardState();
}

class _AnnouncementSkeletonCardState extends State<AnnouncementSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(_ctrl),
      child: Container(
        width: widget.width,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AnnouncementColors.softPink,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 90,
              decoration: const BoxDecoration(
                color: AnnouncementColors.blushPink,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 10, width: widget.width * 0.6, color: AnnouncementColors.blushPink),
                  const SizedBox(height: 8),
                  Container(height: 8, width: widget.width * 0.8, color: AnnouncementColors.blushPink),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
