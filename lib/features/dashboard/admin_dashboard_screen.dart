// lib/features/dashboard/admin_dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../auth/controllers/auth_controller.dart';
import '../auth/repositories/auth_repository.dart';

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
  static const greenPale = Color(0xFFDCF7EE);
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
  if (res.statusCode != 200) throw Exception('Failed to load dashboard');
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
    _tabs = TabController(length: 3, vsync: this);
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
                ],
              ),
            ),
          ],
        ),
      ),
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

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Revenue card
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
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Revenue · 总收入',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
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
                margin: const EdgeInsets.only(bottom: 16),
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

            // User counts
            const Text('Users · 用户',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _AdminStat('${countByRole('student')}', 'Students\n学生',
                      _C.magenta, _C.softPink)),
              const SizedBox(width: 10),
              Expanded(
                  child: _AdminStat('${countByRole('teacher')}', 'Teachers\n老师',
                      _C.slateBlue, const Color(0xFFDCEBF5))),
            ]),
            const SizedBox(height: 20),

            // Booking counts
            const Text('Bookings · 预约',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _AdminStat('${countByStatus('confirmed')}',
                      'Active\n进行中', _C.green, const Color(0xFFDCF7EE))),
              const SizedBox(width: 10),
              Expanded(
                  child: _AdminStat('${countByStatus('completed')}',
                      'Done\n已完成', _C.burgundy, _C.blushPink)),
              const SizedBox(width: 10),
              Expanded(
                  child: _AdminStat('${countByStatus('cancelled')}',
                      'Cancelled\n已取消', _C.inkSoft, _C.softPink)),
            ]),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_pendingTeachersProvider);

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _C.burgundy)),
      error: (e, _) => Center(child: Text('$e')),
      data: (teachers) {
        if (teachers.isEmpty) {
          return const Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle_outline, size: 48, color: _C.green),
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
                    '${t['first_name'][0]}${t['last_name'][0]}',
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
                      Text('${t['first_name']} ${t['last_name']}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _C.ink)),
                      Text(t['email'] ?? t['phone'] ?? '',
                          style:
                              const TextStyle(fontSize: 12, color: _C.inkSoft)),
                      const Text('Pending approval · 待审核',
                          style: TextStyle(
                              fontSize: 11,
                              color: _C.magenta,
                              fontWeight: FontWeight.w600)),
                    ])),
                GestureDetector(
                  onTap: () => _approve(context, ref, t['id']),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                  u['first_name'][0],
                  style:
                      TextStyle(color: roleColor, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${u['first_name']} ${u['last_name']}',
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

// ── Shared stat card ──────────────────────────────────────────────────────────
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
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900, color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: _C.inkSoft,
                fontWeight: FontWeight.w600,
                height: 1.4)),
      ]),
    );
  }
}
