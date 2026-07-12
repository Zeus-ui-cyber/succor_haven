// lib/features/dashboard/admin_dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import '../auth/controllers/auth_controller.dart';
import '../auth/repositories/auth_repository.dart';
import '../../models/user.dart';
import 'admin/create_teacher_account_screen.dart';
import 'admin/students_list_screen.dart';
import 'admin/announcements_screen.dart';
import '../modules/screens/modules_screen.dart';

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
  static const purple = Color(0xFF8E5FD6);
}

// Backend now returns a single computed `full_name` field (first + last
// concatenated server-side), not separate first_name/last_name — see
// admin.controller.js listUsers(). This derives initials safely from that,
// handling null, empty, and single-word names instead of assuming exactly
// two parts always exist.
String _initials(String? fullName) {
  if (fullName == null || fullName.trim().isEmpty) return '?';
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

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
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/admin/dashboard'),
    headers: await _adminHeaders(repo),
  );
  if (res.statusCode != 200) {
    throw Exception(
        'Failed to load dashboard (${res.statusCode}): ${res.body}');
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

final _allUsersProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(_adminRepoProvider);
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/admin/users'),
    headers: await _adminHeaders(repo),
  );
  if (res.statusCode != 200) return [];
  return jsonDecode(res.body) as List;
});

// Needed so ModulesScreen (shared with the teacher dashboard) has a
// UserModel to check role/id against for edit/delete permissions. The
// admin dashboard didn't previously fetch its own "me" profile anywhere
// else — every other provider here works off raw Map data from /admin/*
// endpoints, not the authenticated admin's own record.
final _adminMeProvider =
    FutureProvider<UserModel>((ref) => ref.read(_adminRepoProvider).getMe());

// ═══════════════════════════════════════════════════════════════════════════════
class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.cream,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              color: _C.cream,
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _C.blushPink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.admin_panel_settings_outlined,
                      color: _C.burgundy, size: 20),
                ),
                const SizedBox(width: 10),
                const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin Panel',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _C.ink)),
                      Text('管理控制台',
                          style: TextStyle(fontSize: 11, color: _C.burgundy)),
                    ]),
                const Spacer(),
                Consumer(
                    builder: (_, ref, __) => IconButton(
                          icon: const Icon(Icons.logout_rounded,
                              color: _C.inkSoft),
                          onPressed: () async {
                            await ref
                                .read(authControllerProvider.notifier)
                                .logout();
                            if (context.mounted) {
                              Navigator.pushReplacementNamed(context, '/login');
                            }
                          },
                        )),
              ]),
            ),

            // ── Tabs ─────────────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: _C.softPink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicator: BoxDecoration(
                  color: _C.burgundy,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: _C.inkSoft,
                labelStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Teachers'),
                  Tab(text: 'Users'),
                  Tab(text: 'Students'),
                  Tab(text: 'Modules'),
                  Tab(text: 'Announcements'),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // ── Tab views ─────────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [
                  _OverviewTab(),
                  _TeachersTab(),
                  _UsersTab(),
                  StudentsListScreen(asTab: true),
                  _ModulesTab(),
                  AnnouncementsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modules tab ───────────────────────────────────────────────────────────────
// Wraps the shared ModulesScreen (also used on the teacher dashboard) once
// the admin's own UserModel is available — needed so the screen can decide
// per-module whether Edit/Delete should show (admin: always; teacher: own
// uploads only — enforced identically server-side in modules.controller.js).
// ModulesScreen renders its own Scaffold/AppBar, so it's embedded here
// without an extra wrapping Scaffold to avoid a nested-app-bar look.
class _ModulesTab extends ConsumerWidget {
  const _ModulesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(_adminMeProvider);
    return meAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _C.burgundy)),
      error: (e, _) => Center(child: Text('$e')),
      data: (user) => ModulesScreen(currentUser: user),
    );
  }
}

// ── Overview tab ──────────────────────────────────────────────────────────────
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_dashboardProvider);

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _C.burgundy)),
      error: (e, _) => Center(child: Text('$e')),
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

        final students = countByRole('student');
        final teachers = countByRole('teacher');
        final totalUsers = students + teachers + countByRole('admin');
        final active = countByStatus('confirmed');
        final completed = countByStatus('completed');
        final cancelled = countByStatus('cancelled');

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Revenue hero card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_C.burgundy, _C.magenta],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _C.burgundy.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.payments_rounded,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      const Text('Total Revenue · 总收入',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 10),
                    Text('₱ ${revenue.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900)),
                  ]),
            ),
            const SizedBox(height: 20),

            // Pending approval banner
            if (pending > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFD700)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFB8860B), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                    '$pending teacher${pending > 1 ? 's' : ''} pending approval',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7A5C00)),
                  )),
                ]),
              ),

            // ── KPI Cards grid ─────────────────────────────────────────────
            const Text('Overview · 概览',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [
                _KpiCard(
                  icon: Icons.groups_rounded,
                  value: '$totalUsers',
                  label: 'Total Users\n用户总数',
                  color: _C.burgundy,
                  pale: _C.blushPink,
                ),
                _KpiCard(
                  icon: Icons.school_rounded,
                  value: '$students',
                  label: 'Students\n学生',
                  color: _C.magenta,
                  pale: _C.softPink,
                ),
                _KpiCard(
                  icon: Icons.person_rounded,
                  value: '$teachers',
                  label: 'Teachers\n老师',
                  color: _C.slateBlue,
                  pale: const Color(0xFFDCEBF5),
                ),
                _KpiCard(
                  icon: Icons.hourglass_top_rounded,
                  value: '$pending',
                  label: 'Pending Approvals\n待审核',
                  color: const Color(0xFFB8860B),
                  pale: const Color(0xFFFFF3CD),
                ),
                _KpiCard(
                  icon: Icons.event_available_rounded,
                  value: '$active',
                  label: 'Active Sessions\n进行中',
                  color: _C.green,
                  pale: const Color(0xFFDCF7EE),
                ),
                _KpiCard(
                  icon: Icons.check_circle_rounded,
                  value: '$completed',
                  label: 'Completed\n已完成',
                  color: _C.burgundy,
                  pale: _C.blushPink,
                ),
                _KpiCard(
                  icon: Icons.event_busy_rounded,
                  value: '$cancelled',
                  label: 'Cancelled\n已取消',
                  color: _C.inkSoft,
                  pale: _C.softPink,
                ),
                _KpiCard(
                  icon: Icons.payments_rounded,
                  value: '₱${revenue.toStringAsFixed(0)}',
                  label: 'Revenue\n收入',
                  color: _C.slateBlue,
                  pale: const Color(0xFFDCEBF5),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── User distribution donut chart ───────────────────────────────
            const Text('User Distribution · 用户分布',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _C.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _C.line),
              ),
              child: (students + teachers) == 0
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                          child: Text('No user data yet',
                              style: TextStyle(color: _C.inkSoft))),
                    )
                  : SizedBox(
                      height: 160,
                      child: Row(children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 34,
                              sections: [
                                PieChartSectionData(
                                  value: students.toDouble(),
                                  color: _C.magenta,
                                  title: '$students',
                                  radius: 42,
                                  titleStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white),
                                ),
                                PieChartSectionData(
                                  value: teachers.toDouble(),
                                  color: _C.slateBlue,
                                  title: '$teachers',
                                  radius: 42,
                                  titleStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _LegendDot(color: _C.magenta, label: 'Students'),
                            const SizedBox(height: 10),
                            _LegendDot(color: _C.slateBlue, label: 'Teachers'),
                          ],
                        ),
                      ]),
                    ),
            ),
            const SizedBox(height: 24),

            // ── Booking status bar chart ────────────────────────────────────
            const Text('Booking Status · 预约状态',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
              decoration: BoxDecoration(
                color: _C.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _C.line),
              ),
              child: (active + completed + cancelled) == 0
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                          child: Text('No booking data yet',
                              style: TextStyle(color: _C.inkSoft))),
                    )
                  : SizedBox(
                      height: 160,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: [active, completed, cancelled]
                                  .reduce((a, b) => a > b ? a : b) *
                                  1.25 +
                              1,
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, meta) {
                                  const labels = ['Active', 'Done', 'Cancelled'];
                                  final i = v.toInt();
                                  if (i < 0 || i > 2) return const SizedBox();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(labels[i],
                                        style: const TextStyle(
                                            fontSize: 10, color: _C.inkSoft)),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: [
                            BarChartGroupData(x: 0, barRods: [
                              BarChartRodData(
                                  toY: active.toDouble(),
                                  color: _C.green,
                                  width: 28,
                                  borderRadius: BorderRadius.circular(6)),
                            ]),
                            BarChartGroupData(x: 1, barRods: [
                              BarChartRodData(
                                  toY: completed.toDouble(),
                                  color: _C.burgundy,
                                  width: 28,
                                  borderRadius: BorderRadius.circular(6)),
                            ]),
                            BarChartGroupData(x: 2, barRods: [
                              BarChartRodData(
                                  toY: cancelled.toDouble(),
                                  color: _C.inkSoft,
                                  width: 28,
                                  borderRadius: BorderRadius.circular(6)),
                            ]),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
          ]),
        );
      },
    );
  }
}

// ── Teachers approval tab ─────────────────────────────────────────────────────
class _TeachersTab extends ConsumerWidget {
  const _TeachersTab();

  Future<void> _approve(BuildContext ctx, WidgetRef ref, String userId) async {
    final repo = ref.read(_adminRepoProvider);
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/admin/teachers/$userId/approve'),
      headers: await _adminHeaders(repo),
    );
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(res.statusCode == 200 ? 'Teacher approved ✓' : 'Failed'),
        backgroundColor: res.statusCode == 200 ? _C.green : _C.burgundy,
      ));
      if (res.statusCode == 200) ref.invalidate(_pendingTeachersProvider);
    }
  }

  Future<void> _openCreateTeacher(BuildContext ctx, WidgetRef ref) async {
    final created = await Navigator.push<bool>(
      ctx,
      MaterialPageRoute(builder: (_) => const CreateTeacherAccountScreen()),
    );
    if (created == true) {
      ref.invalidate(_pendingTeachersProvider);
      ref.invalidate(_allUsersProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_pendingTeachersProvider);

    return Column(
      children: [
        // ── "Add Teacher" header ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('Pending Approvals · 待审核',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _C.ink)),
              ),
              GestureDetector(
                onTap: () => _openCreateTeacher(context, ref),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: _C.burgundy,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_alt_1_rounded,
                          size: 15, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Add Teacher',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Pending list ──────────────────────────────────────────────────
        Expanded(
          child: async.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: _C.burgundy)),
            error: (e, _) => Center(child: Text('$e')),
            data: (teachers) {
              if (teachers.isEmpty) {
                return const Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48, color: _C.green),
                        SizedBox(height: 12),
                        Text('All teachers approved!',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _C.ink)),
                        Text('· 所有老师已审核', style: TextStyle(color: _C.inkSoft)),
                      ]),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: teachers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final t = teachers[i];
                  final fullName = t['full_name'] as String?;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _C.paper,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _C.line),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: _C.blushPink,
                        child: Text(
                          _initials(fullName),
                          style: const TextStyle(
                              color: _C.burgundy,
                              fontWeight: FontWeight.w800,
                              fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(fullName ?? 'Unnamed',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _C.ink)),
                            Text(t['email'] ?? t['phone'] ?? '',
                                style: const TextStyle(
                                    fontSize: 12, color: _C.inkSoft)),
                            const Text('Pending approval · 待审核',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _C.magenta,
                                    fontWeight: FontWeight.w600)),
                          ])),
                      GestureDetector(
                        onTap: () => _approve(context, ref, t['id']),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _C.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Approve',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Users tab ─────────────────────────────────────────────────────────────────
class _UsersTab extends ConsumerWidget {
  const _UsersTab();

  Future<void> _toggle(BuildContext ctx, WidgetRef ref, String userId) async {
    final repo = ref.read(_adminRepoProvider);
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/admin/users/$userId/toggle'),
      headers: await _adminHeaders(repo),
    );
    if (ctx.mounted) {
      final active = jsonDecode(res.body)['isActive'] as bool?;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(active == true ? 'User activated' : 'User deactivated'),
        backgroundColor: active == true ? _C.green : _C.burgundy,
      ));
      ref.invalidate(_allUsersProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_allUsersProvider);

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _C.burgundy)),
      error: (e, _) => Center(child: Text('$e')),
      data: (users) => ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final u = users[i];
          final fullName = u['full_name'] as String?;
          final role = u['role'] as String;
          final active = u['is_active'] as bool;
          final roleColor = role == 'student'
              ? _C.magenta
              : role == 'teacher'
                  ? _C.slateBlue
                  : _C.burgundy;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: active ? _C.paper : _C.softPink,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.line),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: roleColor.withValues(alpha: 0.15),
                child: Text(
                  _initials(fullName),
                  style:
                      TextStyle(color: roleColor, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(fullName ?? 'Unnamed',
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _C.ink)),
                    Text(u['email'] ?? u['phone'] ?? '',
                        style:
                            const TextStyle(fontSize: 11, color: _C.inkSoft)),
                  ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(role,
                    style: TextStyle(
                        fontSize: 10,
                        color: roleColor,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              if (role != 'admin')
                GestureDetector(
                  onTap: () => _toggle(context, ref, u['id']),
                  child: Icon(
                    active ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                    color: active ? _C.green : _C.inkSoft,
                    size: 32,
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}

// ── KPI card ─────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color, pale;
  const _KpiCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.pale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pale,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: _C.inkSoft,
                  fontWeight: FontWeight.w600,
                  height: 1.3)),
        ],
      ),
    );
  }
}

// ── Legend dot for pie chart ────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(
              fontSize: 12, color: _C.ink, fontWeight: FontWeight.w600)),
    ]);
  }
}