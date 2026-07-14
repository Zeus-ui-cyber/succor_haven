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
      body: Stack(
        children: [
          const Positioned(
            top: -60,
            right: -60,
            child: _Glow(color: SHColors.magenta, size: 220, opacity: 0.14),
          ),
          const Positioned(
            bottom: 40,
            left: -80,
            child: _Glow(color: SHColors.burgundy, size: 200, opacity: 0.10),
          ),
          SafeArea(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: SHColors.magenta)),
              error: (e, _) => _ErrorState(
                message: '$e',
                onRetry: () =>
                    ref.invalidate(teacherDetailsProvider(teacherId)),
              ),
              data: (teacher) => _TeacherDetailBody(teacher: teacher),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _Glow({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0)
            ],
          ),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top bar: back + favorite, sitting above the hero card so
          // they read as page chrome rather than photo overlay controls.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _GlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
                background: SHColors.paper,
                iconColor: SHColors.ink,
                border: SHColors.line,
              ),
              // ⚠️ NOT YET FUNCTIONAL: there's no "favorite teacher"
              // endpoint or local store wired up anywhere in this app.
              // Shown as a disabled affordance (same pattern as the
              // attachment placeholder in request_appointment_screen.dart)
              // rather than a working button, so it doesn't silently do
              // nothing when tapped. Wire up a real favorites provider
              // before enabling this.
              Opacity(
                opacity: 0.6,
                child: IgnorePointer(
                  child: _GlassIconButton(
                    icon: Icons.favorite_border_rounded,
                    onTap: () {},
                    background: SHColors.paper,
                    iconColor: SHColors.burgundy,
                    border: SHColors.line,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Compact premium hero card: avatar, name, role, stat chips
          // and quick actions, all in one gradient card (mirrors the
          // reference design) instead of a full-bleed photo hero.
          _HeroCard(teacher: teacher, avatarUrl: avatarUrl),
          const SizedBox(height: 18),

          // ── Subjects ────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.menu_book_rounded,
            title: 'Subjects',
            titleCn: '科目',
            child: teacher.subjects.isEmpty
                ? const _EmptyLine('No subjects listed yet')
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: teacher.subjects
                        .map((s) => _SubjectPill(label: s))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),

          // ── Bio ─────────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.person_outline_rounded,
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
          const SizedBox(height: 16),

          // ── Availability ────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.event_available_rounded,
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
                                    color:
                                        SHColors.green.withValues(alpha: 0.3)),
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
          const SizedBox(height: 24),

          // ── CTA ─────────────────────────────────────────────────────────
          _RequestAppointmentButton(teacher: teacher),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Hero card — compact gradient card: avatar, name, role, stat chips,
// and quick actions. Built only from fields the model actually has.
// ════════════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  final TeacherProfileModel teacher;
  final String? avatarUrl;
  const _HeroCard({required this.teacher, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SHColors.burgundy, SHColors.magenta],
        ),
        boxShadow: [
          BoxShadow(
            color: SHColors.magenta.withValues(alpha: 0.32),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle decorative glow so the card reads as premium rather
          // than a flat gradient block.
          Positioned(
            top: -30,
            right: -30,
            child: IgnorePointer(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Avatar(avatarUrl: avatarUrl, initials: teacher.initials),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(teacher.fullName,
                            style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(teacher.isNewTeacher ? 'New Teacher' : 'Teacher',
                            style: TextStyle(
                                fontSize: 13.5,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Stat chips + quick actions ─────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _buildStatChips(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Quick actions (message / call / video)
                  // ⚠️ NOT YET FUNCTIONAL: no chat, voice, or video-call
                  // backend exists in this app yet. Shown disabled, same
                  // reasoning as the favorite button above — a real
                  // placeholder rather than a dead tap target that looks
                  // live. Wire these up once messaging/calling exists.
                  Opacity(
                    opacity: 0.6,
                    child: IgnorePointer(
                      child: Row(
                        children: [
                          _GlassIconButton(
                              icon: Icons.chat_bubble_outline_rounded,
                              onTap: () {},
                              size: 36),
                          const SizedBox(width: 8),
                          _GlassIconButton(
                              icon: Icons.call_outlined,
                              onTap: () {},
                              size: 36),
                          const SizedBox(width: 8),
                          _GlassIconButton(
                              icon: Icons.videocam_outlined,
                              onTap: () {},
                              size: 36),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatChips() {
    final chips = <Widget>[
      _StatChip(
        icon: Icons.menu_book_rounded,
        label: teacher.subjects.length == 1
            ? '1 Subject'
            : '${teacher.subjects.length} Subjects',
      ),
      _StatChip(
        icon: Icons.workspace_premium_rounded,
        label:
            teacher.isNewTeacher ? 'New' : '${teacher.totalSessions} sessions',
      ),
    ];
    if (teacher.hasRating) {
      chips.add(_StatChip(
        icon: Icons.star_rounded,
        iconColor: const Color(0xFFFFC107),
        label: teacher.rating.toStringAsFixed(1),
      ));
    }
    return chips;
  }
}

/// Circular avatar used in the hero card — shows the teacher's photo when
/// available, otherwise a monogram on the brand gradient.
class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  const _Avatar({required this.avatarUrl, required this.initials});

  @override
  Widget build(BuildContext context) {
    const double diameter = 74;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: avatarUrl != null
            ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    _AvatarFallback(initials: initials),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _AvatarFallback(initials: initials);
                },
              )
            : _AvatarFallback(initials: initials),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initials;
  const _AvatarFallback({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.10),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Small pill used inside the hero card to surface a single stat
/// (subject count, session count, rating, etc).
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  const _StatChip({required this.icon, required this.label, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor ?? Colors.white),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color background;
  final Color iconColor;
  final Color border;
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.background = Colors.white24,
    this.iconColor = Colors.white,
    this.border = Colors.white38,
  });

  @override
  Widget build(BuildContext context) {
    final isGlass = background == Colors.white24;
    return Material(
      color: isGlass ? Colors.white.withValues(alpha: 0.16) : background,
      shape: const CircleBorder(),
      elevation: isGlass ? 0 : 2,
      shadowColor: SHColors.ink.withValues(alpha: 0.08),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: isGlass ? Colors.white.withValues(alpha: 0.28) : border),
          ),
          child: Icon(icon, size: size * 0.42, color: iconColor),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Section card — consistent with request_appointment_screen.dart
// ════════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title, titleCn;
  final Widget child;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.titleCn,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SHColors.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SHColors.line),
        boxShadow: [
          BoxShadow(
            color: SHColors.ink.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [SHColors.blushPink, SHColors.softPink]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: SHColors.burgundy),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: SHColors.ink)),
                Text('· $titleCn',
                    style:
                        const TextStyle(fontSize: 11, color: SHColors.magenta)),
              ],
            ),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child:
                Divider(height: 1, color: SHColors.line.withValues(alpha: 0.7)),
          ),
          child,
        ],
      ),
    );
  }
}

class _SubjectPill extends StatelessWidget {
  final String label;
  const _SubjectPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          SHColors.blushPink,
          SHColors.softPink.withValues(alpha: 0.8)
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SHColors.magenta.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: SHColors.burgundy)),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String text;
  const _EmptyLine(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 13, color: SHColors.inkSoft));
}

// ════════════════════════════════════════════════════════════════════
// CTA — navigates to request_appointment_screen.dart, unchanged route
// ════════════════════════════════════════════════════════════════════
class _RequestAppointmentButton extends StatelessWidget {
  final TeacherProfileModel teacher;
  const _RequestAppointmentButton({required this.teacher});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [SHColors.burgundy, SHColors.magenta],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: SHColors.magenta.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          onTap: () {
            // ⚠️ NOT YET BUILT (as of the original placeholder note): the
            // appointment request form screen may still need to be created
            // at features/appointments/screens/request_appointment_screen.dart
            // and registered as '/appointments/request' in main.dart's routes
            // map (or an onGenerateRoute branch) before this button works.
            // Route call-site kept identical to the original implementation.
            Navigator.pushNamed(
              context,
              '/appointments/request',
              arguments: teacher,
            );
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_month_rounded,
                    size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text('Request Appointment · 预约咨询',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
