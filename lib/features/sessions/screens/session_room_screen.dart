// lib/features/sessions/screens/session_room_screen.dart
//
// The actual in-session meeting room — replaces the "coming next"
// placeholder in session_detail_screen.dart once a session is joinable.
// Layout matches the reference mockup: 3-column on desktop/wide tablet
// (session sidebar | video+controls+whiteboard/notes | chat+files),
// collapsing to a single scrollable column with a tab switcher on
// mobile/narrow tablet.
//
// ⚠️ The video call itself (video_call_controller.dart) is unverified in
// a live two-device scenario — this environment has no Flutter SDK to
// run it. Everything else here (whiteboard, notes, chat, files, timer,
// end-of-session) is plain Flutter/Riverpod UI wired to already-tested
// REST endpoints and doesn't depend on WebRTC actually connecting to work.

import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session.dart';
import '../../../models/user.dart';
import '../../auth/repositories/auth_repository.dart';
import '../controllers/session_list_controller.dart'
    show sessionDetailProvider, sessionsRepositoryProvider;
import '../controllers/video_call_controller.dart';
import '../controllers/presence_controller.dart';
import '../widgets/room_theme.dart';
import '../widgets/video_tile.dart';
import '../widgets/room_control_bar.dart';
import '../widgets/whiteboard_panel.dart';
import '../widgets/notes_panel.dart';
import '../widgets/chat_panel.dart';
import '../widgets/files_panel.dart';

final _roomAuthRepoProvider = Provider((_) => AuthRepository());
final _roomMeProvider =
    FutureProvider.autoDispose<UserModel>((ref) => ref.read(_roomAuthRepoProvider).getMe());

enum _RoomTab { whiteboard, notes, chat, files }

class SessionRoomScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const SessionRoomScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionRoomScreen> createState() => _SessionRoomScreenState();
}

class _SessionRoomScreenState extends ConsumerState<SessionRoomScreen> {
  _RoomTab _mobileTab = _RoomTab.chat;
  bool _sessionEnded = false;
  bool _autoEndFired = false;
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _ensureTimer(SessionModel session, bool isTeacher) {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick(session, isTeacher));
    _tick(session, isTeacher);
  }

  // Per spec: "When timer reaches 00:00, Meeting ends automatically" —
  // the teacher's device is the one that calls the actual end-session
  // API (only a teacher is authorized to); the student's device just
  // reacts locally to the same countdown reaching zero.
  void _tick(SessionModel session, bool isTeacher) {
    final reference = session.startedAt ?? session.scheduledAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(reference);
    final total = Duration(minutes: session.durationMins);
    final remaining = total - elapsed;
    if (!mounted) return;
    setState(() => _remaining = remaining.isNegative ? Duration.zero : remaining);
    if (remaining <= Duration.zero && !_autoEndFired) {
      _autoEndFired = true;
      if (isTeacher) {
        ref.read(sessionsRepositoryProvider).endSession(widget.sessionId).catchError((_) {});
      }
      setState(() => _sessionEnded = true);
    }
  }

  Future<void> _leave(bool isTeacher) async {
    if (isTeacher && !_sessionEnded) {
      try {
        await ref.read(sessionsRepositoryProvider).endSession(widget.sessionId);
      } catch (_) {
        // Session still auto-completes later via the backend's own
        // reconcileStale() sweep even if this explicit call fails.
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(_roomMeProvider);
    final sessionAsync = ref.watch(sessionDetailProvider(widget.sessionId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: RoomColors.bg,
        body: SafeArea(
          child: meAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: RoomColors.magenta)),
            error: (e, _) =>
                Center(child: Text('$e', style: const TextStyle(color: Colors.white))),
            data: (me) => sessionAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: RoomColors.magenta)),
              error: (e, _) =>
                  Center(child: Text('$e', style: const TextStyle(color: Colors.white))),
              data: (session) {
                final isTeacher = me.id == session.teacherId;
                _ensureTimer(session, isTeacher);

                if (_sessionEnded) {
                  return _SessionEndedView(onDone: () => Navigator.of(context).pop());
                }

                return _RoomBody(
                  session: session,
                  me: me,
                  isTeacher: isTeacher,
                  remaining: _remaining,
                  mobileTab: _mobileTab,
                  onMobileTabChanged: (t) => setState(() => _mobileTab = t),
                  onLeave: () => _leave(isTeacher),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomBody extends ConsumerWidget {
  final SessionModel session;
  final UserModel me;
  final bool isTeacher;
  final Duration remaining;
  final _RoomTab mobileTab;
  final ValueChanged<_RoomTab> onMobileTabChanged;
  final VoidCallback onLeave;

  const _RoomBody({
    required this.session,
    required this.me,
    required this.isTeacher,
    required this.remaining,
    required this.mobileTab,
    required this.onMobileTabChanged,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(videoCallControllerProvider(session.id));
    final callController = ref.read(videoCallControllerProvider(session.id).notifier);
    final presenceArgs = (sessionId: session.id, myUserId: me.id);
    final presenceState = ref.watch(presenceControllerProvider(presenceArgs));
    final presenceController = ref.read(presenceControllerProvider(presenceArgs).notifier);

    return Column(children: [
      _TopBar(session: session, remaining: remaining, connectionState: callState.connectionState),
      Expanded(
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: wide
                ? _WideBody(
                    session: session,
                    me: me,
                    isTeacher: isTeacher,
                    callState: callState,
                    callController: callController,
                    presenceState: presenceState,
                    presenceController: presenceController,
                    onLeave: onLeave,
                  )
                : _NarrowBody(
                    session: session,
                    me: me,
                    isTeacher: isTeacher,
                    callState: callState,
                    callController: callController,
                    presenceState: presenceState,
                    presenceController: presenceController,
                    tab: mobileTab,
                    onTabChanged: onMobileTabChanged,
                    onLeave: onLeave,
                  ),
          );
        }),
      ),
      _FooterBar(session: session),
    ]);
  }
}

class _TopBar extends StatelessWidget {
  final SessionModel session;
  final Duration remaining;
  final CallConnectionState connectionState;

  const _TopBar({required this.session, required this.remaining, required this.connectionState});

  String get _remainingLabel {
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  String get _connectionLabel => switch (connectionState) {
        CallConnectionState.idle => 'Starting…',
        CallConnectionState.requestingPermissions => 'Requesting camera…',
        CallConnectionState.connectingSignaling => 'Connecting…',
        CallConnectionState.waitingForPeer => 'Waiting for the other participant…',
        CallConnectionState.negotiating => 'Connecting…',
        CallConnectionState.connected => 'Connected',
        CallConnectionState.failed => 'Connection issue',
      };

  Color get _connectionColor => connectionState == CallConnectionState.connected
      ? RoomColors.green
      : connectionState == CallConnectionState.failed
          ? RoomColors.red
          : RoomColors.gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RoomColors.line)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(
              session.title?.trim().isNotEmpty == true ? session.title! : session.subject,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: RoomColors.textPrimary),
            ),
            const Text('1-on-1 Session',
                style: TextStyle(fontSize: 11, color: RoomColors.textSecondary)),
          ]),
          Wrap(
            spacing: 18,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: RoomColors.red.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  _Dot(color: RoomColors.red),
                  SizedBox(width: 5),
                  Text('LIVE',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w800, color: RoomColors.red)),
                ]),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_remainingLabel,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: RoomColors.textPrimary,
                        fontFeatures: [FontFeature.tabularFigures()])),
                const Text('Remaining',
                    style: TextStyle(fontSize: 9.5, color: RoomColors.textSecondary)),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _Dot(color: _connectionColor),
                const SizedBox(width: 6),
                Text(_connectionLabel,
                    style: const TextStyle(fontSize: 11, color: RoomColors.textSecondary)),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _WideBody extends StatelessWidget {
  final SessionModel session;
  final UserModel me;
  final bool isTeacher;
  final VideoCallState callState;
  final VideoCallController callController;
  final PresenceState presenceState;
  final PresenceController presenceController;
  final VoidCallback onLeave;

  const _WideBody({
    required this.session,
    required this.me,
    required this.isTeacher,
    required this.callState,
    required this.callController,
    required this.presenceState,
    required this.presenceController,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 230, child: _Sidebar(session: session)),
      const SizedBox(width: 16),
      Expanded(
        flex: 3,
        child: Column(children: [
          Expanded(
            flex: 3,
            child: Row(children: [
              Expanded(
                child: VideoTile(
                  renderer: callController.localRenderer,
                  label: 'You',
                  micOn: callState.micOn,
                  hasStream: true,
                  mirror: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: VideoTile(
                  renderer: callController.remoteRenderer,
                  label: isTeacher
                      ? (session.studentName ?? 'Student')
                      : (session.teacherName ?? 'Teacher'),
                  micOn: true,
                  hasStream: callState.remoteConnected,
                  badgeColor: RoomColors.burgundy,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          RoomControlBar(
            cameraOn: callState.cameraOn,
            micOn: callState.micOn,
            speakerOn: callState.speakerOn,
            whiteboardOpen: true,
            handRaised: presenceState.myHandRaised,
            isTeacher: isTeacher,
            onToggleCamera: callController.toggleCamera,
            onToggleMic: callController.toggleMic,
            onToggleSpeaker: callController.toggleSpeaker,
            onToggleWhiteboard: () {}, // always visible on wide layout
            onToggleRaiseHand: presenceController.toggleRaiseHand,
            onReaction: presenceController.sendReaction,
            onEndSession: onLeave,
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 2,
            child: Row(children: [
              Expanded(flex: 3, child: WhiteboardPanel(sessionId: session.id, isTeacher: isTeacher)),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: NotesPanel(sessionId: session.id, isStudent: !isTeacher)),
            ]),
          ),
        ]),
      ),
      const SizedBox(width: 16),
      SizedBox(
        width: 320,
        child: Column(children: [
          Expanded(flex: 3, child: ChatPanel(sessionId: session.id, myUserId: me.id)),
          const SizedBox(height: 12),
          Expanded(flex: 2, child: FilesPanel(sessionId: session.id, isTeacher: isTeacher)),
        ]),
      ),
    ]);
  }
}

class _NarrowBody extends StatelessWidget {
  final SessionModel session;
  final UserModel me;
  final bool isTeacher;
  final VideoCallState callState;
  final VideoCallController callController;
  final PresenceState presenceState;
  final PresenceController presenceController;
  final _RoomTab tab;
  final ValueChanged<_RoomTab> onTabChanged;
  final VoidCallback onLeave;

  const _NarrowBody({
    required this.session,
    required this.me,
    required this.isTeacher,
    required this.callState,
    required this.callController,
    required this.presenceState,
    required this.presenceController,
    required this.tab,
    required this.onTabChanged,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 170,
        child: Row(children: [
          Expanded(
            child: VideoTile(
              renderer: callController.localRenderer,
              label: 'You',
              micOn: callState.micOn,
              hasStream: true,
              mirror: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: VideoTile(
              renderer: callController.remoteRenderer,
              label: isTeacher
                  ? (session.studentName ?? 'Student')
                  : (session.teacherName ?? 'Teacher'),
              micOn: true,
              hasStream: callState.remoteConnected,
              badgeColor: RoomColors.burgundy,
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      RoomControlBar(
        cameraOn: callState.cameraOn,
        micOn: callState.micOn,
        speakerOn: callState.speakerOn,
        whiteboardOpen: tab == _RoomTab.whiteboard,
        handRaised: presenceState.myHandRaised,
        isTeacher: isTeacher,
        onToggleCamera: callController.toggleCamera,
        onToggleMic: callController.toggleMic,
        onToggleSpeaker: callController.toggleSpeaker,
        onToggleWhiteboard: () => onTabChanged(_RoomTab.whiteboard),
        onToggleRaiseHand: presenceController.toggleRaiseHand,
        onReaction: presenceController.sendReaction,
        onEndSession: onLeave,
      ),
      const SizedBox(height: 12),
      _MobileTabBar(tab: tab, onTabChanged: onTabChanged),
      const SizedBox(height: 12),
      Expanded(
        child: switch (tab) {
          _RoomTab.whiteboard => WhiteboardPanel(sessionId: session.id, isTeacher: isTeacher),
          _RoomTab.notes => NotesPanel(sessionId: session.id, isStudent: !isTeacher),
          _RoomTab.chat => ChatPanel(sessionId: session.id, myUserId: me.id),
          _RoomTab.files => FilesPanel(sessionId: session.id, isTeacher: isTeacher),
        },
      ),
    ]);
  }
}

class _MobileTabBar extends StatelessWidget {
  final _RoomTab tab;
  final ValueChanged<_RoomTab> onTabChanged;
  const _MobileTabBar({required this.tab, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    final items = [
      (_RoomTab.whiteboard, Icons.draw_outlined, 'Whiteboard'),
      (_RoomTab.notes, Icons.edit_note_rounded, 'Notes'),
      (_RoomTab.chat, Icons.chat_bubble_outline_rounded, 'Chat'),
      (_RoomTab.files, Icons.folder_outlined, 'Files'),
    ];
    return Row(
      children: items.map((item) {
        final active = tab == item.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => onTabChanged(item.$1),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? RoomColors.magenta.withValues(alpha: 0.2)
                    : RoomColors.surfaceRaised,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(item.$2,
                    size: 16, color: active ? RoomColors.magenta : RoomColors.textSecondary),
                const SizedBox(height: 2),
                Text(item.$3,
                    style: TextStyle(
                        fontSize: 9.5,
                        color: active ? RoomColors.magenta : RoomColors.textSecondary)),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final SessionModel session;
  const _Sidebar({required this.session});

  @override
  Widget build(BuildContext context) {
    final parts = session.formattedSchedule?.split(' · ') ?? const [];
    return Container(
      decoration: roomPanelDecoration(),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SESSION DETAILS',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: RoomColors.textSecondary,
                  letterSpacing: 0.6)),
          const SizedBox(height: 14),
          _detailRow('Date', parts.isNotEmpty ? parts.first : '-'),
          _detailRow('Time', parts.length > 1 ? parts.last : '-'),
          _detailRow('Duration', '${session.durationMins} Minutes'),
          _detailRow('Subject', session.subject),
          const SizedBox(height: 6),
          Row(children: [
            const Text('Status', style: TextStyle(fontSize: 11, color: RoomColors.textSecondary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: RoomColors.green.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('In Progress',
                  style: TextStyle(
                      fontSize: 10, color: RoomColors.green, fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 66,
              child:
                  Text(label, style: const TextStyle(fontSize: 11, color: RoomColors.textSecondary))),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, color: RoomColors.textPrimary, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

class _FooterBar extends StatelessWidget {
  final SessionModel session;
  const _FooterBar({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: RoomColors.line))),
      child: Wrap(
        spacing: 24,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            session.title?.trim().isNotEmpty == true ? session.title! : session.subject,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: RoomColors.textPrimary),
          ),
          _footItem('Schedule', session.formattedSchedule ?? '-'),
          _footItem('Duration', '${session.durationMins} Minutes'),
        ],
      ),
    );
  }

  Widget _footItem(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 9.5, color: RoomColors.textSecondary)),
          Text(value,
              style: const TextStyle(
                  fontSize: 11, color: RoomColors.textPrimary, fontWeight: FontWeight.w600)),
        ],
      );
}

class _SessionEndedView extends StatelessWidget {
  final VoidCallback onDone;
  const _SessionEndedView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_rounded, size: 56, color: RoomColors.green),
        const SizedBox(height: 16),
        const Text('Session Completed',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: RoomColors.textPrimary)),
        const Text('课程已完成', style: TextStyle(fontSize: 12, color: RoomColors.textSecondary)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: RoomColors.magenta,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Back to My Sessions'),
        ),
      ]),
    );
  }
}
