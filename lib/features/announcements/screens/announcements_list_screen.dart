// lib/features/announcements/screens/announcements_list_screen.dart
// "See all" — search + quick filters over the student/teacher-facing feed.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/announcement.dart';
import '../controllers/announcement_controller.dart';
import '../utils/announcement_colors.dart';
import '../utils/announcement_meta.dart';
import '../utils/announcement_route.dart';
import 'announcement_detail_screen.dart';

class AnnouncementsListScreen extends ConsumerStatefulWidget {
  const AnnouncementsListScreen({super.key});

  @override
  ConsumerState<AnnouncementsListScreen> createState() => _AnnouncementsListScreenState();
}

class _QuickFilter {
  final String key;
  final String label;
  const _QuickFilter(this.key, this.label);
}

const _quickFilters = [
  _QuickFilter('', 'Latest'),
  _QuickFilter('important', 'Important'),
  _QuickFilter('event', 'Events'),
  _QuickFilter('resource', 'Learning Resources'),
  _QuickFilter('achievement', 'Achievements'),
  _QuickFilter('bookmarked', 'Bookmarked'),
  _QuickFilter('unread', 'Unread'),
];

class _AnnouncementsListScreenState extends ConsumerState<AnnouncementsListScreen> {
  final _searchCtrl = TextEditingController();
  String _active = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _selectFilter(String key) {
    setState(() => _active = key);
    // 'important' and 'event'/'resource'/'achievement' aren't first-class
    // server filter values (server only knows category=/priority=/filter=
    // bookmarked|unread) — map each quick filter to the right query param.
    if (key == 'bookmarked' || key == 'unread') {
      ref.read(announcementQuickFilterProvider.notifier).state = key;
      ref.read(announcementCategoryFilterProvider.notifier).state = '';
    } else if (key == 'important') {
      ref.read(announcementQuickFilterProvider.notifier).state = '';
      ref.read(announcementCategoryFilterProvider.notifier).state = '';
    } else if (key.isEmpty) {
      ref.read(announcementQuickFilterProvider.notifier).state = '';
      ref.read(announcementCategoryFilterProvider.notifier).state = '';
    } else {
      ref.read(announcementQuickFilterProvider.notifier).state = '';
      ref.read(announcementCategoryFilterProvider.notifier).state = key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(announcementFeedProvider);

    return Scaffold(
      backgroundColor: AnnouncementColors.cream,
      appBar: AppBar(
        backgroundColor: AnnouncementColors.cream,
        elevation: 0,
        foregroundColor: AnnouncementColors.ink,
        title: const Text('School Updates',
            style: TextStyle(fontWeight: FontWeight.w800, color: AnnouncementColors.ink)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => ref.read(announcementSearchQueryProvider.notifier).state = v,
            decoration: InputDecoration(
              hintText: 'Search announcements...',
              prefixIcon: const Icon(Icons.search, color: AnnouncementColors.inkSoft, size: 20),
              filled: true,
              fillColor: AnnouncementColors.softPink,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _quickFilters.length,
            itemBuilder: (_, i) {
              final f = _quickFilters[i];
              final active = f.key == _active;
              return GestureDetector(
                onTap: () => _selectFilter(f.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? AnnouncementColors.magenta : AnnouncementColors.paper,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? AnnouncementColors.magenta : AnnouncementColors.line),
                  ),
                  child: Text(f.label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : AnnouncementColors.inkSoft)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: async.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: AnnouncementColors.burgundy)),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$e', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(announcementFeedProvider),
                    child: const Text('Retry'),
                  ),
                ]),
              ),
            ),
            data: (items) {
              // 'important' quick filter isn't a server query param —
              // applied client-side over whatever page was fetched.
              final filtered = _active == 'important'
                  ? items.where((a) => a.priority != 'normal').toList()
                  : items;

              if (filtered.isEmpty) {
                return const Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.campaign_outlined, size: 44, color: AnnouncementColors.inkSoft),
                    SizedBox(height: 12),
                    Text('No announcements found',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: AnnouncementColors.ink)),
                    Text('· 暂无相关公告', style: TextStyle(color: AnnouncementColors.inkSoft)),
                  ]),
                );
              }
              return RefreshIndicator(
                color: AnnouncementColors.magenta,
                onRefresh: () async => ref.invalidate(announcementFeedProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FullWidthAnnouncementTile(a: filtered[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _FullWidthAnnouncementTile extends StatelessWidget {
  final AnnouncementModel a;
  const _FullWidthAnnouncementTile({required this.a});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(announcementFadeRoute(AnnouncementDetailScreen(announcementId: a.id))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AnnouncementColors.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AnnouncementColors.line),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AnnouncementColors.blushPink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(announcementCategoryIcon(a.category),
                color: AnnouncementColors.burgundy, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (!a.isRead) ...[
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(
                          color: AnnouncementColors.magenta, shape: BoxShape.circle),
                    ),
                  ],
                  Expanded(
                    child: Text(a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700, color: AnnouncementColors.ink)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(a.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AnnouncementColors.inkSoft)),
                const SizedBox(height: 6),
                Text(formatAnnouncementDate(a.publishAt),
                    style: const TextStyle(fontSize: 10.5, color: AnnouncementColors.inkSoft)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
