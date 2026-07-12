// lib/features/announcements/widgets/announcement_hero_banner.dart
// Premium "featured" presentation for the top pinned announcement —
// large cover image, gradient overlay, title, short blurb, Read More.
import 'package:flutter/material.dart';
import '../../../models/announcement.dart';
import '../repositories/announcement_repository.dart';
import '../utils/announcement_colors.dart';
import '../utils/announcement_meta.dart';

class AnnouncementHeroBanner extends StatelessWidget {
  final AnnouncementModel a;
  final VoidCallback onTap;
  const AnnouncementHeroBanner({super.key, required this.a, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: child),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 170,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              a.coverImageUrl != null
                  ? Hero(
                      tag: 'announcement-cover-${a.id}',
                      child: Image.network(
                        resolveAnnouncementFileUrl(a.coverImageUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackGradient(),
                      ),
                    )
                  : _fallbackGradient(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (a.isPinned) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AnnouncementColors.magenta,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.push_pin_rounded, size: 10, color: Colors.white),
                            SizedBox(width: 3),
                            Text('Featured',
                                style: TextStyle(
                                    fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
                          ]),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(announcementCategoryLabel(a.category),
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 8),
                    Text(a.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(a.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Read More',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AnnouncementColors.burgundy)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 13, color: AnnouncementColors.burgundy),
                      ]),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _fallbackGradient() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AnnouncementColors.burgundy, AnnouncementColors.magenta],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(announcementCategoryIcon(a.category),
              color: Colors.white.withValues(alpha: 0.5), size: 48),
        ),
      );
}