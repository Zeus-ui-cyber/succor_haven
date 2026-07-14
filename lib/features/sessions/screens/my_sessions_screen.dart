// lib/features/sessions/screens/my_sessions_screen.dart
//
// Embeddable "My Sessions" view — unified feed of pending appointment
// requests + real sessions (from either bookings or appointments). Used
// as a dashboard tab body on both student_dashboard_screen.dart and
// teacher_dashboard_screen.dart (replacing their old raw-/bookings-only
// tabs), not a standalone Scaffold, so it can drop into each dashboard's
// existing IndexedStack.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session.dart';
import '../../../models/user.dart';
import '../controllers/session_list_controller.dart';
import '../widgets/session_card.dart';

class _P {
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
  static const magenta = Color(0xFFD64577);
  static const slateBlue = Color(0xFF3E678A);
}

class MySessionsView extends ConsumerWidget {
  final UserModel user;
  const MySessionsView({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(mySessionsProvider);
    final isTeacher = user.isTeacher;
    final accent = isTeacher ? _P.slateBlue : _P.magenta;

    return RefreshIndicator(
      color: accent,
      onRefresh: () async => ref.invalidate(mySessionsProvider),
      child: sessionsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: accent)),
        error: (e, _) => ListView(children: [
          const SizedBox(height: 80),
          Center(child: Text('$e', style: const TextStyle(color: _P.inkSoft))),
        ]),
        data: (items) {
          if (items.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              _EmptyState(),
            ]);
          }

          final pending = items
              .where((s) =>
                  s.status == SessionCardStatus.pending ||
                  s.status == SessionCardStatus.rescheduled)
              .toList();
          final upcoming = items
              .where((s) =>
                  s.status == SessionCardStatus.upcoming ||
                  s.status == SessionCardStatus.inProgress)
              .toList();
          final past = items
              .where((s) =>
                  s.status == SessionCardStatus.completed ||
                  s.status == SessionCardStatus.cancelled ||
                  s.status == SessionCardStatus.missed ||
                  s.status == SessionCardStatus.declined)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (pending.isNotEmpty) ...[
                const _SectionLabel('Pending Approval · 待批准'),
                ...pending.map((s) => SessionCard(
                      session: s,
                      isTeacherView: isTeacher,
                      onTap: () {},
                    )),
                const SizedBox(height: 16),
              ],
              if (upcoming.isNotEmpty) ...[
                const _SectionLabel('Upcoming · 即将上课'),
                ...upcoming.map((s) => SessionCard(
                      session: s,
                      isTeacherView: isTeacher,
                      onTap: s.isJoinable()
                          ? () =>
                              Navigator.pushNamed(context, '/sessions/${s.id}')
                          : null,
                    )),
                const SizedBox(height: 16),
              ],
              if (past.isNotEmpty) ...[
                const _SectionLabel('Past · 历史课程'),
                ...past.map((s) => SessionCard(
                      session: s,
                      isTeacherView: isTeacher,
                      onTap: () =>
                          Navigator.pushNamed(context, '/sessions/${s.id}'),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: _P.inkSoft)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(children: const [
      Icon(Icons.video_camera_front_outlined, size: 48, color: _P.inkSoft),
      SizedBox(height: 12),
      Text('No sessions yet',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: _P.ink)),
      SizedBox(height: 4),
      Text('暂无课程', style: TextStyle(fontSize: 12, color: _P.inkSoft)),
    ]);
  }
}
