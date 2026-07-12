// lib/features/announcements/widgets/announcement_feed_section.dart
//
// "School Updates" / "Latest Announcements" section, embedded as one more
// sliver inside the existing Student and Teacher Home Dashboard tabs. Pure
// addition — if the feed is empty or fails to load it collapses to nothing,
// so it can never break the layout around it.
//
// GET /announcements (announcements.controller.js's list()) is already
// visibility-filtered server-side by req.user's role/course/year_level, so
// this widget doesn't need to know whether it's embedded in the student or
// teacher dashboard — the backend only ever returns what that user may see.
// It's also already ordered pinned-first, so the swipeable carousel below
// naturally opens on whatever's pinned without needing to split it out.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/announcement.dart';
import '../controllers/announcement_controller.dart';
import '../screens/announcement_detail_screen.dart';
import '../screens/announcements_list_screen.dart';
import '../utils/announcement_colors.dart';
import '../utils/announcement_route.dart';
import 'announcement_hero_banner.dart';

class AnnouncementFeedSection extends ConsumerStatefulWidget {
  const AnnouncementFeedSection({super.key});

  @override
  ConsumerState<AnnouncementFeedSection> createState() => _AnnouncementFeedSectionState();
}

class _AnnouncementFeedSectionState extends ConsumerState<AnnouncementFeedSection> {
  // viewportFraction < 1 lets the next card peek in at the edge, so it
  // reads as "swipe to see more" instead of a single static banner.
  final _pageController = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openDetail(BuildContext context, WidgetRef ref, AnnouncementModel a) {
    Navigator.of(context)
        .push(announcementFadeRoute(AnnouncementDetailScreen(announcementId: a.id)))
        .then((_) => ref.invalidate(announcementFeedProvider));
  }

  void _openSeeAll(BuildContext context, WidgetRef ref) {
    Navigator.of(context)
        .push(announcementFadeRoute(const AnnouncementsListScreen()))
        .then((_) => ref.invalidate(announcementFeedProvider));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(announcementFeedProvider);

    return async.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, showSeeAll: false),
          const SizedBox(height: 10),
          const _CarouselSkeleton(),
        ],
      ),
      // A feed failure should never take down the rest of the dashboard —
      // collapse silently rather than surfacing a raw error widget here.
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        if (_page >= items.length) _page = 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, showSeeAll: true),
            const SizedBox(height: 10),
            SizedBox(
              height: 180,
              child: PageView.builder(
                controller: _pageController,
                itemCount: items.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnnouncementHeroBanner(
                    a: items[i],
                    onTap: () => _openDetail(context, ref, items[i]),
                  ),
                ),
              ),
            ),
            if (items.length > 1) ...[
              const SizedBox(height: 10),
              _Dots(count: items.length, index: _page),
            ],
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context, {required bool showSeeAll}) {
    return Row(children: [
      const Text('School Updates',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: AnnouncementColors.ink)),
      const SizedBox(width: 5),
      const Text('· 校园动态',
          style: TextStyle(
              fontSize: 12, color: AnnouncementColors.magenta, fontWeight: FontWeight.w600)),
      const Spacer(),
      if (showSeeAll)
        GestureDetector(
          onTap: () => _openSeeAll(context, ref),
          child: const Text('See all',
              style: TextStyle(
                  fontSize: 12,
                  color: AnnouncementColors.magenta,
                  fontWeight: FontWeight.w700)),
        ),
    ]);
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? AnnouncementColors.magenta : AnnouncementColors.blushPink,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

/// Pulsing placeholder shown while the feed loads, sized to match the
/// carousel it's replacing (hand-rolled — no shimmer dependency in this
/// project, same approach as AnnouncementSkeletonCard).
class _CarouselSkeleton extends StatefulWidget {
  const _CarouselSkeleton();

  @override
  State<_CarouselSkeleton> createState() => _CarouselSkeletonState();
}

class _CarouselSkeletonState extends State<_CarouselSkeleton>
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
        height: 180,
        decoration: BoxDecoration(
          color: AnnouncementColors.blushPink,
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    );
  }
}