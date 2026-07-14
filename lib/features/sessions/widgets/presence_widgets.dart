// lib/features/sessions/widgets/presence_widgets.dart
//
// Floating reaction toast — fires briefly whenever
// SessionRoomState.lastReactionEmoji changes. No queue/persistence:
// per the plan this is ephemeral UI only.

import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/session_room_controller.dart';
import '../screens/session_room_screen.dart' show D;

class ReactionOverlayBar extends StatefulWidget {
  final SessionRoomState state;
  final SessionRoomController controller;
  final Color accent;
  const ReactionOverlayBar(
      {super.key,
      required this.state,
      required this.controller,
      required this.accent});

  @override
  State<ReactionOverlayBar> createState() => _ReactionOverlayBarState();
}

class _ReactionOverlayBarState extends State<ReactionOverlayBar> {
  String? _shown;
  Timer? _timer;

  @override
  void didUpdateWidget(covariant ReactionOverlayBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final emoji = widget.state.lastReactionEmoji;
    if (emoji != null && emoji != oldWidget.state.lastReactionEmoji) {
      setState(() => _shown = emoji);
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _shown = null);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shown == null) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(_shown),
        width: double.infinity,
        color: D.surface,
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        child: Text(_shown!, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}
