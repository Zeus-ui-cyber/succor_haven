// lib/features/sessions/widgets/screen_share_view.dart
//
// The shared-screen stage — shown whenever either participant is sharing
// their screen. Supports pinch/scroll zoom (via InteractiveViewer, which
// handles pan+zoom natively so there's no custom gesture math here) and a
// "pin" toggle that the VIEWER controls locally: pinned keeps the shared
// screen maximized as the main stage; unpinned shrinks it back down so the
// camera tiles regain focus. Purely local UI state — not synced over
// signaling, since each side may want a different view of the same share.

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'room_theme.dart';

class ScreenShareView extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final String label;
  final bool pinned;
  final VoidCallback onTogglePin;
  final bool isMine;

  const ScreenShareView({
    super.key,
    required this.renderer,
    required this.label,
    required this.pinned,
    required this.onTogglePin,
    this.isMine = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(fit: StackFit.expand, children: [
        Container(color: const Color(0xFF0A0410)),
        InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          child: RTCVideoView(
            renderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: RoomColors.magenta.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.screen_share_rounded,
                  size: 12, color: Colors.white),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: _RoundIconButton(
            icon: pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            active: pinned,
            tooltip: pinned ? 'Unpin' : 'Pin shared screen',
            onTap: onTogglePin,
          ),
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.pinch_rounded, size: 12, color: Colors.white70),
              SizedBox(width: 4),
              Text('Pinch or scroll to zoom',
                  style: TextStyle(fontSize: 9.5, color: Colors.white70)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? RoomColors.magenta.withValues(alpha: 0.9)
            : Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
