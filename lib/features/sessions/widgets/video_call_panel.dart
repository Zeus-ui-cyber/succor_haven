// lib/features/sessions/widgets/video_call_panel.dart
//
// Local + remote video tiles. On wide layouts this fills the left 3/4
// of the screen (remote large, local as a small PIP); on narrow layouts
// it's a fixed-height strip with both tiles side by side.

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../models/session.dart';
import '../controllers/session_room_controller.dart';
import '../screens/session_room_screen.dart' show D;

class VideoCallPanel extends StatelessWidget {
  final SessionModel session;
  final SessionRoomState state;
  final SessionRoomController controller;
  final bool isTeacher;
  final bool compact;

  const VideoCallPanel({
    super.key,
    required this.session,
    required this.state,
    required this.controller,
    required this.isTeacher,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final otherName = isTeacher ? session.studentName : session.teacherName;

    if (compact) {
      return Container(
        color: D.bg,
        child: Row(children: [
          Expanded(
            child: _RemoteTile(
              renderer: controller.webrtc.remoteRenderer,
              peerPresent: state.peerPresent,
              otherName: otherName,
              handRaised: state.remoteHandRaised,
            ),
          ),
          SizedBox(
            width: 110,
            child: _LocalTile(
                renderer: controller.webrtc.localRenderer, camOn: state.camOn),
          ),
        ]),
      );
    }

    return Container(
      color: D.bg,
      padding: const EdgeInsets.all(16),
      child: Stack(children: [
        Positioned.fill(
          child: _RemoteTile(
            renderer: controller.webrtc.remoteRenderer,
            peerPresent: state.peerPresent,
            otherName: otherName,
            handRaised: state.remoteHandRaised,
            large: true,
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          width: 180,
          height: 120,
          child: _LocalTile(
              renderer: controller.webrtc.localRenderer, camOn: state.camOn),
        ),
      ]),
    );
  }
}

class _RemoteTile extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final bool peerPresent;
  final String? otherName;
  final bool handRaised;
  final bool large;
  const _RemoteTile({
    required this.renderer,
    required this.peerPresent,
    required this.otherName,
    required this.handRaised,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(large ? 16 : 8),
      child: Container(
        color: D.surface,
        child: Stack(fit: StackFit.expand, children: [
          if (peerPresent)
            RTCVideoView(renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
          else
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(
                  radius: large ? 36 : 20,
                  backgroundColor: D.surfaceRaised,
                  child: Text(
                    (otherName?.isNotEmpty ?? false)
                        ? otherName![0].toUpperCase()
                        : '?',
                    style:
                        TextStyle(fontSize: large ? 28 : 16, color: D.textSoft),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Waiting for ${otherName ?? "the other participant"}…',
                    style: const TextStyle(fontSize: 12, color: D.textSoft)),
              ]),
            ),
          if (handRaised)
            const Positioned(
              top: 10,
              left: 10,
              child: _Badge(icon: Icons.back_hand_rounded, color: D.amber),
            ),
        ]),
      ),
    );
  }
}

// FIXED: Container previously set both `color:` and `decoration:`
// simultaneously — Flutter forbids this (color is just shorthand for
// decoration: BoxDecoration(color: color), so the two can't coexist).
// This was throwing "Cannot provide both a color and a decoration" on
// every build, crashing the local video tile. Fix: move the color into
// the same BoxDecoration as the border.
class _LocalTile extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final bool camOn;
  const _LocalTile({required this.renderer, required this.camOn});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: D.surfaceRaised,
          border: Border.all(color: D.border),
        ),
        child: camOn
            ? RTCVideoView(renderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
            : const Center(
                child: Icon(Icons.videocam_off_rounded,
                    color: D.textSoft, size: 20)),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _Badge({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, size: 14, color: Colors.white),
      );
}

// ── Bottom control bar (mic/cam/hand/reactions/tool switcher trigger) ──
class ControlBar extends StatelessWidget {
  final SessionRoomState state;
  final SessionRoomController controller;
  final bool isTeacher;
  final Color accent;
  const ControlBar({
    super.key,
    required this.state,
    required this.controller,
    required this.isTeacher,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: D.surface,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _CircleButton(
          icon: state.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
          active: state.micOn,
          onTap: controller.toggleMic,
        ),
        const SizedBox(width: 14),
        _CircleButton(
          icon:
              state.camOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
          active: state.camOn,
          onTap: controller.toggleCam,
        ),
        const SizedBox(width: 14),
        _CircleButton(
          icon: Icons.back_hand_rounded,
          active: state.localHandRaised,
          activeColor: D.amber,
          onTap: controller.toggleRaiseHand,
        ),
        const SizedBox(width: 14),
        _ReactionButton(controller: controller),
        if (isTeacher) ...[
          const SizedBox(width: 14),
          _CircleButton(
            icon: state.canDrawWhiteboard
                ? Icons.edit_note_rounded
                : Icons.edit_off_rounded,
            active: state.canDrawWhiteboard,
            activeColor: D.slateBlue,
            onTap: () =>
                controller.setStudentDrawPermission(!state.canDrawWhiteboard),
            tooltip: 'Allow student to draw',
          ),
        ],
      ]),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color? activeColor;
  final VoidCallback onTap;
  final String? tooltip;
  const _CircleButton({
    required this.icon,
    required this.active,
    required this.onTap,
    this.activeColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? (activeColor ?? D.surfaceRaised) : D.surfaceRaised,
          border: active && activeColor == null
              ? Border.all(color: D.border)
              : null,
        ),
        child: Icon(icon,
            color: active && activeColor == null ? D.textPrimary : Colors.white,
            size: 20),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

class _ReactionButton extends StatelessWidget {
  final SessionRoomController controller;
  const _ReactionButton({required this.controller});

  static const _emojis = ['👍', '👏', '❤️', '😂', '🎉', '🤔'];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: D.surfaceRaised,
      icon: Container(
        width: 44,
        height: 44,
        decoration:
            const BoxDecoration(shape: BoxShape.circle, color: D.surfaceRaised),
        child: const Icon(Icons.emoji_emotions_outlined,
            color: Colors.white, size: 20),
      ),
      onSelected: controller.sendReaction,
      itemBuilder: (_) => _emojis
          .map((e) => PopupMenuItem(
              value: e, child: Text(e, style: const TextStyle(fontSize: 20))))
          .toList(),
    );
  }
}
