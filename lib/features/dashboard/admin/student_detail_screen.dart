// lib/features/dashboard/admin/student_detail_screen.dart
//
// Visual redesign only — all data logic, providers, and API calls are
// unchanged from the previous version. Built with core Flutter widgets
// (BackdropFilter, TweenAnimationBuilder, gradient decorations) rather
// than adding new package dependencies.

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../auth/repositories/auth_repository.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
class _C {
  static const bgTop = Color(0xFFFFF8FC);
  static const bgMid = Color(0xFFFDF2F8);
  static const bgBottom = Color(0xFFFFEAF4);

  static const pink = Color(0xFFFF8FC5);
  static const lightPink = Color(0xFFFFC5E3);
  static const mint = Color(0xFF8EE7C8);
  static const sky = Color(0xFFB9DDFF);
  static const lavender = Color(0xFFDFC8FF);
  static const cream = Color(0xFFFFF6D8);

  static const ink = Color(0xFF44223B);
  static const inkSoft = Color(0xFF8C7084);
  static const paper = Colors.white;
}

// Guards against empty/null first_name or last_name — a bad row shouldn't
// crash on ''[0]. Mirrors the helper in students_list_screen.dart.
String _initials(String? first, String? last) {
  final f = (first ?? '').trim();
  final l = (last ?? '').trim();
  if (f.isEmpty && l.isEmpty) return '?';
  if (f.isEmpty) return l[0].toUpperCase();
  if (l.isEmpty) return f[0].toUpperCase();
  return '${f[0]}${l[0]}'.toUpperCase();
}

// Same resolver as students_list_screen.dart — avatar_url from the backend
// is likely a relative path (multer saves to uploads/profile-pictures/,
// served statically at /uploads/..., separate from /api/v1 routes).
String? _resolveAvatarUrl(String? rawUrl) {
  if (rawUrl == null || rawUrl.isEmpty) return null;
  if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
    return rawUrl;
  }
  final apiBase = AuthRepository.baseUrl;
  final fileHost = apiBase.replaceFirst(RegExp(r'/api/v\d+/?$'), '');
  final path = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
  return '$fileHost$path';
}

int _asInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

final _detailRepoProvider = Provider((_) => AuthRepository());

Future<Map<String, String>> _headers(AuthRepository repo) async {
  final token = await repo.getAccessToken();
  return {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

final studentDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final repo = ref.read(_detailRepoProvider);
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/admin/students/$id'),
    headers: await _headers(repo),
  );
  if (res.statusCode != 200) throw Exception('Failed to load student');
  return jsonDecode(res.body) as Map<String, dynamic>;
});

class StudentDetailScreen extends ConsumerWidget {
  final String studentId;
  const StudentDetailScreen({super.key, required this.studentId});

  // ── Actions (unchanged logic) ────────────────────────────────────────────

  Future<void> _toggleActive(BuildContext ctx, WidgetRef ref) async {
    final repo = ref.read(_detailRepoProvider);
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/admin/users/$studentId/toggle'),
      headers: await _headers(repo),
    );
    if (!ctx.mounted) return;
    final active =
        res.statusCode == 200 ? (jsonDecode(res.body)['isActive'] as bool?) : null;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(active == true
          ? 'Student activated'
          : active == false
              ? 'Student deactivated'
              : 'Failed to update status'),
      backgroundColor: active == true ? _C.mint : _C.pink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
    ref.invalidate(studentDetailProvider(studentId));
  }

  Future<void> _resetPassword(BuildContext ctx, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => _GlassDialog(
        title: 'Reset Password?',
        body:
            'This will generate a new temporary password for this student. Share it with them securely.',
        actions: [
          _DialogButton(
              label: 'Cancel',
              onTap: () => Navigator.pop(dctx, false),
              filled: false),
          _DialogButton(
              label: 'Reset',
              onTap: () => Navigator.pop(dctx, true),
              filled: true,
              color: _C.pink),
        ],
      ),
    );
    if (confirmed != true) return;

    final repo = ref.read(_detailRepoProvider);
    final res = await http.post(
      Uri.parse('${AuthRepository.baseUrl}/admin/students/$studentId/reset-password'),
      headers: await _headers(repo),
    );
    if (!ctx.mounted) return;
    if (res.statusCode == 200) {
      final tempPassword = jsonDecode(res.body)['tempPassword'];
      showDialog(
        context: ctx,
        builder: (dctx) => _GlassDialog(
          title: 'Temporary Password',
          bodyWidget: SelectableText(
            tempPassword,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: _C.pink),
          ),
          actions: [
            _DialogButton(
                label: 'Done',
                onTap: () => Navigator.pop(dctx),
                filled: true,
                color: _C.pink),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('Failed to reset password'),
        backgroundColor: _C.pink,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _deleteStudent(BuildContext ctx, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => _GlassDialog(
        title: 'Delete Student?',
        body:
            'This permanently deletes the account. This cannot be undone. Students with booking history cannot be deleted — deactivate instead.',
        actions: [
          _DialogButton(
              label: 'Cancel',
              onTap: () => Navigator.pop(dctx, false),
              filled: false),
          _DialogButton(
              label: 'Delete',
              onTap: () => Navigator.pop(dctx, true),
              filled: true,
              color: _C.pink),
        ],
      ),
    );
    if (confirmed != true) return;

    final repo = ref.read(_detailRepoProvider);
    final res = await http.delete(
      Uri.parse('${AuthRepository.baseUrl}/admin/users/$studentId'),
      headers: await _headers(repo),
    );
    if (!ctx.mounted) return;
    if (res.statusCode == 200) {
      Navigator.pop(ctx, true);
    } else {
      final err = jsonDecode(res.body)['error'] ?? 'Delete failed';
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: _C.pink,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _openEditSheet(
      BuildContext ctx, WidgetRef ref, Map<String, dynamic> profile) async {
    final firstNameCtrl =
        TextEditingController(text: profile['first_name']?.toString() ?? '');
    final lastNameCtrl =
        TextEditingController(text: profile['last_name']?.toString() ?? '');
    final emailCtrl =
        TextEditingController(text: profile['email']?.toString() ?? '');
    final phoneCtrl =
        TextEditingController(text: profile['phone']?.toString() ?? '');
    final courseCtrl =
        TextEditingController(text: profile['course']?.toString() ?? '');
    final yearLevelCtrl =
        TextEditingController(text: profile['year_level']?.toString() ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_C.bgTop, _C.bgMid],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _C.lightPink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Text('Edit Student',
                      style: TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800, color: _C.ink)),
                  const SizedBox(height: 18),
                  _EditField('First Name', firstNameCtrl),
                  _EditField('Last Name', lastNameCtrl),
                  _EditField('Email', emailCtrl),
                  _EditField('Phone', phoneCtrl),
                  _EditField('Course', courseCtrl),
                  _EditField('Year Level', yearLevelCtrl),
                  const SizedBox(height: 8),
                  _FloatingPillButton(
                    label: 'Save Changes',
                    gradient: const [_C.pink, Color(0xFFFF6FAE)],
                    onTap: () => Navigator.pop(sheetCtx, true),
                  ),
                ]),
          ),
        ),
      ),
    );

    if (saved != true) return;

    final repo = ref.read(_detailRepoProvider);
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/admin/students/$studentId'),
      headers: await _headers(repo),
      body: jsonEncode({
        'firstName': firstNameCtrl.text,
        'lastName': lastNameCtrl.text,
        'email': emailCtrl.text,
        'phone': phoneCtrl.text,
        'course': courseCtrl.text,
        'yearLevel': yearLevelCtrl.text,
      }),
    );
    if (!ctx.mounted) return;
    if (res.statusCode == 200) {
      ref.invalidate(studentDetailProvider(studentId));
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: const Text('Student updated'),
        backgroundColor: _C.mint,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
    } else {
      final err = jsonDecode(res.body)['error'] ?? 'Update failed';
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: _C.pink,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentDetailProvider(studentId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _C.bgTop,
      body: Stack(
        children: [
          const _AmbientBackground(),
          SafeArea(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: _C.pink)),
              error: (e, _) => Center(
                  child: Text('$e', style: const TextStyle(color: _C.ink))),
              data: (data) {
                final profile = data['profile'] as Map<String, dynamic>;
                final takenSubjects = data['takenSubjects'] as List;
                final sessions = data['sessionHistory'] as List;
                final progress = data['progressSummary'] as Map<String, dynamic>;
                final timeline = data['activityTimeline'] as List;
                final active = profile['is_active'] == true;

                final firstName = profile['first_name'] as String?;
                final lastName = profile['last_name'] as String?;
                final displayName = [firstName, lastName]
                    .where((n) => n != null && n.trim().isNotEmpty)
                    .join(' ');
                final avatarUrl =
                    _resolveAvatarUrl(profile['avatar_url'] as String?);
                final course = profile['course']?.toString() ?? '';
                final yearLevel = profile['year_level']?.toString() ?? '';

                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
                  children: [
                    _TopBar(onBack: () => Navigator.pop(context)),
                    const SizedBox(height: 16),

                    // ── Student card ─────────────────────────────────────
                    _GlassCard(
                      child: Column(
                        children: [
                          _BreathingAvatar(
                            avatarUrl: avatarUrl,
                            initials: _initials(firstName, lastName),
                          ),
                          const SizedBox(height: 16),
                          Text(displayName.isEmpty ? 'Unnamed' : displayName,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: _C.ink)),
                          const SizedBox(height: 4),
                          Text('ID: ${profile['id']}',
                              style: const TextStyle(
                                  fontSize: 11, color: _C.inkSoft)),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _GlowBadge(
                                label: active ? 'Active' : 'Inactive',
                                colors: active
                                    ? [_C.mint, const Color(0xFF5FD9A8)]
                                    : [_C.inkSoft.withValues(alpha: 0.4), _C.inkSoft],
                              ),
                              _GlowBadge(
                                label: profile['phone_verified'] == true
                                    ? 'Verified'
                                    : 'Unverified',
                                colors: profile['phone_verified'] == true
                                    ? [_C.sky, const Color(0xFF6FB3FF)]
                                    : [_C.cream, const Color(0xFFE8B84B)],
                              ),
                              if (course.isNotEmpty)
                                _GlowBadge(label: course, colors: const [
                                  _C.pink,
                                  Color(0xFFFF6FAE)
                                ]),
                              if (yearLevel.isNotEmpty)
                                _GlowBadge(label: yearLevel, colors: const [
                                  _C.lavender,
                                  Color(0xFFB794F6)
                                ]),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Contact info ─────────────────────────────────────
                    _GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('Contact Information', '联系信息',
                              icon: Icons.person_outline_rounded,
                              iconColor: _C.pink),
                          const SizedBox(height: 14),
                          _InfoRow(Icons.mail_outline_rounded, 'Email',
                              profile['email'] ?? '-'),
                          _Divider(),
                          _InfoRow(Icons.call_outlined, 'Contact Number',
                              profile['phone'] ?? '-'),
                          _Divider(),
                          _InfoRow(Icons.event_outlined, 'Date Registered',
                              _formatDate(profile['created_at'])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Progress summary ─────────────────────────────────
                    const _SectionTitle('Progress Summary', '进度总览',
                        icon: Icons.insights_rounded, iconColor: _C.ink),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.check_circle_rounded,
                          value: _asInt(progress['totalSessionsCompleted']),
                          label: 'Completed',
                          colors: const [Color(0xFFB8F5DC), _C.mint],
                          iconColor: const Color(0xFF1FAE7C),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.calendar_month_rounded,
                          value: _asInt(progress['totalBookings']),
                          label: 'Bookings',
                          colors: const [Color(0xFFD6EBFF), _C.sky],
                          iconColor: const Color(0xFF3B82C4),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.menu_book_rounded,
                          value: _asInt(progress['subjectsCompleted']),
                          label: 'Subjects',
                          colors: const [Color(0xFFFFD9EC), _C.lightPink],
                          iconColor: const Color(0xFFD6488F),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.trending_up_rounded,
                          value: progress['attendanceRate'] as int?,
                          suffix: progress['attendanceRate'] != null ? '%' : '',
                          label: 'Attendance',
                          colors: const [Color(0xFFEBDCFF), _C.lavender],
                          iconColor: const Color(0xFF8759D6),
                          fallbackDash: progress['attendanceRate'] == null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    // ── Last session ─────────────────────────────────────
                    _LastSessionCard(
                        label: _formatDate(progress['lastSessionDate'])),
                    const SizedBox(height: 22),

                    // ── Taken subjects ────────────────────────────────────
                    const _SectionTitle('Taken Subjects', '已修科目',
                        icon: Icons.auto_stories_rounded, iconColor: _C.ink),
                    const SizedBox(height: 12),
                    takenSubjects.isEmpty
                        ? const _EmptyState(
                            emoji: '📚', text: 'No subjects yet')
                        : Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: takenSubjects
                                .map((s) => _SubjectChip(label: '$s'))
                                .toList(),
                          ),
                    const SizedBox(height: 22),

                    // ── Session history ───────────────────────────────────
                    const _SectionTitle('Session History', '课程记录',
                        icon: Icons.history_rounded, iconColor: _C.ink),
                    const SizedBox(height: 12),
                    sessions.isEmpty
                        ? const _EmptyState(
                            emoji: '🗓️', text: 'No sessions yet')
                        : Column(
                            children: sessions
                                .map((s) => _SessionTile(session: s))
                                .toList(),
                          ),
                    const SizedBox(height: 22),

                    // ── Activity timeline ─────────────────────────────────
                    const _SectionTitle('Activity Timeline', '活动记录',
                        icon: Icons.timeline_rounded, iconColor: _C.ink),
                    const SizedBox(height: 14),
                    _Timeline(entries: timeline),
                    const SizedBox(height: 24),

                    // ── Manage account ────────────────────────────────────
                    const _SectionTitle('Manage Account', '管理账户',
                        icon: Icons.settings_outlined, iconColor: _C.ink),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _PillActionButton(
                          label: 'Edit Info',
                          icon: Icons.edit_rounded,
                          colors: const [_C.sky, Color(0xFF6FB3FF)],
                          onTap: () => _openEditSheet(context, ref, profile),
                        ),
                        _PillActionButton(
                          label: active ? 'Deactivate' : 'Activate',
                          icon: active
                              ? Icons.toggle_off_outlined
                              : Icons.toggle_on_outlined,
                          colors: active
                              ? [_C.inkSoft.withValues(alpha: 0.5), _C.inkSoft]
                              : [_C.mint, const Color(0xFF5FD9A8)],
                          onTap: () => _toggleActive(context, ref),
                        ),
                        _PillActionButton(
                          label: 'Reset Password',
                          icon: Icons.lock_reset_rounded,
                          colors: const [_C.cream, Color(0xFFE8B84B)],
                          onTap: () => _resetPassword(context, ref),
                        ),
                        _PillActionButton(
                          label: 'Delete Account',
                          icon: Icons.delete_outline_rounded,
                          colors: const [_C.pink, Color(0xFFFF5C93)],
                          onTap: () => _deleteStudent(context, ref),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(dynamic iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso.toString())?.toLocal();
    if (dt == null) return '—';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Background ambience — soft blobs, no external packages
// ═══════════════════════════════════════════════════════════════════════════

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_C.bgTop, _C.bgMid, _C.bgBottom],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
              top: -70,
              right: -60,
              child: _blob(180, _C.lightPink.withValues(alpha: 0.55))),
          Positioned(
              top: 160,
              left: -80,
              child: _blob(150, _C.sky.withValues(alpha: 0.4))),
          Positioned(
              bottom: 120,
              right: -50,
              child: _blob(140, _C.lavender.withValues(alpha: 0.4))),
          Positioned(
              bottom: -60,
              left: -40,
              child: _blob(160, _C.mint.withValues(alpha: 0.35))),
          const Positioned(top: 40, right: 30, child: _Sparkle(size: 10)),
          const Positioned(top: 90, right: 70, child: _Sparkle(size: 6)),
          const Positioned(top: 200, left: 20, child: _Sparkle(size: 7)),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)]),
        ),
      );
}

class _Sparkle extends StatelessWidget {
  final double size;
  const _Sparkle({required this.size});
  @override
  Widget build(BuildContext context) => Icon(Icons.star_rounded,
      size: size, color: Colors.white.withValues(alpha: 0.8));
}

// ═══════════════════════════════════════════════════════════════════════════
// Top bar
// ═══════════════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleGlassButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        const SizedBox(width: 14),
        const Text('Student Profile',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w900, color: _C.ink)),
      ],
    );
  }
}

class _CircleGlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleGlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                  color: _C.pink.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: _C.ink),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Glass card — the base "floating 3D" container used throughout
// ═══════════════════════════════════════════════════════════════════════════

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 24),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.85),
                Colors.white.withValues(alpha: 0.55),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: _C.pink.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.9),
                blurRadius: 1,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Breathing avatar
// ═══════════════════════════════════════════════════════════════════════════

class _BreathingAvatar extends StatefulWidget {
  final String? avatarUrl;
  final String initials;
  const _BreathingAvatar({required this.avatarUrl, required this.initials});

  @override
  State<_BreathingAvatar> createState() => _BreathingAvatarState();
}

class _BreathingAvatarState extends State<_BreathingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showImage = widget.avatarUrl != null && !_failed;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final glow = 0.25 + (_ctrl.value * 0.25);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _C.pink.withValues(alpha: glow),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Container(
        width: 104,
        height: 104,
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_C.pink, Color(0xFFFF6FAE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ClipOval(
            child: showImage
                ? Image.network(
                    widget.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _failed = true);
                      });
                      return _initialsFallback();
                    },
                  )
                : _initialsFallback(),
          ),
        ),
      ),
    );
  }

  Widget _initialsFallback() => Center(
        child: Text(widget.initials,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 32)),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Glow badge (capsule)
// ═══════════════════════════════════════════════════════════════════════════

class _GlowBadge extends StatelessWidget {
  final String label;
  final List<Color> colors;
  const _GlowBadge({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11.5,
                color: Colors.white,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Section title
// ═══════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String en, zh;
  final IconData icon;
  final Color iconColor;
  const _SectionTitle(this.en, this.zh,
      {required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: iconColor),
      ),
      const SizedBox(width: 10),
      Text(en,
          style: const TextStyle(
              fontSize: 15.5, fontWeight: FontWeight.w800, color: _C.ink)),
      const SizedBox(width: 6),
      Text('· $zh',
          style: const TextStyle(fontSize: 12, color: _C.inkSoft)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Contact info row
// ═══════════════════════════════════════════════════════════════════════════

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_C.lightPink, _C.pink]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 17, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 10.5, color: _C.inkSoft)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _C.ink)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
        color: _C.inkSoft.withValues(alpha: 0.12),
        height: 1,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Progress stat card, with counter animation
// ═══════════════════════════════════════════════════════════════════════════

class _StatCard extends StatefulWidget {
  final IconData icon;
  final int? value;
  final String suffix;
  final String label;
  final List<Color> colors;
  final Color iconColor;
  final bool fallbackDash;
  const _StatCard({
    required this.icon,
    required this.value,
    this.suffix = '',
    required this.label,
    required this.colors,
    required this.iconColor,
    this.fallbackDash = false,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: widget.colors.last.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(widget.icon, size: 18, color: widget.iconColor),
              ),
              const SizedBox(height: 12),
              widget.fallbackDash
                  ? const Text('—',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: _C.ink))
                  : TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: widget.value ?? 0),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (_, val, __) => Text('$val${widget.suffix}',
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: _C.ink)),
                    ),
              const SizedBox(height: 2),
              Text(widget.label,
                  style: const TextStyle(
                      fontSize: 11.5,
                      color: _C.inkSoft,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Last session card
// ═══════════════════════════════════════════════════════════════════════════

class _LastSessionCard extends StatelessWidget {
  final String label;
  const _LastSessionCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_C.sky, Color(0xFF6FB3FF)]),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.access_time_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Last session',
                  style: TextStyle(fontSize: 11, color: _C.inkSoft)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Subject chip
// ═══════════════════════════════════════════════════════════════════════════

class _SubjectChip extends StatelessWidget {
  final String label;
  const _SubjectChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.white, _C.lightPink]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 1.4),
        boxShadow: [
          BoxShadow(
              color: _C.pink.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.menu_book_rounded, size: 15, color: _C.pink),
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: _C.ink)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Empty state
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final String emoji, text;
  const _EmptyState({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 34)),
        const SizedBox(height: 10),
        Text(text,
            style: const TextStyle(
                fontSize: 13, color: _C.inkSoft, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Session tile
// ═══════════════════════════════════════════════════════════════════════════

class _SessionTile extends StatelessWidget {
  final Map<String, dynamic> session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(session['scheduledAt'].toString())?.toLocal();
    final status = session['status'] as String;
    final statusColors = {
      'confirmed': [_C.mint, const Color(0xFF1FAE7C)],
      'completed': [_C.sky, const Color(0xFF3B82C4)],
      'cancelled': [_C.inkSoft.withValues(alpha: 0.3), _C.inkSoft],
      'pending': [_C.lightPink, _C.pink],
      'missed': [_C.cream, const Color(0xFFE8B84B)],
    }[status] ??
        [_C.inkSoft.withValues(alpha: 0.3), _C.inkSoft];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_C.lavender, Color(0xFFB794F6)]),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.calendar_today_rounded,
                    size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(session['teacherName'] ?? 'Teacher',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w800, color: _C.ink)),
              ),
              _GlowBadge(
                  label: status,
                  colors: [statusColors[0], statusColors[1]]),
            ]),
            const SizedBox(height: 10),
            if (dt != null)
              Text(
                  '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11.5, color: _C.inkSoft)),
            const SizedBox(height: 2),
            Text(
                '${session['durationMins']} min · ${session['creditsCost']} credits'
                '${session['pricingName'] != null ? ' · ${session['pricingName']}' : ''}',
                style: const TextStyle(fontSize: 11.5, color: _C.inkSoft)),
            if (session['teacherNotes'] != null) ...[
              const SizedBox(height: 8),
              Text('Note: ${session['teacherNotes']}',
                  style: const TextStyle(
                      fontSize: 11.5, color: _C.pink, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Timeline
// ═══════════════════════════════════════════════════════════════════════════

class _Timeline extends StatelessWidget {
  final List entries;
  const _Timeline({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(entries.length, (i) {
        final entry = entries[i] as Map<String, dynamic>;
        final dt = DateTime.tryParse(entry['at'].toString())?.toLocal();
        final isLast = i == entries.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [_C.pink, Color(0xFFFF6FAE)]),
                    boxShadow: [
                      BoxShadow(
                          color: _C.pink.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.4,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _C.pink.withValues(alpha: 0.5),
                            _C.lightPink.withValues(alpha: 0.2),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry['label'] ?? '',
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _C.ink)),
                        if (dt != null) ...[
                          const SizedBox(height: 3),
                          Text(
                              '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  fontSize: 10.5, color: _C.inkSoft)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Pill action buttons
// ═══════════════════════════════════════════════════════════════════════════

class _PillActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  const _PillActionButton({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_PillActionButton> createState() => _PillActionButtonState();
}

class _PillActionButtonState extends State<_PillActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 110),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: widget.colors),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: widget.colors.last.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, size: 16, color: Colors.white),
            const SizedBox(width: 7),
            Text(widget.label,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.white,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

class _FloatingPillButton extends StatelessWidget {
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _FloatingPillButton(
      {required this.label, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
                color: gradient.last.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Edit field (glass style input)
// ═══════════════════════════════════════════════════════════════════════════

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _EditField(this.label, this.controller);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: _C.ink, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: _C.inkSoft),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _C.lightPink.withValues(alpha: 0.6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _C.pink, width: 1.8),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Dialogs
// ═══════════════════════════════════════════════════════════════════════════

class _GlassDialog extends StatelessWidget {
  final String title;
  final String? body;
  final Widget? bodyWidget;
  final List<Widget> actions;
  const _GlassDialog({
    required this.title,
    this.body,
    this.bodyWidget,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: _C.ink)),
                const SizedBox(height: 12),
                if (bodyWidget != null) bodyWidget!,
                if (body != null)
                  Text(body!,
                      style: const TextStyle(
                          fontSize: 13, color: _C.inkSoft, height: 1.5)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions
                      .map((a) => Padding(
                          padding: const EdgeInsets.only(left: 8), child: a))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final Color? color;
  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.filled,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (!filled) {
      return TextButton(
        onPressed: onTap,
        child: Text(label, style: const TextStyle(color: _C.inkSoft)),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: color ?? _C.pink,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}