// lib/features/sessions/screens/session_room_screen.dart
//
// The real in-session meeting room — dark theme, responsive: 3-column
// on wide screens (video | tool panel | chat rail collapses into tabs),
// tabbed single-column below ~900px. Embeds video_call_panel,
// whiteboard_panel, notes_panel, files_panel, chat_panel,
// presence_widgets.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session.dart';
import '../../../models/user.dart';
import '../controllers/session_room_controller.dart';
import '../widgets/video_call_panel.dart';
import '../widgets/whiteboard_panel.dart';
import '../widgets/chat_panel.dart';
import '../widgets/notes_panel.dart';
import '../widgets/files_panel.dart';
import '../widgets/presence_widgets.dart';
import '../services/socket_room_service.dart' show RoomConnectionStatus;

class D {
  static const bg = Color(0xFF17101A);
  static const surface = Color(0xFF241A28);
  static const surfaceRaised = Color(0xFF2F2233);
  static const border = Color(0xFF3D2C42);
  static const textPrimary = Color(0xFFF5EAF0);
  static const textSoft = Color(0xFFB79EBE);
  static const magenta = Color(0xFFD64577);
  static const slateBlue = Color(0xFF5C8FBD);
  static const green = Color(0xFF00C48C);
  static const red = Color(0xFFE5484D);
  static const amber = Color(0xFFE0A800);
}

class SessionRoomScreen extends ConsumerStatefulWidget {
  final SessionModel session;
  final UserModel currentUser;
  const SessionRoomScreen(
      {super.key, required this.session, required this.currentUser});

  @override
  ConsumerState<SessionRoomScreen> createState() => _SessionRoomScreenState();
}

class _SessionRoomScreenState extends ConsumerState<SessionRoomScreen> {
  Timer? _tick;
  late final bool _isTeacher;

  @override
  void initState() {
    super.initState();
    _isTeacher = widget.currentUser.id == widget.session.teacherId;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  SessionRoomArgs get _args => SessionRoomArgs(
        session: widget.session,
        currentUserId: widget.currentUser.id,
        isTeacher: _isTeacher,
      );

  Duration get _remaining {
    final end = widget.session.scheduledEndAt;
    if (end == null) return Duration.zero;
    final d = end.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionRoomControllerProvider(_args));
    final controller = ref.read(sessionRoomControllerProvider(_args).notifier);

    ref.listen(sessionRoomControllerProvider(_args), (prev, next) {
      if (next.sessionEnded && (prev == null || !prev.sessionEnded)) {
        _showEndedDialog(context);
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: D.red),
        );
      }
    });

    final accent = _isTeacher ? D.slateBlue : D.magenta;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmLeave(context, controller, isTeacher: _isTeacher);
      },
      child: Scaffold(
        backgroundColor: D.bg,
        body: SafeArea(
          child: Column(children: [
            _TopBar(
              session: widget.session,
              accent: accent,
              connectionStatus: state.connectionStatus,
              remainingLabel: _fmt(_remaining),
              isTeacher: _isTeacher,
              peerPresent: state.peerPresent,
              onLeave: () =>
                  _confirmLeave(context, controller, isTeacher: _isTeacher),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return wide
                    ? _WideLayout(
                        session: widget.session,
                        state: state,
                        controller: controller,
                        isTeacher: _isTeacher,
                        accent: accent,
                      )
                    : _NarrowLayout(
                        session: widget.session,
                        state: state,
                        controller: controller,
                        isTeacher: _isTeacher,
                        accent: accent,
                      );
              }),
            ),
            ReactionOverlayBar(
                state: state, controller: controller, accent: accent),
            ControlBar(
              state: state,
              controller: controller,
              isTeacher: _isTeacher,
              accent: accent,
              onLeave: () =>
                  _confirmLeave(context, controller, isTeacher: _isTeacher),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmLeave(
      BuildContext context, SessionRoomController controller,
      {required bool isTeacher}) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: D.surfaceRaised,
        title: const Text('Leave meeting?',
            style: TextStyle(color: D.textPrimary)),
        content: Text(
          isTeacher
              ? 'You can leave (the room stays open) or end the session for both participants.'
              : 'You can rejoin later if the session is still open.',
          style: const TextStyle(color: D.textSoft),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: D.textSoft))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'leave'),
              child:
                  const Text('Leave', style: TextStyle(color: D.textPrimary))),
          if (isTeacher)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'end'),
              style: FilledButton.styleFrom(backgroundColor: D.red),
              child: const Text('End Session'),
            ),
        ],
      ),
    );

    if (action == 'leave') {
      await controller.leaveRoom();
      if (context.mounted) Navigator.of(context).pop();
    } else if (action == 'end') {
      await controller.endSessionAsTeacher();
    }
  }

  void _showEndedDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: D.surfaceRaised,
        title:
            const Text('Session ended', style: TextStyle(color: D.textPrimary)),
        content: const Text(
          'This session has ended. A full summary screen is coming in a later update.',
          style: TextStyle(color: D.textSoft),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final SessionModel session;
  final Color accent;
  final RoomConnectionStatus connectionStatus;
  final String remainingLabel;
  final bool isTeacher;
  final bool peerPresent;
  final VoidCallback onLeave;

  const _TopBar({
    required this.session,
    required this.accent,
    required this.connectionStatus,
    required this.remainingLabel,
    required this.isTeacher,
    required this.peerPresent,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (connectionStatus) {
      RoomConnectionStatus.joined => 'Connected',
      RoomConnectionStatus.connecting => 'Connecting…',
      RoomConnectionStatus.reconnecting => 'Reconnecting…',
      RoomConnectionStatus.disconnected => 'Disconnected',
      RoomConnectionStatus.error => 'Connection error',
    };
    final statusColor = connectionStatus == RoomConnectionStatus.joined
        ? D.green
        : connectionStatus == RoomConnectionStatus.error
            ? D.red
            : D.amber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [D.surface, D.surfaceRaised.withValues(alpha: 0.6)],
        ),
        border: const Border(bottom: BorderSide(color: D.border)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
              gradient:
                  const LinearGradient(colors: [D.red, Color(0xFFB93A63)]),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                    color: D.red.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            const Text('LIVE',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: Colors.white)),
          ]),
        ),
        const SizedBox(width: 8),
        Icon(Icons.shield_rounded,
            size: 14, color: D.green.withValues(alpha: 0.8)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                session.title?.trim().isNotEmpty == true
                    ? session.title!
                    : session.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: D.textPrimary),
              ),
              const Text('1-on-1 Session',
                  style: TextStyle(fontSize: 10.5, color: D.textSoft)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _Pill(children: [
          const Icon(Icons.people_alt_rounded, size: 13, color: D.textSoft),
          const SizedBox(width: 5),
          Text(peerPresent ? '2' : '1',
              style: const TextStyle(
                  fontSize: 11.5,
                  color: D.textPrimary,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(width: 8),
        _Pill(children: [
          const Icon(Icons.timer_outlined, size: 13, color: D.textSoft),
          const SizedBox(width: 5),
          Text(remainingLabel,
              style: const TextStyle(
                  fontSize: 11.5,
                  color: D.textPrimary,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(width: 8),
        _Pill(children: [
          Container(
              width: 7,
              height: 7,
              decoration:
                  BoxDecoration(color: statusColor, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(statusLabel, style: TextStyle(fontSize: 11, color: statusColor)),
        ]),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onLeave,
          icon: Icon(
              isTeacher ? Icons.stop_circle_rounded : Icons.logout_rounded,
              size: 16),
          label: Text(isTeacher ? 'End Session' : 'Leave',
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: D.magenta,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final List<Widget> children;
  const _Pill({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: D.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: D.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _ToolTabs extends StatelessWidget {
  final ActiveTool active;
  final ValueChanged<ActiveTool> onChanged;
  final Color accent;
  const _ToolTabs(
      {required this.active, required this.onChanged, required this.accent});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (ActiveTool.chat, Icons.chat_bubble_outline_rounded, 'Chat'),
      (ActiveTool.whiteboard, Icons.draw_outlined, 'Board'),
      (ActiveTool.notes, Icons.notes_rounded, 'Notes'),
      (ActiveTool.files, Icons.folder_outlined, 'Files'),
    ];
    return Container(
      color: D.surface,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: tabs.map((t) {
          final isActive = active == t.$1;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged(t.$1),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isActive
                      ? accent.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isActive
                          ? accent.withValues(alpha: 0.4)
                          : Colors.transparent),
                ),
                child: Column(children: [
                  Icon(t.$2, size: 17, color: isActive ? accent : D.textSoft),
                  const SizedBox(height: 3),
                  Text(t.$3,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? accent : D.textSoft)),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

Widget _toolBody(ActiveTool tool, SessionRoomState state,
    SessionRoomController controller, bool isTeacher) {
  switch (tool) {
    case ActiveTool.chat:
      return ChatPanel(state: state, controller: controller);
    case ActiveTool.whiteboard:
      return WhiteboardPanel(
          state: state, controller: controller, isTeacher: isTeacher);
    case ActiveTool.notes:
      return NotesPanel(state: state, controller: controller);
    case ActiveTool.files:
      return FilesPanel(
          state: state, controller: controller, isTeacher: isTeacher);
  }
}

class _WideLayout extends StatelessWidget {
  final SessionModel session;
  final SessionRoomState state;
  final SessionRoomController controller;
  final bool isTeacher;
  final Color accent;
  const _WideLayout({
    required this.session,
    required this.state,
    required this.controller,
    required this.isTeacher,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        flex: 3,
        child: VideoCallPanel(
          session: session,
          state: state,
          controller: controller,
          isTeacher: isTeacher,
        ),
      ),
      Container(width: 1, color: D.border),
      SizedBox(
        width: 380,
        child: Column(children: [
          _ToolTabs(
              active: state.activeTool,
              onChanged: controller.setActiveTool,
              accent: accent),
          Expanded(
              child: _toolBody(state.activeTool, state, controller, isTeacher)),
        ]),
      ),
    ]);
  }
}

class _NarrowLayout extends StatelessWidget {
  final SessionModel session;
  final SessionRoomState state;
  final SessionRoomController controller;
  final bool isTeacher;
  final Color accent;
  const _NarrowLayout({
    required this.session,
    required this.state,
    required this.controller,
    required this.isTeacher,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 220,
        child: VideoCallPanel(
          session: session,
          state: state,
          controller: controller,
          isTeacher: isTeacher,
          compact: true,
        ),
      ),
      Container(height: 1, color: D.border),
      _ToolTabs(
          active: state.activeTool,
          onChanged: controller.setActiveTool,
          accent: accent),
      Expanded(
          child: _toolBody(state.activeTool, state, controller, isTeacher)),
    ]);
  }
}
