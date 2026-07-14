// lib/features/sessions/widgets/video_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'room_theme.dart';

class VideoTile extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final String label;
  final bool micOn;
  final bool hasStream;
  final bool mirror;
  final Color badgeColor;

  const VideoTile({
    super.key,
    required this.renderer,
    required this.label,
    required this.micOn,
    required this.hasStream,
    this.mirror = false,
    this.badgeColor = RoomColors.magenta,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(fit: StackFit.expand, children: [
        Container(color: const Color(0xFF0A0410)),
        if (hasStream)
          RTCVideoView(
            renderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            mirror: mirror,
          )
        else
          const Center(
            child: Icon(Icons.person_rounded, size: 56, color: Colors.white24),
          ),
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: Icon(
              micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
              size: 14,
              color: micOn ? Colors.white : RoomColors.red,
            ),
          ),
        ),
      ]),
    );
  }
}
