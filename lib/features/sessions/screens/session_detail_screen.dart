// lib/features/sessions/screens/session_detail_screen.dart
//
// Phase 1 stub: shows the session's confirmed details and, once inside
// the join window, a placeholder for the meeting room. The actual
// WebRTC video call (camera/mic, chat, whiteboard, etc. — Phase 2+ of
// the "My Sessions" build-out) replaces the placeholder area below
// without needing to change how this screen is reached.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session.dart';
import '../../booking/utils/avatar_url.dart';
import '../controllers/session_list_controller.dart';

class _P {
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
  static const cream = Color(0xFFFFF5F7);
  static const line = Color(0xFFF0DCE5);
  static const magenta = Color(0xFFD64577);
}

class SessionDetailScreen extends ConsumerWidget {
  final String sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionDetailProvider(sessionId));

    return Scaffold(
      backgroundColor: _P.cream,
      appBar: AppBar(
        backgroundColor: _P.cream,
        elevation: 0,
        foregroundColor: _P.ink,
        title: const Text('Session Details · 课程详情'),
      ),
      body: sessionAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _P.magenta)),
        error: (e, _) => Center(child: Text('$e')),
        data: (session) => _SessionDetailBody(session: session),
      ),
    );
  }
}

class _SessionDetailBody extends StatelessWidget {
  final SessionModel session;
  const _SessionDetailBody({required this.session});

  @override
  Widget build(BuildContext context) {
    final joinable = session.isJoinable();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _P.line),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              session.title?.trim().isNotEmpty == true
                  ? session.title!
                  : session.subject,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _P.ink),
            ),
            const SizedBox(height: 12),
            Row(children: [
              _avatar(session.teacherAvatarUrl, session.teacherName),
              const SizedBox(width: 10),
              Text('Teacher: ${session.teacherName ?? '-'}',
                  style: const TextStyle(color: _P.inkSoft)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _avatar(session.studentAvatarUrl, session.studentName),
              const SizedBox(width: 10),
              Text('Student: ${session.studentName ?? '-'}',
                  style: const TextStyle(color: _P.inkSoft)),
            ]),
            const SizedBox(height: 12),
            Text(
              session.formattedSchedule ?? 'Schedule pending',
              style: const TextStyle(color: _P.inkSoft, fontSize: 13),
            ),
            Text('${session.durationMins} minutes',
                style: const TextStyle(color: _P.inkSoft, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 20),
        Material(
          color: _P.ink,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: joinable
                ? () => Navigator.pushNamed(context, '/sessions/${session.id}/room')
                : null,
            child: Container(
              height: 260,
              alignment: Alignment.center,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  joinable ? Icons.videocam_rounded : Icons.lock_clock_outlined,
                  color: Colors.white70,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  joinable
                      ? 'Tap to join the meeting room'
                      : 'The video meeting room will unlock at the\nscheduled start time.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatar(String? url, String? name) {
    final resolved = resolveAvatarUrl(url);
    return CircleAvatar(
      radius: 14,
      backgroundColor: _P.magenta.withValues(alpha: 0.15),
      backgroundImage: resolved != null ? NetworkImage(resolved) : null,
      child: resolved == null
          ? Text(
              (name?.isNotEmpty ?? false) ? name![0].toUpperCase() : '?',
              style: const TextStyle(
                  fontSize: 11, color: _P.magenta, fontWeight: FontWeight.w700),
            )
          : null,
    );
  }
}
