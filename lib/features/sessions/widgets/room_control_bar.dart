// lib/features/sessions/widgets/room_control_bar.dart
import 'package:flutter/material.dart';
import 'room_theme.dart';

class RoomControlBar extends StatelessWidget {
  final bool cameraOn;
  final bool micOn;
  final bool speakerOn;
  final bool whiteboardOpen;
  final bool handRaised;
  final bool isTeacher;
  final bool sharingScreen;
  final bool remoteSharingScreen;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onToggleWhiteboard;
  final VoidCallback onToggleRaiseHand;
  final void Function(String emoji) onReaction;
  final VoidCallback onEndSession;
  final VoidCallback onToggleScreenShare;

  const RoomControlBar({
    super.key,
    required this.cameraOn,
    required this.micOn,
    required this.speakerOn,
    required this.whiteboardOpen,
    required this.handRaised,
    required this.isTeacher,
    required this.sharingScreen,
    required this.remoteSharingScreen,
    required this.onToggleCamera,
    required this.onToggleMic,
    required this.onToggleSpeaker,
    required this.onToggleWhiteboard,
    required this.onToggleRaiseHand,
    required this.onReaction,
    required this.onEndSession,
    required this.onToggleScreenShare,
  });

  void _showReactionPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: RoomColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 20,
            alignment: WrapAlignment.center,
            children: ['👍', '❤️', '👏', '😂'].map((emoji) {
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  onReaction(emoji);
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(emoji, style: const TextStyle(fontSize: 32)),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: roomPanelDecoration(radius: 20),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Wrap(spacing: 6, runSpacing: 8, children: [
            _ControlButton(
              icon: cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              label: 'Camera',
              active: cameraOn,
              onTap: onToggleCamera,
            ),
            _ControlButton(
              icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
              label: 'Mic',
              active: micOn,
              onTap: onToggleMic,
            ),
            _ControlButton(
              icon: speakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              label: 'Speaker',
              active: speakerOn,
              onTap: onToggleSpeaker,
            ),
            _ControlButton(
              icon: sharingScreen
                  ? Icons.stop_screen_share_rounded
                  : Icons.screen_share_outlined,
              label: sharingScreen ? 'Stop Sharing' : 'Screen Share',
              active: sharingScreen,
              disabled: remoteSharingScreen && !sharingScreen,
              onTap: remoteSharingScreen && !sharingScreen
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'The other participant is already sharing their screen.'),
                        ),
                      )
                  : onToggleScreenShare,
            ),
            _ControlButton(
              icon: Icons.draw_rounded,
              label: 'Whiteboard',
              active: whiteboardOpen,
              onTap: onToggleWhiteboard,
            ),
            _ControlButton(
              icon: handRaised ? Icons.back_hand_rounded : Icons.back_hand_outlined,
              label: 'Raise Hand',
              active: handRaised,
              onTap: onToggleRaiseHand,
            ),
            _ControlButton(
              icon: Icons.emoji_emotions_outlined,
              label: 'Reactions',
              active: false,
              onTap: () => _showReactionPicker(context),
            ),
          ]),
          ElevatedButton.icon(
            onPressed: onEndSession,
            icon: const Icon(Icons.call_end_rounded, size: 18),
            label: Text(isTeacher ? 'End Session' : 'Leave'),
            style: ElevatedButton.styleFrom(
              backgroundColor: RoomColors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool disabled;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 68,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? RoomColors.magenta.withValues(alpha: 0.25)
                  : RoomColors.surfaceRaised,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  size: 20,
                  color: active ? RoomColors.magenta : RoomColors.textSecondary),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: active ? RoomColors.magenta : RoomColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center),
            ]),
          ),
        ),
      ),
    );
  }
}
