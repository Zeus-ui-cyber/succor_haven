// lib/features/dashboard/teacher_dashboard_screen.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../auth/controllers/auth_controller.dart';
import '../auth/repositories/auth_repository.dart';
import '../../models/user.dart';
import '../../models/booking.dart';

// ── Palette (kiddy / glowy — same family as admin + student dashboards) ─────
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

final _tRepoProvider = Provider((_) => AuthRepository());

final _tMeProvider =
    FutureProvider<UserModel>((ref) => ref.read(_tRepoProvider).getMe());

// ⚠️ CHANGED: parses into BookingModel now (b.*, student_name, teacher_name,
// teacher_avatar, pricing_name, session_type — see bookings.controller.js
// list()). The old code read booking['student_first']/['student_last'],
// which never existed on the real response — only student_name (full_name)
// does, since users has one full_name column, not first/last.
final _tBookingsProvider = FutureProvider<List<BookingModel>>((ref) async {
  final repo = ref.read(_tRepoProvider);
  final token = await repo.getAccessToken();
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/bookings'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (res.statusCode != 200) {
    return [];
  }
  final decoded = jsonDecode(res.body) as List;
  return decoded
      .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ═══════════════════════════════════════════════════════════════════════════════
class TeacherDashboard extends ConsumerStatefulWidget {
  const TeacherDashboard({super.key});
  @override
  ConsumerState<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends ConsumerState<TeacherDashboard> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(_tMeProvider);

    return meAsync.when(
      loading: () => const Scaffold(
        backgroundColor: _C.cream,
        body: Center(child: CircularProgressIndicator(color: _C.coral)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _C.cream,
        body: Center(
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
                const Text('Couldn\'t load profile',
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
                  onTap: () => ref.invalidate(_tMeProvider),
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
      ),
      data: (user) => Scaffold(
        backgroundColor: _C.cream,
        body: SafeArea(
          child: Stack(children: [
            const _BackgroundBlobs(),
            IndexedStack(
              index: _navIndex,
              children: [
                _THomeTab(user: user),
                _TScheduleTab(user: user),
                _TSessionsTab(user: user),
                _TEarningsTab(user: user),
                _TProfileTab(user: user, onLogout: _logout),
              ],
            ),
          ]),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    const items = [
      (Icons.home_rounded, Icons.home_outlined, 'Home', '首页'),
      (
        Icons.calendar_month_rounded,
        Icons.calendar_month_outlined,
        'Schedule',
        '日程'
      ),
      (Icons.video_call_rounded, Icons.video_call_outlined, 'Sessions', '课程'),
      (
        Icons.account_balance_wallet_rounded,
        Icons.account_balance_wallet_outlined,
        'Earnings',
        '收入'
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
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        color: active ? Colors.white : _C.inkSoft, size: 21),
                    const SizedBox(height: 2),
                    Text(active ? item.$3 : item.$4,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: active ? Colors.white : _C.inkSoft)),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }
}

// ── Decorative background blobs (shared visual language across dashboards) ──
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
          gradient:
              RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      );
}

// ── HOME TAB ──────────────────────────────────────────────────────────────────
class _THomeTab extends ConsumerWidget {
  final UserModel user;
  const _THomeTab({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_tBookingsProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        // Stats hero
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          sliver: SliverToBoxAdapter(
            child: bookingsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (b) => _StatsHero(bookings: b),
            ),
          ),
        ),
        // Next session
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(
            child: bookingsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (b) {
                final next = b
                    .where((x) => x.status == BookingStatus.confirmed)
                    .toList();
                if (next.isEmpty) {
                  return const SizedBox.shrink();
                }
                return _TNextSessionBanner(booking: next.first);
              },
            ),
          ),
        ),
        // Upcoming
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
          sliver:
              SliverToBoxAdapter(child: _TLabel('Upcoming Sessions', '即将上课')),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverToBoxAdapter(
            child: bookingsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: _C.coral)),
              error: (e, _) => Text('$e'),
              data: (b) {
                final upcoming =
                    b.where((x) => x.status == BookingStatus.confirmed).toList();
                if (upcoming.isEmpty) {
                  return const _TEmpty('No upcoming sessions yet', '暂无即将上课的课程');
                }
                return Column(
                    children: upcoming
                        .take(5)
                        .map((x) => _TBookingCard(
                            booking: x, showComplete: true, ref: null))
                        .toList());
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(children: [
        const _OwlMascot(size: 52),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hi, ${user.firstName}! 🎓',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: _C.navy)),
          const Text('· 老师 Teacher',
              style: TextStyle(
                  fontSize: 12, color: _C.coral, fontWeight: FontWeight.w700)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_C.sunshine, _C.coral]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: _C.coral.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3)),
              ]),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.verified_rounded, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text('Teacher',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );
  }
}

// ── SCHEDULE TAB ──────────────────────────────────────────────────────────────
class _TScheduleTab extends ConsumerWidget {
  final UserModel user;
  const _TScheduleTab({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_tBookingsProvider);
    final now = DateTime.now();
    final days =
        List.generate(7, (i) => DateTime(now.year, now.month, now.day + i));
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: _PageHeader('Schedule', '日程安排', '🗓️'),
      ),
      SizedBox(
        height: 72,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: days.length,
          itemBuilder: (_, i) {
            final day = days[i];
            final isToday = i == 0;
            return bookingsAsync.when(
              loading: () => _DayChip(
                  day: day,
                  dayName: dayNames[(day.weekday - 1) % 7],
                  isToday: isToday,
                  hasSession: false),
              error: (_, __) => _DayChip(
                  day: day,
                  dayName: dayNames[(day.weekday - 1) % 7],
                  isToday: isToday,
                  hasSession: false),
              data: (bookings) {
                final hasSession = bookings.any((b) {
                  final dt = b.scheduledAt;
                  return dt.year == day.year &&
                      dt.month == day.month &&
                      dt.day == day.day &&
                      b.status == BookingStatus.confirmed;
                });
                return _DayChip(
                    day: day,
                    dayName: dayNames[(day.weekday - 1) % 7],
                    isToday: isToday,
                    hasSession: hasSession);
              },
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: _TLabel('All Booked Sessions', '所有预约课程'),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: bookingsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _C.coral)),
          error: (e, _) => Center(child: Text('$e')),
          data: (bookings) {
            final scheduled = bookings
                .where((b) =>
                    b.status == BookingStatus.confirmed ||
                    b.status == BookingStatus.pending)
                .toList()
              ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

            if (scheduled.isEmpty) {
              return const Center(
                  child: _TEmpty('No scheduled sessions', '暂无排课'));
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              itemCount: scheduled.length,
              itemBuilder: (_, i) => _TScheduleCard(booking: scheduled[i]),
            );
          },
        ),
      ),
    ]);
  }
}

// ── SESSIONS TAB ──────────────────────────────────────────────────────────────
class _TSessionsTab extends ConsumerWidget {
  final UserModel user;
  const _TSessionsTab({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_tBookingsProvider);

    return Column(children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: _PageHeader('Sessions', '课程管理', '🎬'),
      ),
      Expanded(
        child: bookingsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _C.coral)),
          error: (e, _) => Center(child: Text('$e')),
          data: (bookings) {
            if (bookings.isEmpty) {
              return const Center(child: _TEmpty('No sessions yet', '暂无课程'));
            }
            final upcoming = bookings
                .where((b) => b.status == BookingStatus.confirmed)
                .toList();
            final completed = bookings
                .where((b) => b.status == BookingStatus.completed)
                .toList();
            final cancelled = bookings
                .where((b) => b.status == BookingStatus.cancelled)
                .toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                if (upcoming.isNotEmpty) ...[
                  const _TLabel('Upcoming', '即将上课'),
                  const SizedBox(height: 10),
                  ...upcoming.map((b) =>
                      _TBookingCard(booking: b, showComplete: true, ref: ref)),
                  const SizedBox(height: 16),
                ],
                if (completed.isNotEmpty) ...[
                  const _TLabel('Completed', '已完成'),
                  const SizedBox(height: 10),
                  ...completed.map((b) => _TBookingCard(
                      booking: b, showComplete: false, ref: null)),
                  const SizedBox(height: 16),
                ],
                if (cancelled.isNotEmpty) ...[
                  const _TLabel('Cancelled', '已取消'),
                  const SizedBox(height: 10),
                  ...cancelled.map((b) => _TBookingCard(
                      booking: b, showComplete: false, ref: null)),
                ],
              ],
            );
          },
        ),
      ),
    ]);
  }
}

// ── EARNINGS TAB ──────────────────────────────────────────────────────────────
class _TEarningsTab extends ConsumerWidget {
  final UserModel user;
  const _TEarningsTab({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_tBookingsProvider);

    return bookingsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _C.coral)),
      error: (e, _) => Center(child: Text('$e')),
      data: (bookings) {
        final completed =
            bookings.where((b) => b.status == BookingStatus.completed).toList();
        final totalCredits =
            completed.fold<int>(0, (sum, b) => sum + b.creditsCost);
        final totalSessions = completed.length;
        final thisMonth = completed.where((b) {
          final dt = b.scheduledAt;
          final now = DateTime.now();
          return dt.year == now.year && dt.month == now.month;
        }).toList();
        final monthCredits =
            thisMonth.fold<int>(0, (sum, b) => sum + b.creditsCost);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            const _PageHeader('Earnings', '收入统计', '💰'),
            const SizedBox(height: 16),

            // Total earnings hero (navy glow card — matches admin's revenue card)
            Container(
              padding: const EdgeInsets.all(22),
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
                    child: Icon(Icons.diamond_rounded,
                        size: 90, color: _C.sunshine),
                  ),
                ),
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Credits Earned · 总积分收入',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('$totalCredits',
                          style: const TextStyle(
                              color: _C.sunshine,
                              fontSize: 44,
                              fontWeight: FontWeight.w900)),
                      const Text('credits from completed sessions',
                          style:
                              TextStyle(color: Colors.white60, fontSize: 12)),
                    ]),
              ]),
            ),
            const SizedBox(height: 16),

            // Stats row
            Row(children: [
              Expanded(
                  child: _EarningStat('$totalSessions', 'Sessions\n总课程数',
                      _C.coral, _C.coralSoft)),
              const SizedBox(width: 10),
              Expanded(
                  child: _EarningStat('$monthCredits', 'This Month\n本月收入',
                      _C.green, _C.greenPale)),
              const SizedBox(width: 10),
              Expanded(
                  child: _EarningStat(
                      totalSessions > 0
                          ? (totalCredits / totalSessions).toStringAsFixed(1)
                          : '0',
                      'Avg / Session\n平均每课',
                      _C.navy,
                      _C.sunshineGlow)),
            ]),
            const SizedBox(height: 24),

            const _TLabel('Session Breakdown', '课程明细'),
            const SizedBox(height: 12),
            if (completed.isEmpty)
              const _TEmpty('No completed sessions yet', '暂无已完成课程')
            else
              ...completed.map((b) => _EarningRow(booking: b)),
          ],
        );
      },
    );
  }
}

// ── PROFILE TAB ───────────────────────────────────────────────────────────────
class _TProfileTab extends ConsumerWidget {
  final UserModel user;
  final VoidCallback onLogout;
  const _TProfileTab({required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_tBookingsProvider);
    final totalSessions = bookingsAsync.whenOrNull(
          data: (b) =>
              b.where((x) => x.status == BookingStatus.completed).length,
        ) ??
        0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Center(
            child: Column(children: [
          const _OwlMascot(size: 84),
          const SizedBox(height: 14),
          Text(user.fullName,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: _C.navy)),
          const SizedBox(height: 2),
          Text(user.email,
              style: const TextStyle(fontSize: 13, color: _C.inkSoft)),
          const SizedBox(height: 8),
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
            child: const Text('老师 · Teacher',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w800)),
          ),
        ])),
        const SizedBox(height: 28),

        // ⚠️ CHANGED: user.phone doesn't exist on UserModel (the real users
        // table has no phone column) — swapped for languagePref, which is
        // an actual field on the model.
        Row(children: [
          Expanded(
              child: _TeacherProfileStat('$totalSessions', 'Sessions\n总课程')),
          const SizedBox(width: 12),
          Expanded(
              child: _TeacherProfileStat(
                  user.languagePref.toUpperCase(), 'Language\n语言')),
        ]),
        const SizedBox(height: 24),

        // ⚠️ CHANGED: "Credits Per Session" removed — teachers.controller.js
        // no longer has a credits_per_session column on teacher_profiles;
        // session cost is set by an admin via the pricing table and picked
        // by the student per-course. Replaced with an informational tile.
        _TProfileSection('Teaching', '教学', [
          _TProfileTile(
              Icons.edit_rounded, 'Edit Bio & Subjects', '编辑简介', _noop),
          _TProfileTile(
              Icons.schedule_rounded, 'Set Availability', '设置空闲时间', _noop),
          _TProfileTile(Icons.info_outline_rounded, 'Session Pricing (set by admin)',
              '课程定价由管理员设置', _noop),
        ]),
        const SizedBox(height: 16),
        _TProfileSection('Account', '账户', [
          _TProfileTile(Icons.lock_outline, 'Change Password', '修改密码', _noop),
          _TProfileTile(
              Icons.notifications_outlined, 'Notifications', '通知', _noop),
        ]),
        const SizedBox(height: 24),

        OutlinedButton.icon(
          onPressed: onLogout,
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

void _noop() {}

// ══════════════════════════════════════════════════════════════════════════════
// THE TWIST — animated owl mascot 🦉 (teacher's wise companion)
// Bobs gently like the admin's tool mascot, and gives a little extra "wing
// flap" wiggle whenever a session gets marked complete (see _CelebrationPulse
// below, which the owl listens for via the shared completionPulseProvider).
// ══════════════════════════════════════════════════════════════════════════════
final _completionPulseProvider = StateProvider<int>((ref) => 0);

class _OwlMascot extends ConsumerStatefulWidget {
  final double size;
  const _OwlMascot({required this.size});
  @override
  ConsumerState<_OwlMascot> createState() => _OwlMascotState();
}

class _OwlMascotState extends ConsumerState<_OwlMascot>
    with TickerProviderStateMixin {
  // TickerProviderStateMixin (not Single-) because this state drives TWO
  // AnimationControllers — the idle bob loop and the completion wiggle.
  // SingleTickerProviderStateMixin only supports one ticker per State and
  // throws "_OwlMascotState is a SingleTickerProviderStateMixin but
  // multiple tickers were created" on the second AnimationController
  // (vsync: this) call.
  late final AnimationController _bobCtrl;
  late final AnimationController _wiggleCtrl;
  int _lastPulse = 0;

  @override
  void initState() {
    super.initState();
    _bobCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _wiggleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _bobCtrl.dispose();
    _wiggleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pulse = ref.watch(_completionPulseProvider);
    if (pulse != _lastPulse) {
      _lastPulse = pulse;
      _wiggleCtrl.forward(from: 0);
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_bobCtrl, _wiggleCtrl]),
      builder: (_, __) {
        final bob = math.sin(_bobCtrl.value * math.pi) * -4;
        final wiggle =
            math.sin(_wiggleCtrl.value * math.pi * 4) * (1 - _wiggleCtrl.value) * 0.15;
        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(
            angle: wiggle,
            child: Container(
              width: widget.size,
              height: widget.size,
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
              child: Center(
                  child: Text('🦉',
                      style: TextStyle(fontSize: widget.size * 0.43))),
            ),
          ),
        );
      },
    );
  }
}

// Little floating "+credits" celebration that pops up near a card when a
// session is marked done — the second half of the twist alongside the owl.
class _CelebrationPulse extends StatefulWidget {
  final VoidCallback onDone;
  const _CelebrationPulse({required this.onDone});
  @override
  State<_CelebrationPulse> createState() => _CelebrationPulseState();
}

class _CelebrationPulseState extends State<_CelebrationPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward().whenComplete(widget.onDone);
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
        final t = _ctrl.value;
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -28 * t),
            child: const Text('✨ +credits',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _C.green)),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED TEACHER WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _PageHeader extends StatelessWidget {
  final String en, zh, emoji;
  const _PageHeader(this.en, this.zh, this.emoji);
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [_C.sunshine, _C.coral]),
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
      ]);
}

class _StatsHero extends StatelessWidget {
  final List<BookingModel> bookings;
  const _StatsHero({required this.bookings});
  @override
  Widget build(BuildContext context) {
    final total = bookings.length;
    final completed =
        bookings.where((b) => b.status == BookingStatus.completed).length;
    final upcoming =
        bookings.where((b) => b.status == BookingStatus.confirmed).length;
    final credits = bookings
        .where((b) => b.status == BookingStatus.completed)
        .fold<int>(0, (s, b) => s + b.creditsCost);

    return Row(children: [
      Expanded(child: _MiniStat('$total', 'Total\n总计', _C.navy, _C.sunshineGlow)),
      const SizedBox(width: 10),
      Expanded(
          child: _MiniStat('$completed', 'Done\n已完成', _C.green, _C.greenPale)),
      const SizedBox(width: 10),
      Expanded(
          child: _MiniStat('$upcoming', 'Soon\n即将', _C.coral, _C.coralSoft)),
      const SizedBox(width: 10),
      Expanded(
          child:
              _MiniStat('$credits', 'Credits\n积分', _C.navySoft, _C.blushSoft)),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  final String value, label;
  final Color color, pale;
  const _MiniStat(this.value, this.label, this.color, this.pale);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: pale,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.16),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 9,
                  color: _C.inkSoft,
                  fontWeight: FontWeight.w700,
                  height: 1.3)),
        ]),
      );
}

class _TNextSessionBanner extends StatelessWidget {
  final BookingModel booking;
  const _TNextSessionBanner({required this.booking});
  @override
  Widget build(BuildContext context) {
    final dt = booking.scheduledAt.toLocal();
    final name = booking.studentName ?? 'your student';
    return Container(
      padding: const EdgeInsets.all(16),
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
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_C.sunshine, _C.coral]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: _C.coral.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ]),
          child: const Icon(Icons.video_call_rounded,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Next Session · 下一节课',
              style: TextStyle(
                  fontSize: 11, color: _C.coral, fontWeight: FontWeight.w800)),
          Text('with $name',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _C.navy)),
          Text(
              '${dt.day}/${dt.month}  '
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12, color: _C.inkSoft)),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _C.coral),
      ]),
    );
  }
}

class _TBookingCard extends ConsumerStatefulWidget {
  final BookingModel booking;
  final bool showComplete;
  final WidgetRef? ref;
  const _TBookingCard(
      {required this.booking, required this.showComplete, required this.ref});

  @override
  ConsumerState<_TBookingCard> createState() => _TBookingCardState();
}

class _TBookingCardState extends ConsumerState<_TBookingCard> {
  bool _showCelebration = false;

  Future<void> _complete(BuildContext context) async {
    final activeRef = widget.ref ?? ref;
    final repo = activeRef.read(_tRepoProvider);
    final token = await repo.getAccessToken();
    final res = await http.patch(
      Uri.parse(
          '${AuthRepository.baseUrl}/bookings/${widget.booking.id}/complete'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.statusCode == 200 ? 'Session completed ✓' : 'Failed'),
        backgroundColor: res.statusCode == 200 ? _C.green : _C.coral,
      ));
      if (res.statusCode == 200) {
        setState(() => _showCelebration = true);
        ref.read(_completionPulseProvider.notifier).state++;
        activeRef.invalidate(_tBookingsProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final name = booking.studentName ?? 'Student';
    final initial = name.isNotEmpty ? name[0] : '?';
    final status = booking.status;
    final dt = booking.scheduledAt.toLocal();

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
            radius: 20,
            backgroundColor: _C.sunshineGlow,
            child: Text(initial,
                style: const TextStyle(
                    color: _C.navy, fontWeight: FontWeight.w900))),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _C.navy)),
          const SizedBox(height: 2),
          Text(
              '${dt.day}/${dt.month}/${dt.year}  '
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
          Text(
              '${booking.creditsCost} credits · ${booking.durationMins} min',
              style: const TextStyle(
                  fontSize: 11, color: _C.coral, fontWeight: FontWeight.w700)),
        ])),
        if (_showCelebration)
          _CelebrationPulse(onDone: () {
            if (mounted) setState(() => _showCelebration = false);
          }),
        if (widget.showComplete && status == BookingStatus.confirmed)
          GestureDetector(
            onTap: () => _complete(context),
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
              child: const Text('Done',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w800)),
            ),
          )
        else if (!_showCelebration)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: (status == BookingStatus.completed ? _C.green : _C.inkSoft)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20)),
            child: Text(status.label,
                style: TextStyle(
                    fontSize: 10,
                    color:
                        status == BookingStatus.completed ? _C.green : _C.inkSoft,
                    fontWeight: FontWeight.w800)),
          ),
      ]),
    );
  }
}

class _TScheduleCard extends StatelessWidget {
  final BookingModel booking;
  const _TScheduleCard({required this.booking});
  @override
  Widget build(BuildContext context) {
    final name = booking.studentName ?? 'Student';
    final dt = booking.scheduledAt.toLocal();
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
        SizedBox(
          width: 48,
          child: Column(children: [
            Text(dayNames[(dt.weekday - 1) % 7],
                style: const TextStyle(
                    fontSize: 11, color: _C.inkSoft, fontWeight: FontWeight.w700)),
            Text('${dt.day}',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: _C.coral)),
            Text('${dt.month}/${dt.year.toString().substring(2)}',
                style: const TextStyle(fontSize: 10, color: _C.inkSoft)),
          ]),
        ),
        Container(
            width: 1,
            height: 50,
            color: _C.line,
            margin: const EdgeInsets.symmetric(horizontal: 12)),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _C.navy)),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.access_time_rounded, size: 12, color: _C.inkSoft),
            const SizedBox(width: 4),
            Text(
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}  '
                '· ${booking.durationMins} min',
                style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
          ]),
          Row(children: [
            const Icon(Icons.diamond_rounded, size: 12, color: _C.coral),
            const SizedBox(width: 4),
            Text('${booking.creditsCost} credits',
                style: const TextStyle(
                    fontSize: 11, color: _C.coral, fontWeight: FontWeight.w700)),
          ]),
        ])),
      ]),
    );
  }
}

class _EarningRow extends StatelessWidget {
  final BookingModel booking;
  const _EarningRow({required this.booking});
  @override
  Widget build(BuildContext context) {
    final name = booking.studentName ?? 'Student';
    final initial = name.isNotEmpty ? name[0] : '?';
    final credits = booking.creditsCost;
    final dt = booking.scheduledAt.toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.line, width: 1.4),
      ),
      child: Row(children: [
        CircleAvatar(
            radius: 16,
            backgroundColor: _C.sunshineGlow,
            child: Text(initial,
                style: const TextStyle(
                    color: _C.navy, fontWeight: FontWeight.w900, fontSize: 12))),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: _C.navy)),
          Text('${dt.day}/${dt.month}/${dt.year}',
              style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: _C.greenPale, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.diamond_rounded, size: 12, color: _C.green),
            const SizedBox(width: 4),
            Text('+$credits',
                style: const TextStyle(
                    fontSize: 12, color: _C.green, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );
  }
}

class _EarningStat extends StatelessWidget {
  final String value, label;
  final Color color, pale;
  const _EarningStat(this.value, this.label, this.color, this.pale);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
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
                  fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: _C.inkSoft,
                  fontWeight: FontWeight.w700,
                  height: 1.4)),
        ]),
      );
}

class _DayChip extends StatelessWidget {
  final DateTime day;
  final String dayName;
  final bool isToday, hasSession;
  const _DayChip(
      {required this.day,
      required this.dayName,
      required this.isToday,
      required this.hasSession});
  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          gradient: isToday
              ? const LinearGradient(colors: [_C.sunshine, _C.coral])
              : null,
          color: isToday ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isToday ? Colors.transparent : _C.line, width: 1.4),
          boxShadow: isToday
              ? [
                  BoxShadow(
                      color: _C.coral.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(dayName,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isToday ? Colors.white70 : _C.inkSoft)),
          const SizedBox(height: 2),
          Text('${day.day}',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isToday ? Colors.white : _C.navy)),
          if (hasSession)
            Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                    color: isToday ? Colors.white : _C.coral,
                    shape: BoxShape.circle)),
        ]),
      );
}

class _TLabel extends StatelessWidget {
  final String en;
  final String? zh;
  const _TLabel(this.en, [this.zh]);
  @override
  Widget build(BuildContext context) => Row(children: [
        Text(en,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w900, color: _C.navy)),
        if (zh != null) ...[
          const SizedBox(width: 5),
          Text('· $zh',
              style: const TextStyle(
                  fontSize: 12, color: _C.coral, fontWeight: FontWeight.w700)),
        ],
      ]);
}

class _TEmpty extends StatelessWidget {
  final String title, titleCn;
  const _TEmpty(this.title, this.titleCn);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: _C.sunshineGlow.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _C.line, width: 1.4)),
        child: Column(children: [
          const Text('🗓️', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: _C.navy)),
          Text('· $titleCn',
              style: const TextStyle(fontSize: 12, color: _C.coral)),
        ]),
      );
}

class _TeacherProfileStat extends StatelessWidget {
  final String value, label;
  const _TeacherProfileStat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.sunshineGlow.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: _C.navy)),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 10,
                  color: _C.inkSoft,
                  fontWeight: FontWeight.w700,
                  height: 1.4)),
        ]),
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
                      fontSize: 13, fontWeight: FontWeight.w800, color: _C.inkSoft)),
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