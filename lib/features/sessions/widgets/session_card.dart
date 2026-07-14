// lib/features/sessions/widgets/session_card.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/session.dart';
import '../../booking/utils/avatar_url.dart';

class _P {
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
  static const line = Color(0xFFF0DCE5);
  static const paper = Color(0xFFFFFFFF);
  static const magenta = Color(0xFFD64577);
  static const slateBlue = Color(0xFF3E678A);
  static const green = Color(0xFF00C48C);
}

/// Card for one item in the unified "My Sessions" feed. `isTeacherView`
/// picks which side's name/avatar to show as the "other party" — a
/// student sees the teacher, a teacher sees the student.
class SessionCard extends StatelessWidget {
  final SessionModel session;
  final bool isTeacherView;
  final VoidCallback? onTap;

  const SessionCard({
    super.key,
    required this.session,
    required this.isTeacherView,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final otherName =
        (isTeacherView ? session.studentName : session.teacherName) ??
            'Unknown';
    final otherAvatar = resolveAvatarUrl(
      isTeacherView ? session.studentAvatarUrl : session.teacherAvatarUrl,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _P.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _P.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      session.title?.trim().isNotEmpty == true
                          ? session.title!
                          : session.subject,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _P.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusBadge(status: session.status),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _P.magenta.withValues(alpha: 0.15),
                    backgroundImage:
                        otherAvatar != null ? NetworkImage(otherAvatar) : null,
                    child: otherAvatar == null
                        ? Text(
                            otherName.isNotEmpty
                                ? otherName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: _P.magenta, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isTeacherView ? 'Student: $otherName' : 'Teacher: $otherName',
                      style: const TextStyle(fontSize: 13, color: _P.inkSoft),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                _ScheduleRow(session: session),
                if (!session.isPendingAppointment) ...[
                  const SizedBox(height: 12),
                  _JoinButton(session: session),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final SessionModel session;
  const _ScheduleRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final label = session.formattedSchedule;
    if (label == null) {
      return const Row(children: [
        Icon(Icons.schedule_outlined, size: 14, color: _P.inkSoft),
        SizedBox(width: 6),
        Text('Awaiting confirmed schedule',
            style: TextStyle(fontSize: 12, color: _P.inkSoft)),
      ]);
    }
    return Row(children: [
      const Icon(Icons.event_outlined, size: 14, color: _P.inkSoft),
      const SizedBox(width: 6),
      Expanded(
        child: Text(label,
            style: const TextStyle(fontSize: 12, color: _P.inkSoft)),
      ),
      const SizedBox(width: 6),
      const Icon(Icons.timer_outlined, size: 14, color: _P.inkSoft),
      const SizedBox(width: 4),
      Text('${session.durationMins} min',
          style: const TextStyle(fontSize: 12, color: _P.inkSoft)),
    ]);
  }
}

class _StatusBadge extends StatelessWidget {
  final SessionCardStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.paleColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.badgeLabel.split(' · ').first,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: status.color,
        ),
      ),
    );
  }
}

/// Ticks every 30s so the button flips from disabled -> "Join Meeting"
/// exactly at the scheduled start time without needing a screen refresh.
class _JoinButton extends StatefulWidget {
  final SessionModel session;
  const _JoinButton({required this.session});

  @override
  State<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends State<_JoinButton> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;

    if (s.status == SessionCardStatus.completed) {
      return _pill('Session Completed', _P.inkSoft, filled: false);
    }
    if (s.status == SessionCardStatus.cancelled) {
      return _pill('Cancelled', _P.inkSoft, filled: false);
    }
    if (s.status == SessionCardStatus.missed) {
      return _pill('Missed Session', _P.inkSoft, filled: false);
    }

    if (s.isJoinable()) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () =>
              Navigator.pushNamed(context, '/sessions/${s.id}'),
          icon: const Icon(Icons.videocam_rounded, size: 18),
          label: const Text('Join Meeting · 加入课程'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _P.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    final until = s.timeUntilJoinable();
    final label = until == null
        ? 'Join Disabled'
        : until.inMinutes <= 0
            ? 'Meeting starts shortly'
            : until.inHours >= 1
                ? 'Meeting starts in ${until.inHours}h ${until.inMinutes % 60}m'
                : 'Meeting starts in ${until.inMinutes} min';

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.lock_clock_outlined, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: _P.inkSoft,
          side: const BorderSide(color: _P.line),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _pill(String label, Color color, {required bool filled}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }
}
