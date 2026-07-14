// lib/features/sessions/widgets/video_call_panel.dart
//
// Local + remote video tiles, shown side by side (teacher | student) so
// both participants are always visually represented — even before the
// peer connects, where the remote tile shows a waiting state instead of
// disappearing.

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../models/session.dart';
import '../../booking/utils/avatar_url.dart';
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
    final otherAvatar = resolveAvatarUrl(
        isTeacher ? session.studentAvatarUrl : session.teacherAvatarUrl);
    final otherRole = isTeacher ? 'Student' : 'Teacher';

    final remote = _RemoteTile(
      renderer: controller.webrtc.remoteRenderer,
      peerPresent: state.peerPresent,
      otherName: otherName,
      otherAvatarUrl: otherAvatar,
      roleLabel: otherRole,
      handRaised: state.remoteHandRaised,
      compact: compact,
    );
    final local = _LocalTile(
      renderer: controller.webrtc.localRenderer,
      camOn: state.camOn,
      micOn: state.micOn,
      compact: compact,
    );

    return Container(
      color: D.bg,
      padding: EdgeInsets.all(compact ? 8 : 16),
      child: Row(children: [
        Expanded(child: remote),
        SizedBox(width: compact ? 8 : 14),
        Expanded(child: local),
      ]),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _RoleBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: D.bg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _NameTag extends StatelessWidget {
  final String label;
  final bool micOn;
  const _NameTag({required this.label, required this.micOn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: D.bg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            size: 13, color: micOn ? D.green : D.red),
        const SizedBox(width: 5),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ),
      ]),
    );
  }
}

class _RemoteTile extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final bool peerPresent;
  final String? otherName;
  final String? otherAvatarUrl;
  final String roleLabel;
  final bool handRaised;
  final bool compact;
  const _RemoteTile({
    required this.renderer,
    required this.peerPresent,
    required this.otherName,
    required this.otherAvatarUrl,
    required this.roleLabel,
    required this.handRaised,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatarRadius = compact ? 22.0 : 40.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 10 : 18),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [D.surfaceRaised, D.surface],
          ),
          border: Border.all(color: D.border),
        ),
        child: Stack(fit: StackFit.expand, children: [
          if (peerPresent)
            RTCVideoView(renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
          else
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [D.slateBlue, D.magenta]),
                  ),
                  child: CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: D.surfaceRaised,
                    backgroundImage: otherAvatarUrl != null
                        ? NetworkImage(otherAvatarUrl!)
                        : null,
                    child: otherAvatarUrl == null
                        ? Text(
                            (otherName?.isNotEmpty ?? false)
                                ? otherName![0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                fontSize: compact ? 16 : 28,
                                fontWeight: FontWeight.w700,
                                color: D.textPrimary),
                          )
                        : null,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 14),
                  Text(
                      'Waiting for ${otherName ?? "your $roleLabel".toLowerCase()}…',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: D.textPrimary)),
                  const SizedBox(height: 4),
                  const Text("They'll join any moment now",
                      style: TextStyle(fontSize: 11, color: D.textSoft)),
                ],
              ]),
            ),
          Positioned(
            top: 10,
            left: 10,
            child: _RoleBadge(
                label: roleLabel,
                color: roleLabel == 'Teacher' ? D.slateBlue : D.magenta),
          ),
          if (peerPresent)
            Positioned(
              left: 10,
              bottom: 10,
              child: _NameTag(label: otherName ?? roleLabel, micOn: true),
            ),
          if (handRaised)
            const Positioned(
              top: 10,
              right: 10,
              child: _Badge(icon: Icons.back_hand_rounded, color: D.amber),
            ),
        ]),
      ),
    );
  }
}

class _LocalTile extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final bool camOn;
  final bool micOn;
  final bool compact;
  const _LocalTile({
    required this.renderer,
    required this.camOn,
    required this.micOn,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 10 : 18),
      child: Container(
        decoration: BoxDecoration(
          color: D.surfaceRaised,
          border: Border.all(color: D.border),
        ),
        child: Stack(fit: StackFit.expand, children: [
          camOn
              ? RTCVideoView(renderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
              : Center(
                  child: Icon(Icons.videocam_off_rounded,
                      color: D.textSoft, size: compact ? 18 : 32),
                ),
          const Positioned(
            top: 10,
            left: 10,
            child: _RoleBadge(label: 'You', color: D.green),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: _NameTag(label: 'You', micOn: micOn),
          ),
        ]),
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
  final VoidCallback onLeave;
  const ControlBar({
    super.key,
    required this.state,
    required this.controller,
    required this.isTeacher,
    required this.accent,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: D.surface,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _PillButton(
          icon: state.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
          label: state.micOn ? 'Mute' : 'Unmute',
          active: state.micOn,
          onTap: controller.toggleMic,
        ),
        const SizedBox(width: 12),
        _PillButton(
          icon:
              state.camOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
          label: 'Camera',
          active: state.camOn,
          onTap: controller.toggleCam,
        ),
        const SizedBox(width: 12),
        _PillButton(
          icon: Icons.back_hand_rounded,
          label: 'Raise Hand',
          active: state.localHandRaised,
          activeColor: D.amber,
          onTap: controller.toggleRaiseHand,
        ),
        const SizedBox(width: 12),
        _ReactionButton(controller: controller),
        if (isTeacher) ...[
          const SizedBox(width: 12),
          _PillButton(
            icon: state.canDrawWhiteboard
                ? Icons.edit_note_rounded
                : Icons.edit_off_rounded,
            label: 'Board Access',
            active: state.canDrawWhiteboard,
            activeColor: D.slateBlue,
            onTap: () =>
                controller.setStudentDrawPermission(!state.canDrawWhiteboard),
            tooltip: 'Allow student to draw',
          ),
        ],
        const SizedBox(width: 20),
        Container(width: 1, height: 32, color: D.border),
        const SizedBox(width: 20),
        _PillButton(
          icon: isTeacher ? Icons.stop_circle_rounded : Icons.call_end_rounded,
          label: isTeacher ? 'End' : 'Leave',
          active: true,
          activeColor: D.red,
          onTap: onLeave,
        ),
      ]),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? activeColor;
  final VoidCallback onTap;
  final String? tooltip;
  const _PillButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final highlighted = active && activeColor != null;
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 66,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: highlighted
              ? activeColor!.withValues(alpha: 0.18)
              : D.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: highlighted ? activeColor! : D.border,
              width: highlighted ? 1.3 : 1),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              color: highlighted
                  ? activeColor
                  : (active ? D.textPrimary : D.textSoft),
              size: 20),
          const SizedBox(height: 4),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: highlighted ? activeColor : D.textSoft)),
        ]),
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
      tooltip: 'React',
      icon: Container(
        width: 66,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: D.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: D.border),
        ),
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.emoji_emotions_outlined, color: D.textSoft, size: 20),
          SizedBox(height: 4),
          Text('React',
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: D.textSoft)),
        ]),
      ),
      onSelected: controller.sendReaction,
      itemBuilder: (_) => _emojis
          .map((e) => PopupMenuItem(
              value: e, child: Text(e, style: const TextStyle(fontSize: 20))))
          .toList(),
    );
  }
}
