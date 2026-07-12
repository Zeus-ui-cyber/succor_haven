// lib/features/announcements/utils/announcement_route.dart
// Lightweight fade+slide push transition, used instead of the default
// MaterialPageRoute slide so opening an announcement feels a bit more
// premium — no new package, just PageRouteBuilder.
import 'package:flutter/material.dart';

Route<T> announcementFadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}
