// lib/features/announcements/screens/announcement_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/announcement.dart';
import '../controllers/announcement_controller.dart';
import '../repositories/announcement_repository.dart';
import '../utils/announcement_colors.dart';
import '../utils/announcement_meta.dart';
import '../utils/announcement_route.dart';
import '../widgets/announcement_card.dart';
import '../widgets/announcement_comments_section.dart';

class AnnouncementDetailScreen extends ConsumerWidget {
  final String announcementId;
  const AnnouncementDetailScreen({super.key, required this.announcementId});

  Future<void> _openUrl(BuildContext context, String rawUrl) async {
    final url = Uri.parse(
      rawUrl.startsWith('http') ? rawUrl : resolveAnnouncementFileUrl(rawUrl),
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  void _share(BuildContext context, AnnouncementModel a) {
    Clipboard.setData(ClipboardData(text: '${a.title}\n\n${a.description}'));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Copied to clipboard — share it!'),
      backgroundColor: AnnouncementColors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(announcementDetailProvider(announcementId));

    return Scaffold(
      backgroundColor: AnnouncementColors.cream,
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AnnouncementColors.burgundy)),
        error: (e, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(announcementDetailProvider(announcementId)),
                child: const Text('Retry'),
              ),
            ]),
          ),
        ),
        data: (a) => _DetailBody(a: a, onOpenUrl: _openUrl, onShare: _share),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final AnnouncementModel a;
  final void Function(BuildContext, String) onOpenUrl;
  final void Function(BuildContext, AnnouncementModel) onShare;
  const _DetailBody({required this.a, required this.onOpenUrl, required this.onShare});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorityColor = announcementPriorityColor(a.priority);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          backgroundColor: AnnouncementColors.burgundy,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: FlexibleSpaceBar(
            background: a.coverImageUrl != null
                ? Hero(
                    tag: 'announcement-cover-${a.id}',
                    child: Image.network(
                      resolveAnnouncementFileUrl(a.coverImageUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallbackHeader(),
                    ),
                  )
                : _fallbackHeader(),
          ),
        ),
        SliverToBoxAdapter(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 300),
            builder: (_, v, child) => Opacity(opacity: v, child: child),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _Badge(
                      label: announcementCategoryLabel(a.category),
                      color: AnnouncementColors.slateBlue,
                      icon: announcementCategoryIcon(a.category),
                    ),
                    if (a.priority != 'normal')
                      _Badge(
                        label: kAnnouncementPriorityLabels[a.priority] ?? a.priority,
                        color: priorityColor,
                        icon: Icons.priority_high_rounded,
                      ),
                  ]),
                  const SizedBox(height: 14),
                  Text(a.title,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900, color: AnnouncementColors.ink)),
                  if (a.subtitle != null && a.subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(a.subtitle!,
                        style: const TextStyle(fontSize: 14, color: AnnouncementColors.magenta)),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.person_outline_rounded, size: 14, color: AnnouncementColors.inkSoft),
                    const SizedBox(width: 4),
                    Text(a.createdByName ?? 'Admin',
                        style: const TextStyle(fontSize: 12, color: AnnouncementColors.inkSoft)),
                    const SizedBox(width: 12),
                    const Icon(Icons.calendar_today_rounded, size: 12, color: AnnouncementColors.inkSoft),
                    const SizedBox(width: 4),
                    Text(formatAnnouncementDate(a.publishAt),
                        style: const TextStyle(fontSize: 12, color: AnnouncementColors.inkSoft)),
                  ]),
                  const SizedBox(height: 18),
                  Text(a.description,
                      style: const TextStyle(fontSize: 14.5, color: AnnouncementColors.ink, height: 1.6)),

                  if (a.galleryUrls.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Gallery',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800, color: AnnouncementColors.ink)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: a.galleryUrls.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GestureDetector(
                              onTap: () => _openGalleryViewer(context, a.galleryUrls, i),
                              child: Image.network(
                                resolveAnnouncementFileUrl(a.galleryUrls[i]),
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 90,
                                  height: 90,
                                  color: AnnouncementColors.softPink,
                                  child: const Icon(Icons.image_not_supported_outlined,
                                      color: AnnouncementColors.inkSoft),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (a.attachmentUrl != null) ...[
                    const SizedBox(height: 20),
                    _LinkTile(
                      icon: Icons.attach_file_rounded,
                      label: a.attachmentName ?? 'Attachment',
                      onTap: () => onOpenUrl(context, a.attachmentUrl!),
                    ),
                  ],
                  if (a.externalLink != null && a.externalLink!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _LinkTile(
                      icon: Icons.open_in_new_rounded,
                      label: a.externalLink!,
                      onTap: () => onOpenUrl(context, a.externalLink!),
                    ),
                  ],

                  const SizedBox(height: 22),
                  Row(children: [
                    _ActionButton(
                      icon: a.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      label: '${a.likeCount}',
                      active: a.isLiked,
                      onTap: () => ref.read(announcementActionsProvider.notifier).toggleLike(a),
                    ),
                    const SizedBox(width: 10),
                    _ActionButton(
                      icon: a.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      label: 'Save',
                      active: a.isBookmarked,
                      onTap: () => ref.read(announcementActionsProvider.notifier).toggleBookmark(a),
                    ),
                    const SizedBox(width: 10),
                    _ActionButton(
                      icon: Icons.share_outlined,
                      label: 'Share',
                      active: false,
                      onTap: () => onShare(context, a),
                    ),
                  ]),

                  if (a.commentsEnabled) ...[
                    const SizedBox(height: 24),
                    const Divider(color: AnnouncementColors.line),
                    const SizedBox(height: 16),
                    AnnouncementCommentsSection(announcementId: a.id),
                  ],

                  const SizedBox(height: 28),
                  _RelatedSection(a: a),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openGalleryViewer(BuildContext context, List<String> urls, int startIndex) {
    Navigator.of(context).push(announcementFadeRoute(
      _GalleryViewer(urls: urls, startIndex: startIndex),
    ));
  }

  Widget _fallbackHeader() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AnnouncementColors.burgundy, AnnouncementColors.magenta],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(announcementCategoryIcon(a.category),
              color: Colors.white.withValues(alpha: 0.5), size: 64),
        ),
      );
}

class _RelatedSection extends ConsumerWidget {
  final AnnouncementModel a;
  const _RelatedSection({required this.a});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async =
        ref.watch(relatedAnnouncementsProvider((id: a.id, category: a.category)));

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Related Announcements',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: AnnouncementColors.ink)),
            const SizedBox(height: 10),
            SizedBox(
              height: 190,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (_, i) => AnnouncementCard(
                  a: items[i],
                  onTap: () => Navigator.of(context).pushReplacement(
                    announcementFadeRoute(AnnouncementDetailScreen(announcementId: items[i].id)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _Badge({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LinkTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AnnouncementColors.softPink,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: AnnouncementColors.burgundy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, color: AnnouncementColors.ink, fontWeight: FontWeight.w600)),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18, color: AnnouncementColors.inkSoft),
        ]),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AnnouncementColors.blushPink : AnnouncementColors.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? AnnouncementColors.magenta : AnnouncementColors.line),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: active ? AnnouncementColors.magenta : AnnouncementColors.inkSoft),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: active ? AnnouncementColors.magenta : AnnouncementColors.inkSoft)),
          ]),
        ),
      ),
    );
  }
}

class _GalleryViewer extends StatefulWidget {
  final List<String> urls;
  final int startIndex;
  const _GalleryViewer({required this.urls, required this.startIndex});

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _pageCtrl = PageController(initialPage: widget.startIndex);

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.urls.length,
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: Image.network(resolveAnnouncementFileUrl(widget.urls[i])),
          ),
        ),
      ),
    );
  }
}
