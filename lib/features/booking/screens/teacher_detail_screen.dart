// lib/features/booking/screens/teacher_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart' show SHColors;
import '../../../models/teacher_profile.dart';
import '../controllers/booking_controller.dart';
import '../utils/avatar_url.dart';

class TeacherDetailScreen extends ConsumerWidget {
  final String teacherId;
  const TeacherDetailScreen({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherDetailsProvider(teacherId));

    return Scaffold(
      backgroundColor: SHColors.bg,
      body: SafeArea(
        child: async.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: SHColors.magenta)),
          error: (e, _) => _ErrorState(
            message: '$e',
            onRetry: () => ref.invalidate(teacherDetailsProvider(teacherId)),
          ),
          data: (teacher) => _TeacherDetailBody(teacher: teacher),
        ),
      ),
    );
  }
}

class _TeacherDetailBody extends StatelessWidget {
  final TeacherProfileModel teacher;
  const _TeacherDetailBody({required this.teacher});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = resolveAvatarUrl(teacher.avatarUrl);

    return CustomScrollView(
      slivers: [
        // ── Header / back button ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: SHColors.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SHColors.line),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: SHColors.ink),
                ),
              ),
            ]),
          ),
        ),

        // ── Profile hero ─────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: SHColors.blushPink,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(teacher.initials,
                        style: const TextStyle(
                            fontSize: 32,
                            color: SHColors.burgundy,
                            fontWeight: FontWeight.w800))
                    : null,
              ),
              const SizedBox(height: 14),
              Text(teacher.fullName,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: SHColors.ink)),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (teacher.hasRating) ...[
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFFFC107), size: 18),
                  const SizedBox(width: 4),
                  Text(teacher.rating.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: SHColors.ink)),
                  const SizedBox(width: 10),
                  Container(width: 1, height: 14, color: SHColors.line),
                  const SizedBox(width: 10),
                ],
                Text(
                    teacher.isNewTeacher
                        ? 'New teacher'
                        : '${teacher.totalSessions} sessions taught',
                    style: const TextStyle(
                        fontSize: 13,
                        color: SHColors.inkSoft,
                        fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
        ),

        // ── Subjects ──────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _Section(
              title: 'Subjects',
              titleCn: '科目',
              child: teacher.subjects.isEmpty
                  ? const _EmptyLine('No subjects listed yet')
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: teacher.subjects
                          .map((s) => Chip(label: Text(s)))
                          .toList(),
                    ),
            ),
          ),
        ),

        // ── Bio ───────────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _Section(
              title: 'About',
              titleCn: '简介',
              child: Text(
                (teacher.bio != null && teacher.bio!.trim().isNotEmpty)
                    ? teacher.bio!
                    : 'This teacher hasn\'t added a bio yet.',
                style: const TextStyle(
                    fontSize: 13.5, color: SHColors.ink, height: 1.6),
              ),
            ),
          ),
        ),

        // ── Availability ──────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _Section(
              title: 'Weekly Availability',
              titleCn: '每周可预约时间',
              child: teacher.availability.isEmpty
                  ? const _EmptyLine('No availability set yet')
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: teacher.availability
                          .map((day) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: SHColors.greenPale,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: SHColors.green
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Text(day,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: SHColors.green)),
                              ))
                          .toList(),
                    ),
            ),
          ),
        ),

        // ── Actions ───────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
          sliver: SliverToBoxAdapter(
            child: Column(children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // ⚠️ NOT YET BUILT: the appointment request form screen
                    // doesn't exist yet. This route is a placeholder —
                    // create features/appointments/screens/request_appointment_screen.dart
                    // and register '/appointments/request' in main.dart's
                    // routes map (or an onGenerateRoute branch) before this
                    // button will actually work. Wiring it here now so the
                    // navigation call-site exists and doesn't need another
                    // pass through teacher_detail_screen.dart later.
                    Navigator.pushNamed(
                      context,
                      '/appointments/request',
                      arguments: teacher,
                    );
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: const Text('Request Appointment · 预约咨询'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title, titleCn;
  final Widget child;
  const _Section(
      {required this.title, required this.titleCn, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: SHColors.ink)),
          const SizedBox(width: 6),
          Text('· $titleCn',
              style: const TextStyle(fontSize: 12, color: SHColors.magenta)),
        ]),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String text;
  const _EmptyLine(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, color: SHColors.inkSoft));
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded,
              size: 40, color: SHColors.inkSoft),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: SHColors.inkSoft)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      ),
    );
  }
}