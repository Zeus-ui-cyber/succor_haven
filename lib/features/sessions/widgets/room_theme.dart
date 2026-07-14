// lib/features/sessions/widgets/room_theme.dart
//
// Shared dark palette for the in-session meeting room screen and all its
// panels (video stage, whiteboard, notes, chat, files, control bar).
// Deliberately dark-baseline rather than following the app's usual
// light-cream dashboards — this matches the reference mockup and the
// spec's "modern, premium... Google Meet/Teams/Zoom-inspired" request —
// built on the same magenta/burgundy brand accents used everywhere else
// in the app, just against a dark surface instead of a light one.
//
// Scope note: this is a dark-only room theme for now, not a full
// light/dark toggle for this specific screen — every other screen in the
// app already follows its own light theme unaffected by this file.

import 'package:flutter/material.dart';

class RoomColors {
  static const bg = Color(0xFF120717); // near-black plum background
  static const surface = Color(0xFF1E0E28); // cards/panels
  static const surfaceRaised = Color(0xFF291436); // toolbars, chips
  static const line = Color(0x1FFFFFFF); // subtle white-alpha border
  static const magenta = Color(0xFFD64577);
  static const burgundy = Color(0xFF7D002B);
  static const green = Color(0xFF00C48C);
  static const red = Color(0xFFE0245E);
  static const gold = Color(0xFFE0A800);
  static const textPrimary = Color(0xFFF5EEF2);
  static const textSecondary = Color(0xFFB89AA8);
}

BoxDecoration roomPanelDecoration({double radius = 20}) => BoxDecoration(
      color: RoomColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: RoomColors.line),
    );
