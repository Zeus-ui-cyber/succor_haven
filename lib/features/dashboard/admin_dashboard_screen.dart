// lib/features/dashboard/admin_dashboard_screen.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../auth/controllers/auth_controller.dart';
import '../auth/repositories/auth_repository.dart';

// ── Palette (kiddy / glowy — same family as student dashboard) ───────────────
class _C {
  static const sunshine = Color(0xFFFFC93C);
  static const sunshineDeep = Color(0xFFFFB100);
  static const sunshineGlow = Color(0xFFFFE49A);
  static const navy = Color(0xFF142850);
  static const navySoft = Color(0xFF274472);
  static const coral = Color(0xFFFF6F61);
  static const coralSoft = Color(0xFFFFD9CC);
  static const blushSoft = Color(0xFFFCE0E6);
  static const cream = Color(0xFFFFF8E7);
  static const paper = Color(0xFFFFFFFF);
  static const inkSoft = Color(0xFF6E7593);
  static const line = Color(0xFFFFE8B8);
  static const green = Color(0xFF00C48C);
  static const greenPale = Color(0xFFDFFBEF);
}

void _noop() {}

final _adminRepoProvider = Provider((_) => AuthRepository());

Future<Map<String, String>> _adminHeaders(AuthRepository repo) async {
  final token = await repo.getAccessToken();
  return {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

final _dashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(_adminRepoProvider);
  final headers = await _adminHeaders(repo);

  // No token at all = not logged in / token wiped. Fail with a clear reason
  // instead of letting the request go out unauthenticated and 401 silently.
  if (!headers.containsKey('Authorization')) {
    throw Exception(
        'Not signed in (no access token found). Please log in again.');
  }

  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/admin/dashboard'),
    headers: headers,
  );

  if (res.statusCode != 200) {
    // Surface the real server response so the UI/console show *why* it
    // failed (401 = bad/expired token, 403 = not admin, 500 = server bug,
    // etc.) instead of a generic, undiagnosable message.
    String detail = res.body;
    try {
      final parsed = jsonDecode(res.body);
      if (parsed is Map && parsed['error'] != null) {
        detail = parsed['error'].toString();
      }
    } catch (_) {
      // body wasn't JSON — keep raw text
    }
    throw Exception(
        'Failed to load dashboard (HTTP ${res.statusCode}): $detail');
  }

  return jsonDecode(res.body) as Map<String, dynamic>;
});

final _pendingTeachersProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(_adminRepoProvider);
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/admin/users?role=teacher'),
    headers: await _adminHeaders(repo),
  );
  if (res.statusCode != 200) return [];
  final all = jsonDecode(res.body) as List;
  return all.where((u) => u['teacher_approved'] == false).toList();
});

final _allTeachersProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(_adminRepoProvider);
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/admin/users?role=teacher'),
    headers: await _adminHeaders(repo),
  );
  if (res.statusCode != 200) return [];
  final all = jsonDecode(res.body) as List;
  return all.where((u) => u['teacher_approved'] == true).toList();
});

final _allUsersProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(_adminRepoProvider);
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/admin/users'),
    headers: await _adminHeaders(repo),
  );
  if (res.statusCode != 200) return [];
  return jsonDecode(res.body) as List;
});

// Bookings for a single teacher, used by the schedule manager.
final _teacherScheduleProvider =
    FutureProvider.family<List<dynamic>, String>((ref, teacherId) async {
  final repo = ref.read(_adminRepoProvider);
  final res = await http.get(
    Uri.parse(
        '${AuthRepository.baseUrl}/admin/teachers/$teacherId/bookings'),
    headers: await _adminHeaders(repo),
  );
  if (res.statusCode != 200) return [];
  return jsonDecode(res.body) as List;
});

// ═══════════════════════════════════════════════════════════════════════════════
class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.cream,
      body: SafeArea(
        child: Stack(children: [
          const _BackgroundBlobs(),
          IndexedStack(
            index: _navIndex,
            children: const [
              _OverviewTab(),
              _TeachersTab(),
              _PeopleTab(),
              _AdminProfileTab(),
            ],
          ),
        ]),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    const items = [
      (Icons.dashboard_rounded, Icons.dashboard_outlined, 'Overview', '概览'),
      (Icons.school_rounded, Icons.school_outlined, 'Teachers', '老师'),
      (
        Icons.diamond_rounded,
        Icons.diamond_outlined,
        'Credits',
        '积分管理'
      ),
      (Icons.person_rounded, Icons.person_outlined, 'Profile', '我'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _C.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: _C.sunshineDeep.withValues(alpha: 0.28),
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, -6))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final active = i == _navIndex;
              final item = items[i];
              return GestureDetector(
                onTap: () => setState(() => _navIndex = i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: active
                        ? const LinearGradient(
                            colors: [_C.sunshine, _C.coral],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: active
                        ? [
                            BoxShadow(
                                color: _C.coral.withValues(alpha: 0.45),
                                blurRadius: 14,
                                offset: const Offset(0, 4))
                          ]
                        : null,
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(active ? item.$1 : item.$2,
                        color: active ? Colors.white : _C.inkSoft, size: 22),
                    const SizedBox(height: 2),
                    Text(active ? item.$3 : item.$4,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : _C.inkSoft,
                        )),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Decorative background blobs (shared visual language with student app) ───
class _BackgroundBlobs extends StatelessWidget {
  const _BackgroundBlobs();
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(children: [
        Positioned(
            top: -60,
            right: -70,
            child: _glowCircle(180, _C.sunshineGlow.withValues(alpha: 0.55))),
        Positioned(
            top: 140,
            left: -80,
            child: _glowCircle(150, _C.blushSoft.withValues(alpha: 0.6))),
        Positioned(
            bottom: 80,
            right: -60,
            child: _glowCircle(140, _C.coralSoft.withValues(alpha: 0.5))),
      ]),
    );
  }

  Widget _glowCircle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      );
}

class _PageHeader extends StatelessWidget {
  final String en, zh, emoji;
  const _PageHeader(this.en, this.zh, this.emoji);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  const LinearGradient(colors: [_C.sunshine, _C.coral]),
              boxShadow: [
                BoxShadow(
                    color: _C.coral.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(en,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: _C.navy)),
            Text('· $zh',
                style: const TextStyle(
                    fontSize: 12, color: _C.coral, fontWeight: FontWeight.w700)),
          ]),
        ]),
      );
}

// ── OVERVIEW TAB ──────────────────────────────────────────────────────────────
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_dashboardProvider);

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _C.coral)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.coralSoft, width: 1.4),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('⚠️', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 10),
              const Text('Couldn\'t load dashboard',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _C.navy)),
              const SizedBox(height: 8),
              Text('$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: _C.inkSoft)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => ref.invalidate(_dashboardProvider),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_C.sunshine, _C.coral]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('Retry',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ),
        ),
      ),
      data: (data) {
        final userCounts = data['userCounts'] as List;
        final bookingCounts = data['bookingCounts'] as List;
        final revenue = (data['totalRevenueCents'] as num) / 100;
        final pending = data['pendingTeachers'] as int;

        int countByRole(String r) {
          try {
            return int.parse(
                userCounts.firstWhere((x) => x['role'] == r)['count']);
          } catch (_) {
            return 0;
          }
        }

        int countByStatus(String s) {
          try {
            return int.parse(
                bookingCounts.firstWhere((x) => x['status'] == s)['count']);
          } catch (_) {
            return 0;
          }
        }

        return CustomScrollView(slivers: [
          const SliverToBoxAdapter(
              child: _PageHeader('Admin Panel', '管理控制台', '🛠️')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverToBoxAdapter(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Revenue glow card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_C.navy, _C.navySoft],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                          color: _C.sunshineDeep.withValues(alpha: 0.35),
                          blurRadius: 24,
                          spreadRadius: -4,
                          offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Stack(children: [
                    const Positioned(
                      right: -10,
                      top: -10,
                      child: Opacity(
                        opacity: 0.18,
                        child: Icon(Icons.star_rounded,
                            size: 90, color: _C.sunshine),
                      ),
                    ),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Revenue · 总收入',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text('₱ ${revenue.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: _C.sunshine,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900)),
                        ]),
                  ]),
                ),
                const SizedBox(height: 20),

                if (pending > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFFD700)),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Row(children: [
                      const Text('⏳', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                        '$pending teacher${pending > 1 ? 's' : ''} pending approval',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7A5C00)),
                      )),
                    ]),
                  ),

                const Text('Users · 用户',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _C.navy)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _AdminStat('${countByRole('student')}',
                          'Students\n学生', _C.coral, _C.coralSoft)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _AdminStat('${countByRole('teacher')}',
                          'Teachers\n老师', _C.navy, _C.sunshineGlow)),
                ]),
                const SizedBox(height: 20),

                const Text('Bookings · 预约',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _C.navy)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _AdminStat('${countByStatus('confirmed')}',
                          'Active\n进行中', _C.green, _C.greenPale)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _AdminStat('${countByStatus('completed')}',
                          'Done\n已完成', _C.navySoft, _C.sunshineGlow)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _AdminStat('${countByStatus('cancelled')}',
                          'Cancelled\n已取消', _C.inkSoft, _C.blushSoft)),
                ]),
              ]),
            ),
          ),
        ]);
      },
    );
  }
}

// ── TEACHERS TAB — approve teachers + open their schedule manager ───────────
class _TeachersTab extends ConsumerStatefulWidget {
  const _TeachersTab();
  @override
  ConsumerState<_TeachersTab> createState() => _TeachersTabState();
}

class _TeachersTabState extends ConsumerState<_TeachersTab> {
  bool _showPending = true;

  Future<void> _approve(BuildContext ctx, WidgetRef ref, String userId) async {
    final repo = ref.read(_adminRepoProvider);
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/admin/teachers/$userId/approve'),
      headers: await _adminHeaders(repo),
    );
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(res.statusCode == 200 ? 'Teacher approved ✓' : 'Failed'),
        backgroundColor: res.statusCode == 200 ? _C.green : _C.coral,
      ));
      if (res.statusCode == 200) {
        ref.invalidate(_pendingTeachersProvider);
        ref.invalidate(_allTeachersProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(_pendingTeachersProvider);
    final approvedAsync = ref.watch(_allTeachersProvider);

    return Column(children: [
      const _PageHeader('Teachers', '老师管理', '🍎'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Expanded(
              child: _ToggleChip(
                  label: 'Pending · 待审核',
                  active: _showPending,
                  onTap: () => setState(() => _showPending = true))),
          const SizedBox(width: 8),
          Expanded(
              child: _ToggleChip(
                  label: 'Approved · 已审核',
                  active: !_showPending,
                  onTap: () => setState(() => _showPending = false))),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: _showPending
            ? pendingAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: _C.coral)),
                error: (e, _) => Center(child: Text('$e')),
                data: (teachers) {
                  if (teachers.isEmpty) {
                    return const _NiceEmpty(
                        emoji: '✅',
                        title: 'All teachers approved!',
                        titleCn: '所有老师已审核');
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    itemCount: teachers.length,
                    itemBuilder: (_, i) => _PendingTeacherCard(
                      teacher: teachers[i],
                      onApprove: () =>
                          _approve(context, ref, teachers[i]['id']),
                    ),
                  );
                },
              )
            : approvedAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: _C.coral)),
                error: (e, _) => Center(child: Text('$e')),
                data: (teachers) {
                  if (teachers.isEmpty) {
                    return const _NiceEmpty(
                        emoji: '🍃',
                        title: 'No approved teachers yet',
                        titleCn: '暂无已审核老师');
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    itemCount: teachers.length,
                    itemBuilder: (_, i) => _ApprovedTeacherCard(
                      teacher: teachers[i],
                      onManageSchedule: () => _openScheduleSheet(
                          context, teachers[i]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  void _openScheduleSheet(BuildContext context, Map teacher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TeacherScheduleSheet(teacher: teacher),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleChip(
      {required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(colors: [_C.sunshine, _C.coral])
                : null,
            color: active ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? Colors.transparent : _C.line),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: _C.coral.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]
                : null,
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : _C.inkSoft)),
        ),
      );
}

class _PendingTeacherCard extends StatelessWidget {
  final Map teacher;
  final VoidCallback onApprove;
  const _PendingTeacherCard(
      {required this.teacher, required this.onApprove});
  @override
  Widget build(BuildContext context) {
    final t = teacher;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.line, width: 1.4),
        boxShadow: [
          BoxShadow(
              color: _C.sunshineDeep.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: _C.sunshineGlow,
          child: Text('${t['first_name'][0]}${t['last_name'][0]}',
              style: const TextStyle(
                  color: _C.navy, fontWeight: FontWeight.w900, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${t['first_name']} ${t['last_name']}',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: _C.navy)),
          Text(t['email'] ?? t['phone'] ?? '',
              style: const TextStyle(fontSize: 12, color: _C.inkSoft)),
          const Text('Pending approval · 待审核',
              style: TextStyle(
                  fontSize: 11, color: _C.coral, fontWeight: FontWeight.w700)),
        ])),
        GestureDetector(
          onTap: onApprove,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _C.green,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: _C.green.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: const Text('Approve',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }
}

class _ApprovedTeacherCard extends StatelessWidget {
  final Map teacher;
  final VoidCallback onManageSchedule;
  const _ApprovedTeacherCard(
      {required this.teacher, required this.onManageSchedule});
  @override
  Widget build(BuildContext context) {
    final t = teacher;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.line, width: 1.4),
        boxShadow: [
          BoxShadow(
              color: _C.sunshineDeep.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: _C.sunshineGlow,
          child: Text('${t['first_name'][0]}${t['last_name'][0]}',
              style: const TextStyle(
                  color: _C.navy, fontWeight: FontWeight.w900, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${t['first_name']} ${t['last_name']}',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: _C.navy)),
          Text(t['email'] ?? t['phone'] ?? '',
              style: const TextStyle(fontSize: 12, color: _C.inkSoft)),
        ])),
        GestureDetector(
          onTap: onManageSchedule,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_C.sunshine, _C.coral]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: _C.coral.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_month_rounded, color: Colors.white, size: 14),
              SizedBox(width: 5),
              Text('Schedule',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Teacher schedule manager (bottom sheet) ──────────────────────────────────
// Lets admin view a teacher's booked sessions and cancel / reassign credits
// for a booking — i.e. the admin is "responsible to give a schedule" by being
// able to inspect, cancel, or push back any session on a teacher's calendar.
class _TeacherScheduleSheet extends ConsumerWidget {
  final Map teacher;
  const _TeacherScheduleSheet({required this.teacher});

  Future<void> _cancelBooking(
      BuildContext ctx, WidgetRef ref, String bookingId) async {
    final repo = ref.read(_adminRepoProvider);
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/admin/bookings/$bookingId/cancel'),
      headers: await _adminHeaders(repo),
    );
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content:
            Text(res.statusCode == 200 ? 'Session cancelled' : 'Failed'),
        backgroundColor: res.statusCode == 200 ? _C.green : _C.coral,
      ));
      if (res.statusCode == 200) {
        ref.invalidate(_teacherScheduleProvider(teacher['id']));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync =
        ref.watch(_teacherScheduleProvider(teacher['id'] as String));
    final name = '${teacher['first_name']} ${teacher['last_name']}';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _C.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                  color: _C.line, borderRadius: BorderRadius.circular(10))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              CircleAvatar(
                  radius: 18,
                  backgroundColor: _C.sunshineGlow,
                  child: Text(name[0],
                      style: const TextStyle(
                          color: _C.navy, fontWeight: FontWeight.w900))),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: _C.navy)),
                    const Text('Schedule · 课程安排',
                        style: TextStyle(fontSize: 11, color: _C.coral)),
                  ])),
            ]),
          ),
          const Divider(color: _C.line, height: 1),
          Expanded(
            child: scheduleAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: _C.coral)),
              error: (e, _) => Center(child: Text('$e')),
              data: (bookings) {
                if (bookings.isEmpty) {
                  return const _NiceEmpty(
                      emoji: '🗓️',
                      title: 'No sessions scheduled',
                      titleCn: '暂无排课');
                }
                final sorted = [...bookings]..sort((a, b) =>
                    DateTime.parse(a['scheduled_at'])
                        .compareTo(DateTime.parse(b['scheduled_at'])));
                return ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  itemCount: sorted.length,
                  itemBuilder: (_, i) {
                    final b = sorted[i];
                    final dt = DateTime.parse(b['scheduled_at']).toLocal();
                    final studentName =
                        '${b['student_first'] ?? ''} ${b['student_last'] ?? ''}';
                    final status = b['status'] as String;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _C.line, width: 1.4),
                      ),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                              Text(studentName.trim().isEmpty
                                  ? 'Student'
                                  : studentName,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _C.navy)),
                              const SizedBox(height: 2),
                              Text(
                                  '${dt.day}/${dt.month}/${dt.year}  '
                                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                      fontSize: 11, color: _C.inkSoft)),
                              Text('${b['credits_cost']} credits',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: _C.coral,
                                      fontWeight: FontWeight.w700)),
                            ])),
                        if (status == 'confirmed' || status == 'pending')
                          GestureDetector(
                            onTap: () =>
                                _cancelBooking(context, ref, b['id']),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: _C.coralSoft,
                                  borderRadius: BorderRadius.circular(14)),
                              child: const Text('Cancel',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _C.coral,
                                      fontWeight: FontWeight.w800)),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: (status == 'completed'
                                        ? _C.green
                                        : _C.inkSoft)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(status,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: status == 'completed'
                                        ? _C.green
                                        : _C.inkSoft,
                                    fontWeight: FontWeight.w800)),
                          ),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── PEOPLE TAB — manage every user + open/manipulate credits & points ───────
class _PeopleTab extends ConsumerStatefulWidget {
  const _PeopleTab();
  @override
  ConsumerState<_PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends ConsumerState<_PeopleTab> {
  final _search = TextEditingController();
  String _roleFilter = 'All';

  Future<void> _toggleActive(
      BuildContext ctx, WidgetRef ref, String userId) async {
    final repo = ref.read(_adminRepoProvider);
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/admin/users/$userId/toggle'),
      headers: await _adminHeaders(repo),
    );
    if (ctx.mounted) {
      final active = jsonDecode(res.body)['isActive'] as bool?;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(active == true ? 'User activated' : 'User deactivated'),
        backgroundColor: active == true ? _C.green : _C.coral,
      ));
      ref.invalidate(_allUsersProvider);
    }
  }

  void _openCreditsSheet(BuildContext context, Map user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreditsPointsSheet(user: user),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_allUsersProvider);

    return Column(children: [
      const _PageHeader('Credits & Points', '积分管理', '💎'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search students or teachers...',
            prefixIcon: const Icon(Icons.search, color: _C.inkSoft, size: 20),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _C.line, width: 1.4)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _C.line, width: 1.4)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _C.coral, width: 1.6)),
          ),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: ['All', 'student', 'teacher', 'admin']
              .map((r) => GestureDetector(
                    onTap: () => setState(() => _roleFilter = r),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: _roleFilter == r
                            ? const LinearGradient(
                                colors: [_C.sunshine, _C.coral])
                            : null,
                        color: _roleFilter == r ? null : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _roleFilter == r
                                ? Colors.transparent
                                : _C.line),
                      ),
                      child: Text(r == 'All' ? 'All · 全部' : r,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _roleFilter == r
                                  ? Colors.white
                                  : _C.inkSoft)),
                    ),
                  ))
              .toList(),
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: usersAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _C.coral)),
          error: (e, _) => Center(child: Text('$e')),
          data: (users) {
            final q = _search.text.toLowerCase();
            final filtered = users.where((u) {
              final name = '${u['first_name']} ${u['last_name']}'.toLowerCase();
              final matchSearch = q.isEmpty || name.contains(q);
              final matchRole =
                  _roleFilter == 'All' || u['role'] == _roleFilter;
              return matchSearch && matchRole;
            }).toList();

            if (filtered.isEmpty) {
              return const _NiceEmpty(
                  emoji: '🔍', title: 'No users found', titleCn: '未找到用户');
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final u = filtered[i];
                return _UserCreditsCard(
                  user: u,
                  onToggleActive: () => _toggleActive(context, ref, u['id']),
                  onManageCredits: () => _openCreditsSheet(context, u),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

class _UserCreditsCard extends StatelessWidget {
  final Map user;
  final VoidCallback onToggleActive;
  final VoidCallback onManageCredits;
  const _UserCreditsCard(
      {required this.user,
      required this.onToggleActive,
      required this.onManageCredits});

  @override
  Widget build(BuildContext context) {
    final u = user;
    final role = u['role'] as String;
    final active = u['is_active'] as bool? ?? true;
    final roleColor = role == 'student'
        ? _C.coral
        : role == 'teacher'
            ? _C.navy
            : _C.navySoft;
    final credits = u['credits'] ?? 0;
    final points = u['points'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? Colors.white : _C.blushSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.line, width: 1.4),
        boxShadow: [
          BoxShadow(
              color: _C.sunshineDeep.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: roleColor.withValues(alpha: 0.15),
            child: Text(u['first_name'][0],
                style: TextStyle(color: roleColor, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${u['first_name']} ${u['last_name']}',
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _C.navy)),
            Text(u['email'] ?? u['phone'] ?? '',
                style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Text(role,
                style: TextStyle(
                    fontSize: 10,
                    color: roleColor,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 6),
          if (role != 'admin')
            GestureDetector(
              onTap: onToggleActive,
              child: Icon(
                active ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                color: active ? _C.green : _C.inkSoft,
                size: 32,
              ),
            ),
        ]),
        if (role != 'admin') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                    color: _C.sunshineGlow.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.diamond_rounded, size: 14, color: _C.navy),
                  const SizedBox(width: 6),
                  Text('$credits credits',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _C.navy)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                    color: _C.coralSoft,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.emoji_events_rounded,
                      size: 14, color: _C.coral),
                  const SizedBox(width: 6),
                  Text('$points pts',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _C.coral)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onManageCredits,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(colors: [_C.sunshine, _C.coral]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: _C.coral.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child:
                    const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ── Credits / points editor sheet ────────────────────────────────────────────
// This is where the admin "opens and manipulates" a user's credit & point
// balances — adjust up or down, with a reason, applied via the admin API.
class _CreditsPointsSheet extends ConsumerStatefulWidget {
  final Map user;
  const _CreditsPointsSheet({required this.user});
  @override
  ConsumerState<_CreditsPointsSheet> createState() =>
      _CreditsPointsSheetState();
}

class _CreditsPointsSheetState extends ConsumerState<_CreditsPointsSheet> {
  final _creditsCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _creditsCtrl.dispose();
    _pointsCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _apply(int sign) async {
    final creditsDelta = int.tryParse(_creditsCtrl.text) ?? 0;
    final pointsDelta = int.tryParse(_pointsCtrl.text) ?? 0;
    if (creditsDelta == 0 && pointsDelta == 0) return;

    setState(() => _saving = true);
    final repo = ref.read(_adminRepoProvider);
    final headers = await _adminHeaders(repo);
    final userId = widget.user['id'];

    try {
      if (creditsDelta != 0) {
        await http.patch(
          Uri.parse('${AuthRepository.baseUrl}/admin/users/$userId/credits'),
          headers: headers,
          body: jsonEncode({
            'amount': creditsDelta * sign,
            'reason': _reasonCtrl.text,
          }),
        );
      }
      if (pointsDelta != 0) {
        await http.patch(
          Uri.parse('${AuthRepository.baseUrl}/admin/users/$userId/points'),
          headers: headers,
          body: jsonEncode({
            'amount': pointsDelta * sign,
            'reason': _reasonCtrl.text,
          }),
        );
      }
      ref.invalidate(_allUsersProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Balance updated ✓'),
          backgroundColor: _C.green,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update balance'),
          backgroundColor: _C.coral,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final name = '${u['first_name']} ${u['last_name']}';

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        decoration: const BoxDecoration(
          color: _C.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                      color: _C.line, borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Text('💎', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Adjust $name\'s balance',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _C.navy))),
            ]),
            const Text('调整积分余额',
                style: TextStyle(fontSize: 12, color: _C.coral)),
            const SizedBox(height: 18),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _C.sunshineGlow.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('Current: ${u['credits'] ?? 0} credits',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _C.navy)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _C.coralSoft,
                    borderRadius: BorderRadius.circular(10)),
                child: Text('${u['points'] ?? 0} pts',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _C.coral)),
              ),
            ]),
            const SizedBox(height: 18),
            _GlowField(
                controller: _creditsCtrl,
                label: 'Credits amount',
                icon: Icons.diamond_rounded),
            const SizedBox(height: 12),
            _GlowField(
                controller: _pointsCtrl,
                label: 'Points amount',
                icon: Icons.emoji_events_rounded),
            const SizedBox(height: 12),
            _GlowField(
                controller: _reasonCtrl,
                label: 'Reason (optional) · 备注',
                icon: Icons.edit_note_rounded),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: _ActionButton(
                  label: 'Deduct · 扣除',
                  colors: const [Color(0xFFFF8A75), _C.coral],
                  icon: Icons.remove_circle_outline,
                  onTap: _saving ? null : () => _apply(-1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'Add · 增加',
                  colors: const [_C.sunshine, _C.sunshineDeep],
                  icon: Icons.add_circle_outline,
                  onTap: _saving ? null : () => _apply(1),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _GlowField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  const _GlowField(
      {required this.controller, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: label.startsWith('Reason')
            ? TextInputType.text
            : TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _C.coral, size: 18),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _C.line, width: 1.4)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _C.line, width: 1.4)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _C.coral, width: 1.6)),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final IconData icon;
  final VoidCallback? onTap;
  const _ActionButton(
      {required this.label,
      required this.colors,
      required this.icon,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: colors.last.withValues(alpha: 0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

// ── ADMIN PROFILE TAB ────────────────────────────────────────────────────────
class _AdminProfileTab extends ConsumerWidget {
  const _AdminProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Center(
            child: Column(children: [
          const _AdminMascot(),
          const SizedBox(height: 14),
          const Text('Admin',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: _C.navy)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
                gradient:
                    const LinearGradient(colors: [_C.sunshine, _C.coral]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: _C.coral.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ]),
            child: const Text('管理员 · Admin',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w800)),
          ),
        ])),
        const SizedBox(height: 28),
        const _TProfileSection('Controls', '管理功能', [
          _TProfileTile(Icons.diamond_rounded, 'Credit & Point Rules', '积分规则',
              _noop),
          _TProfileTile(
              Icons.emoji_events_rounded, 'Milestone Rewards', '里程碑奖励', _noop),
          _TProfileTile(
              Icons.price_change_rounded, 'Session Pricing', '课程定价', _noop),
        ]),
        const SizedBox(height: 16),
        const _TProfileSection('Account', '账户', [
          _TProfileTile(Icons.lock_outline, 'Change Password', '修改密码', _noop),
          _TProfileTile(
              Icons.notifications_outlined, 'Notifications', '通知', _noop),
        ]),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).logout();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Sign Out · 退出登录'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _C.coral,
            side: const BorderSide(color: _C.coral, width: 1.6),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ],
    );
  }
}

class _AdminMascot extends StatefulWidget {
  const _AdminMascot();
  @override
  State<_AdminMascot> createState() => _AdminMascotState();
}

class _AdminMascotState extends State<_AdminMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final bob = math.sin(_ctrl.value * math.pi) * -4;
        return Transform.translate(
          offset: Offset(0, bob),
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [_C.navy, _C.navySoft],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              boxShadow: [
                BoxShadow(
                    color: _C.sunshineDeep.withValues(alpha: 0.5),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 6)),
              ],
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Center(child: Text('🛠️', style: TextStyle(fontSize: 36))),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _AdminStat extends StatelessWidget {
  final String value, label;
  final Color color, pale;
  const _AdminStat(this.value, this.label, this.color, this.pale);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: pale,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.16),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900, color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: _C.inkSoft,
                fontWeight: FontWeight.w700,
                height: 1.4)),
      ]),
    );
  }
}

class _NiceEmpty extends StatelessWidget {
  final String emoji, title, titleCn;
  const _NiceEmpty(
      {required this.emoji, required this.title, required this.titleCn});
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
              color: _C.sunshineGlow.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _C.line, width: 1.4)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _C.navy)),
            Text('· $titleCn',
                style: const TextStyle(fontSize: 12, color: _C.coral)),
          ]),
        ),
      );
}

class _TProfileSection extends StatelessWidget {
  final String en, zh;
  final List<Widget> tiles;
  const _TProfileSection(this.en, this.zh, this.tiles);
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Text(en,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _C.inkSoft)),
              const SizedBox(width: 5),
              Text('· $zh',
                  style: const TextStyle(fontSize: 12, color: _C.coral)),
            ]),
          ),
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.line, width: 1.4),
                boxShadow: [
                  BoxShadow(
                      color: _C.sunshineDeep.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ]),
            child: Column(children: tiles),
          ),
        ],
      );
}

class _TProfileTile extends StatelessWidget {
  final IconData icon;
  final String label, labelCn;
  final VoidCallback onTap;
  const _TProfileTile(this.icon, this.label, this.labelCn, this.onTap);
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Icon(icon, color: _C.coral, size: 20),
        title: Text('$label · $labelCn',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: _C.navy)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 13, color: _C.inkSoft),
        dense: true,
      );
}