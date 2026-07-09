// lib/features/dashboard/admin/student_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../auth/repositories/auth_repository.dart';

class _C {
  static const burgundy = Color(0xFF7D002B);
  static const magenta = Color(0xFFD64577);
  static const blushPink = Color(0xFFF2C6D6);
  static const softPink = Color(0xFFF9E1EA);
  static const slateBlue = Color(0xFF3E678A);
  static const cream = Color(0xFFFFF5F7);
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
  static const line = Color(0xFFF0DCE5);
  static const paper = Color(0xFFFFFFFF);
  static const green = Color(0xFF00C48C);
  static const amber = Color(0xFFB8860B);
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
      backgroundColor: active == true ? _C.green : _C.burgundy,
    ));
    ref.invalidate(studentDetailProvider(studentId));
  }

  Future<void> _resetPassword(BuildContext ctx, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: const Text('Reset Password?'),
        content: const Text(
            'This will generate a new temporary password for this student. Share it with them securely.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Reset', style: TextStyle(color: _C.burgundy))),
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
        builder: (dctx) => AlertDialog(
          title: const Text('Temporary Password'),
          content: SelectableText(
            tempPassword,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: _C.burgundy),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Done')),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('Failed to reset password'), backgroundColor: _C.burgundy));
    }
  }

  Future<void> _deleteStudent(BuildContext ctx, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: const Text('Delete Student?'),
        content: const Text(
            'This permanently deletes the account. This cannot be undone. Students with booking history cannot be deleted — deactivate instead.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Delete', style: TextStyle(color: _C.burgundy))),
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
      Navigator.pop(ctx, true); // pop back to list
    } else {
      final err = jsonDecode(res.body)['error'] ?? 'Delete failed';
      ScaffoldMessenger.of(ctx)
          .showSnackBar(SnackBar(content: Text(err), backgroundColor: _C.burgundy));
    }
  }

  // ⚠️ FIXED: TextEditingController(text: ...) requires a non-null String.
  // profile['course'] / profile['year_level'] (and potentially others) can
  // be null for a student who hasn't been assigned one — this was throwing
  // "type 'Null' is not a subtype of type 'String'" the moment Edit Info
  // was tapped on any such student. Every field now coerces null to ''.
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
      backgroundColor: _C.cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit Student',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: _C.ink)),
                const SizedBox(height: 16),
                _EditField('First Name', firstNameCtrl),
                _EditField('Last Name', lastNameCtrl),
                _EditField('Email', emailCtrl),
                _EditField('Phone', phoneCtrl),
                _EditField('Course', courseCtrl),
                _EditField('Year Level', yearLevelCtrl),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.burgundy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(sheetCtx, true),
                    child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ]),
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
      ScaffoldMessenger.of(ctx)
          .showSnackBar(const SnackBar(content: Text('Student updated'), backgroundColor: _C.green));
    } else {
      final err = jsonDecode(res.body)['error'] ?? 'Update failed';
      ScaffoldMessenger.of(ctx)
          .showSnackBar(SnackBar(content: Text(err), backgroundColor: _C.burgundy));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentDetailProvider(studentId));

    return Scaffold(
      backgroundColor: _C.cream,
      appBar: AppBar(
        backgroundColor: _C.cream,
        elevation: 0,
        foregroundColor: _C.ink,
        title: const Text('Student Profile'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _C.burgundy)),
        error: (e, _) => Center(child: Text('$e')),
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
          final avatarUrl = _resolveAvatarUrl(profile['avatar_url'] as String?);
          final course = profile['course']?.toString() ?? '';
          final yearLevel = profile['year_level']?.toString() ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Header card ────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _C.paper,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _C.line),
                ),
                child: Column(children: [
                  _Avatar(
                    avatarUrl: avatarUrl,
                    initials: _initials(firstName, lastName),
                    radius: 36,
                    fontSize: 24,
                  ),
                  const SizedBox(height: 12),
                  Text(displayName.isEmpty ? 'Unnamed' : displayName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: _C.ink)),
                  Text('ID: ${profile['id']}',
                      style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
                    _Badge(active ? 'Active' : 'Inactive', active ? _C.green : _C.inkSoft),
                    _Badge(
                        profile['phone_verified'] == true ? 'Verified' : 'Unverified',
                        profile['phone_verified'] == true ? _C.slateBlue : _C.amber),
                    if (course.isNotEmpty) _Badge(course, _C.magenta),
                    if (yearLevel.isNotEmpty) _Badge(yearLevel, _C.burgundy),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Contact info ───────────────────────────────────────────
              _SectionCard('Contact Information · 联系信息', [
                _InfoRow('Email', profile['email'] ?? '-'),
                _InfoRow('Contact Number', profile['phone'] ?? '-'),
                _InfoRow('Date Registered', _formatDate(profile['created_at'])),
              ]),
              const SizedBox(height: 16),

              // ── Progress summary ───────────────────────────────────────
              const Text('Progress Summary · 进度总览',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _StatCard('${progress['totalSessionsCompleted']}', 'Completed',
                        _C.green, const Color(0xFFDCF7EE))),
                const SizedBox(width: 8),
                Expanded(
                    child: _StatCard('${progress['totalBookings']}', 'Bookings', _C.slateBlue,
                        const Color(0xFFDCEBF5))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _StatCard(
                        '${progress['subjectsCompleted']}', 'Subjects', _C.magenta, _C.blushPink)),
                const SizedBox(width: 8),
                Expanded(
                    child: _StatCard(
                        progress['attendanceRate'] != null ? '${progress['attendanceRate']}%' : '—',
                        'Attendance',
                        _C.burgundy,
                        _C.softPink)),
              ]),
              const SizedBox(height: 6),
              Text('Last session: ${_formatDate(progress['lastSessionDate'])}',
                  style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
              const SizedBox(height: 20),

              // ── Taken subjects ──────────────────────────────────────────
              const Text('Taken Subjects · 已修科目',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink)),
              const SizedBox(height: 10),
              takenSubjects.isEmpty
                  ? const Text('No subjects yet', style: TextStyle(fontSize: 12, color: _C.inkSoft))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: takenSubjects
                          .map((s) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color: _C.softPink, borderRadius: BorderRadius.circular(20)),
                                child: Text('$s',
                                    style: const TextStyle(fontSize: 12, color: _C.burgundy)),
                              ))
                          .toList(),
                    ),
              const SizedBox(height: 20),

              // ── Session history ─────────────────────────────────────────
              const Text('Session History · 课程记录',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink)),
              const SizedBox(height: 10),
              sessions.isEmpty
                  ? const Text('No sessions yet', style: TextStyle(fontSize: 12, color: _C.inkSoft))
                  : Column(children: sessions.map((s) => _SessionTile(session: s)).toList()),
              const SizedBox(height: 20),

              // ── Activity timeline ────────────────────────────────────────
              const Text('Activity Timeline · 活动记录',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink)),
              const SizedBox(height: 10),
              Column(children: timeline.map((t) => _TimelineTile(entry: t)).toList()),
              const SizedBox(height: 24),

              // ── Actions ───────────────────────────────────────────────────
              const Text('Manage Account · 管理账户',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink)),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _ActionButton(
                    label: 'Edit Info',
                    icon: Icons.edit_outlined,
                    color: _C.slateBlue,
                    onTap: () => _openEditSheet(context, ref, profile)),
                _ActionButton(
                    label: active ? 'Deactivate' : 'Activate',
                    icon: active ? Icons.toggle_off_outlined : Icons.toggle_on_outlined,
                    color: active ? _C.inkSoft : _C.green,
                    onTap: () => _toggleActive(context, ref)),
                _ActionButton(
                    label: 'Reset Password',
                    icon: Icons.lock_reset_outlined,
                    color: _C.amber,
                    onTap: () => _resetPassword(context, ref)),
                _ActionButton(
                    label: 'Delete Account',
                    icon: Icons.delete_outline,
                    color: _C.burgundy,
                    onTap: () => _deleteStudent(context, ref)),
              ]),
            ]),
          );
        },
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

// ── Shared small widgets ────────────────────────────────────────────────────

// Falls back to initials if avatarUrl is null OR fails to load. Mirrors
// the widget in students_list_screen.dart, parameterized for radius/font
// size since this screen shows a larger avatar than the list rows.
class _Avatar extends StatefulWidget {
  final String? avatarUrl;
  final String initials;
  final double radius;
  final double fontSize;
  const _Avatar({
    required this.avatarUrl,
    required this.initials,
    this.radius = 22,
    this.fontSize = 13,
  });

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> {
  bool _failed = false;

  @override
  void didUpdateWidget(covariant _Avatar old) {
    super.didUpdateWidget(old);
    if (old.avatarUrl != widget.avatarUrl) _failed = false;
  }

  @override
  Widget build(BuildContext context) {
    final showImage = widget.avatarUrl != null && !_failed;
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: _C.blushPink,
      backgroundImage: showImage ? NetworkImage(widget.avatarUrl!) : null,
      onBackgroundImageError: showImage
          ? (_, __) {
              if (mounted) setState(() => _failed = true);
            }
          : null,
      child: showImage
          ? null
          : Text(widget.initials,
              style: TextStyle(
                  fontSize: widget.fontSize,
                  color: _C.burgundy,
                  fontWeight: FontWeight.w800)),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard(this.title, this.children);
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: _C.paper, borderRadius: BorderRadius.circular(18), border: Border.all(color: _C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _C.ink)),
          const SizedBox(height: 10),
          ...children,
        ]),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontSize: 12, color: _C.inkSoft))),
          Expanded(
              flex: 3,
              child: Text(value,
                  style: const TextStyle(fontSize: 12, color: _C.ink, fontWeight: FontWeight.w600))),
        ]),
      );
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color color, pale;
  const _StatCard(this.value, this.label, this.color, this.pale);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(color: pale, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: _C.inkSoft, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _SessionTile extends StatelessWidget {
  final Map<String, dynamic> session;
  const _SessionTile({required this.session});
  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(session['scheduledAt'].toString())?.toLocal();
    final status = session['status'] as String;
    final statusColor = {
          'confirmed': _C.green,
          'completed': _C.slateBlue,
          'cancelled': _C.inkSoft,
          'pending': _C.magenta,
          'missed': _C.amber,
        }[status] ??
        _C.inkSoft;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration:
          BoxDecoration(color: _C.paper, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(session['teacherName'] ?? 'Teacher',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.ink))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration:
                BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Text(status,
                style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        if (dt != null)
          Text(
              '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
        Text(
            '${session['durationMins']} min · ${session['creditsCost']} credits'
            '${session['pricingName'] != null ? ' · ${session['pricingName']}' : ''}',
            style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
        // Teacher's remarks — not available until bookings.teacher_notes exists.
        if (session['teacherNotes'] != null) ...[
          const SizedBox(height: 6),
          Text('Note: ${session['teacherNotes']}',
              style: const TextStyle(fontSize: 11, color: _C.burgundy, fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _TimelineTile({required this.entry});
  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(entry['at'].toString())?.toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: _C.magenta, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry['label'] ?? '',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.ink)),
          if (dt != null)
            Text('${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 10, color: _C.inkSoft)),
        ])),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.label, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      );
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _EditField(this.label, this.controller);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: _C.paper,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
}