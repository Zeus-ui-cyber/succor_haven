// lib/features/sessions/screens/session_detail_screen.dart
//
// Pre-join details screen. Once inside the join window, embeds the
// real SessionRoomScreen in place of the old video-call placeholder —
// routing (Navigator.pushNamed(context, '/sessions/$id')) is unchanged,
// so this stays the single entry point for both states.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../booking/utils/avatar_url.dart';
import '../controllers/session_list_controller.dart';
import 'session_room_screen.dart';

class _P {
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
  static const cream = Color(0xFFFFF5F7);
  static const line = Color(0xFFF0DCE5);
  static const magenta = Color(0xFFD64577);
}

// FIXED: this must be a stable top-level provider, not created inline
// inside build(). `ref.watch(FutureProvider((r) => ...))` was
// instantiating a NEW provider on every rebuild, which restarted
// getMe() before the previous call ever resolved — the screen was
// stuck in the `loading` branch forever, which is why joining a
// session appeared to hang indefinitely on both the teacher and
// student side (this gate sits in front of SessionRoomScreen).
final _currentUserProvider =
    FutureProvider<dynamic>((ref) => AuthRepository().getMe());

class SessionDetailScreen extends ConsumerWidget {
  final String sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionDetailProvider(sessionId));
    final meAsync = ref.watch(_currentUserProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(
        backgroundColor: _P.cream,
        body: Center(child: CircularProgressIndicator(color: _P.magenta)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _P.cream,
        appBar: AppBar(
            backgroundColor: _P.cream, elevation: 0, foregroundColor: _P.ink),
        body: Center(child: Text('$e')),
      ),
      data: (session) => meAsync.when(
        loading: () => const Scaffold(
          backgroundColor: _P.cream,
          body: Center(child: CircularProgressIndicator(color: _P.magenta)),
        ),
        error: (e, _) => Scaffold(
          backgroundColor: _P.cream,
          body: Center(child: Text('$e')),
        ),
        data: (me) {
          if (session.isJoinable()) {
            // Real meeting room — dark theme, its own Scaffold.
            return SessionRoomScreen(session: session, currentUser: me);
          }
          return Scaffold(
            backgroundColor: _P.cream,
            appBar: AppBar(
              backgroundColor: _P.cream,
              elevation: 0,
              foregroundColor: _P.ink,
              title: const Text('Session Details · 课程详情'),
            ),
            body: _WaitingBody(session: session),
          );
        },
      ),
    );
  }
}

class _WaitingBody extends StatelessWidget {
  final SessionModel session;
  const _WaitingBody({required this.session});

  @override
  Widget build(BuildContext context) {
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              session.scheduledAt != null
                  ? '${session.scheduledAt}'
                  : 'Schedule pending',
              style: const TextStyle(color: _P.inkSoft, fontSize: 13),
            ),
            Text('${session.durationMins} minutes',
                style: const TextStyle(color: _P.inkSoft, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 20),
        Container(
          height: 220,
          decoration: BoxDecoration(
              color: _P.ink, borderRadius: BorderRadius.circular(20)),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.lock_clock_outlined, color: Colors.white70, size: 40),
            SizedBox(height: 12),
            Text(
              'The video meeting room will unlock at the\nscheduled start time.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ]),
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
          ? Text((name?.isNotEmpty ?? false) ? name![0].toUpperCase() : '?',
              style: const TextStyle(
                  fontSize: 11, color: _P.magenta, fontWeight: FontWeight.w700))
          : null,
    );
  }
}
