// lib/features/dashboard/teacher_dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../auth/controllers/auth_controller.dart';
import '../auth/repositories/auth_repository.dart';
import '../../core/api/api_service.dart';
import '../../models/user.dart';
import '../../models/appointment.dart';
import '../settings/repositories/settings_repository.dart';
import '../settings/screens/teacher/edit_bio_subjects_screen.dart';
import '../settings/screens/teacher/set_availability_screen.dart';
import '../settings/screens/teacher/credits_per_session_screen.dart';
import '../settings/screens/student/change_password_screen.dart';
import '../appointments/controllers/appointment_controller.dart';
import '../appointments/screens/teacher_appointments_screen.dart';
import '../modules/screens/modules_screen.dart';
import '../booking/utils/avatar_url.dart';
import '../announcements/controllers/announcement_controller.dart';
import '../announcements/widgets/announcement_feed_section.dart';
import '../notifications/widgets/notification_bell.dart';

class _C {
  static const slateBlue = Color(0xFF3E678A);
  static const bluePale = Color(0xFFDCEBF5);
  static const magenta = Color(0xFFD64577);
  static const burgundy = Color(0xFF7D002B);
  static const blushPink = Color(0xFFF2C6D6);
  static const softPink = Color(0xFFF9E1EA);
  static const cream = Color(0xFFFFF5F7);
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
  static const line = Color(0xFFF0DCE5);
  static const paper = Color(0xFFFFFFFF);
  static const green = Color(0xFF00C48C);
  static const greenPale = Color(0xFFDCF7EE);
  static const purple = Color(0xFF8E5FD6);
  static const purplePale = Color(0xFFEBE2FA);
}

// Guards against an empty firstName string crashing on ''[0] — same
// pattern applied to the student dashboard. Falls back to lastName, then
// '?' if both are somehow empty.
String _avatarLetter(UserModel user) {
  final f = user.firstName.trim();
  if (f.isNotEmpty) return f[0].toUpperCase();
  final l = user.lastName.trim();
  if (l.isNotEmpty) return l[0].toUpperCase();
  return '?';
}

final _tRepoProvider = Provider((_) => AuthRepository());

final _tMeProvider =
    FutureProvider<UserModel>((ref) => ref.read(_tRepoProvider).getMe());

final _tBookingsProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(_tRepoProvider);
  final token = await repo.getAccessToken();
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/bookings'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (res.statusCode != 200) return [];
  return jsonDecode(res.body) as List;
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
        body: Center(child: CircularProgressIndicator(color: _C.slateBlue)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _C.cream,
        body: Center(child: Text('$e')),
      ),
      data: (user) => Scaffold(
        backgroundColor: _C.cream,
        body: SafeArea(
          child: IndexedStack(
            index: _navIndex,
            children: [
              _THomeTab(user: user),
              _TScheduleTab(user: user),
              _TSessionsTab(user: user),
              _TEarningsTab(user: user),
              _TProfileTab(user: user, onLogout: _logout),
            ],
          ),
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
      decoration: const BoxDecoration(
        color: _C.paper,
        border: Border(top: BorderSide(color: _C.line, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final active = i == _navIndex;
              final item = items[i];
              return GestureDetector(
                onTap: () => setState(() => _navIndex = i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? _C.bluePale : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(active ? item.$1 : item.$2,
                        color: active ? _C.slateBlue : _C.inkSoft, size: 22),
                    const SizedBox(height: 2),
                    Text(active ? item.$3 : item.$4,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: active ? _C.slateBlue : _C.inkSoft)),
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

// ── HOME TAB ──────────────────────────────────────────────────────────────────
class _THomeTab extends ConsumerWidget {
  final UserModel user;
  const _THomeTab({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_tBookingsProvider);

    return RefreshIndicator(
      color: _C.slateBlue,
      onRefresh: () async {
        ref.invalidate(_tBookingsProvider);
        ref.invalidate(announcementFeedProvider);
      },
      child: CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),

        // Appointment requests entry point
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          sliver: const SliverToBoxAdapter(child: _AppointmentsEntryCard()),
        ),

        // Modules entry point
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          sliver: SliverToBoxAdapter(child: _ModulesEntryCard(user: user)),
        ),

        // ── Faculty Updates · Announcements ─────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          sliver: const SliverToBoxAdapter(child: AnnouncementFeedSection()),
        ),

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
                final next =
                    b.where((x) => x['status'] == 'confirmed').toList();
                if (next.isEmpty) return const SizedBox.shrink();
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
              loading: () => const Center(
                  child: CircularProgressIndicator(color: _C.slateBlue)),
              error: (e, _) => Text('$e'),
              data: (b) {
                final upcoming =
                    b.where((x) => x['status'] == 'confirmed').toList();
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
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: _C.bluePale,
          backgroundImage: user.profilePictureUrl != null
              ? NetworkImage(resolveAvatarUrl(user.profilePictureUrl)!)
              : null,
          child: user.profilePictureUrl == null
              ? Text(_avatarLetter(user),
                  style: const TextStyle(
                      color: _C.slateBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 16))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hi, ${user.firstName}! 🎓',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _C.ink)),
          const Text('老师 · Teacher',
              style: TextStyle(fontSize: 11, color: _C.inkSoft)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: _C.bluePale, borderRadius: BorderRadius.circular(20)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.verified_outlined, color: _C.slateBlue, size: 14),
            SizedBox(width: 4),
            Text('Teacher',
                style: TextStyle(
                    fontSize: 11,
                    color: _C.slateBlue,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 10),
        const NotificationBell(),
      ]),
    );
  }
}

// ── Appointment requests entry card (Home tab) ─────────────────────────────────
// Shows a live pending count via teacherAppointmentsProvider (from
// appointment_controller.dart) and opens TeacherAppointmentsScreen, which
// handles the full Pending/Approved/Today/Upcoming/Completed/Declined/
// Cancelled categorized workflow.
class _AppointmentsEntryCard extends ConsumerWidget {
  const _AppointmentsEntryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherAppointmentsProvider);
    final pendingCount = async.whenOrNull(
          data: (list) =>
              list.where((a) => a.status.apiValue == 'pending').length,
        ) ??
        0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TeacherAppointmentsScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.line),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _C.bluePale,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_note_rounded,
                color: _C.slateBlue, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appointment Requests',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _C.ink)),
                Text('预约请求',
                    style: TextStyle(fontSize: 11, color: _C.slateBlue)),
              ],
            ),
          ),
          if (pendingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _C.magenta,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$pendingCount pending',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: _C.inkSoft),
        ]),
      ),
    );
  }
}

// ── Modules entry card (Home tab) ───────────────────────────────────────────
// Opens ModulesScreen (shared with admin), which lists both admin-uploaded
// reference materials and the teacher's own supplementary uploads.
class _ModulesEntryCard extends StatelessWidget {
  final UserModel user;
  const _ModulesEntryCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ModulesScreen(currentUser: user)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.line),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _C.purplePale,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.folder_copy_outlined,
                color: _C.purple, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Learning Modules',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _C.ink)),
                Text('教学资料', style: TextStyle(fontSize: 11, color: _C.purple)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: _C.inkSoft),
        ]),
      ),
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
    // Build next 7 days
    final days =
        List.generate(7, (i) => DateTime(now.year, now.month, now.day + i));
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(children: [
      // Header
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Schedule',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: _C.ink)),
            Text('日程安排',
                style: TextStyle(
                    fontSize: 12,
                    color: _C.slateBlue,
                    fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
      // Week strip
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
                  final dt = DateTime.parse(b['scheduled_at']);
                  return dt.year == day.year &&
                      dt.month == day.month &&
                      dt.day == day.day &&
                      b['status'] == 'confirmed';
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
          loading: () => const Center(
              child: CircularProgressIndicator(color: _C.slateBlue)),
          error: (e, _) => Center(child: Text('$e')),
          data: (bookings) {
            final scheduled = bookings
                .where((b) =>
                    b['status'] == 'confirmed' || b['status'] == 'pending')
                .toList()
              ..sort((a, b) => DateTime.parse(a['scheduled_at'])
                  .compareTo(DateTime.parse(b['scheduled_at'])));

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
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sessions',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: _C.ink)),
            Text('课程管理',
                style: TextStyle(
                    fontSize: 12,
                    color: _C.slateBlue,
                    fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
      Expanded(
        child: bookingsAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: _C.slateBlue)),
          error: (e, _) => Center(child: Text('$e')),
          data: (bookings) {
            if (bookings.isEmpty) {
              return const Center(child: _TEmpty('No sessions yet', '暂无课程'));
            }
            final upcoming =
                bookings.where((b) => b['status'] == 'confirmed').toList();
            final completed =
                bookings.where((b) => b['status'] == 'completed').toList();
            final cancelled =
                bookings.where((b) => b['status'] == 'cancelled').toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                if (upcoming.isNotEmpty) ...[
                  const _TLabel('Upcoming · 即将上课'),
                  ...upcoming.map((b) =>
                      _TBookingCard(booking: b, showComplete: true, ref: ref)),
                  const SizedBox(height: 16),
                ],
                if (completed.isNotEmpty) ...[
                  const _TLabel('Completed · 已完成'),
                  ...completed.map((b) => _TBookingCard(
                      booking: b, showComplete: false, ref: null)),
                  const SizedBox(height: 16),
                ],
                if (cancelled.isNotEmpty) ...[
                  const _TLabel('Cancelled · 已取消'),
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
          const Center(child: CircularProgressIndicator(color: _C.slateBlue)),
      error: (e, _) => Center(child: Text('$e')),
      data: (bookings) {
        final completed =
            bookings.where((b) => b['status'] == 'completed').toList();
        final totalCredits = completed.fold<int>(
            0, (sum, b) => sum + (b['credits_cost'] as int? ?? 0));
        final totalSessions = completed.length;
        final thisMonth = completed.where((b) {
          final dt = DateTime.parse(b['scheduled_at']);
          final now = DateTime.now();
          return dt.year == now.year && dt.month == now.month;
        }).toList();
        final monthCredits = thisMonth.fold<int>(
            0, (sum, b) => sum + (b['credits_cost'] as int? ?? 0));

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            // Earnings header
            const Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Earnings',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _C.ink)),
                Text('收入统计',
                    style: TextStyle(
                        fontSize: 12,
                        color: _C.slateBlue,
                        fontWeight: FontWeight.w600)),
              ]),
            ]),
            const SizedBox(height: 16),

            // Total earnings hero
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_C.slateBlue, Color(0xFF2D5A7E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Credits Earned · 总积分收入',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('$totalCredits',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900)),
                    const Text('credits from completed sessions',
                        style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ]),
            ),
            const SizedBox(height: 16),

            // Stats row
            Row(children: [
              _EarningStat('$totalSessions', 'Total Sessions\n总课程数',
                  _C.slateBlue, _C.bluePale),
              const SizedBox(width: 12),
              _EarningStat(
                  '$monthCredits', 'This Month\n本月收入', _C.green, _C.greenPale),
              const SizedBox(width: 12),
              _EarningStat(
                  totalSessions > 0
                      ? (totalCredits / totalSessions).toStringAsFixed(1)
                      : '0',
                  'Avg / Session\n平均每课',
                  _C.magenta,
                  const Color(0xFFF9E1EA)),
            ]),
            const SizedBox(height: 24),

            // Per-session breakdown
            const _TLabel('Session Breakdown · 课程明细'),
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

  Future<void> _pickAndUploadPhoto(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    try {
      await SettingsRepository().uploadProfilePicture(bytes, picked.name);
      ref.invalidate(_tMeProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated · 头像已更新')),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload photo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_tBookingsProvider);
    final totalSessions = bookingsAsync.whenOrNull(
          data: (b) => b.where((x) => x['status'] == 'completed').length,
        ) ??
        0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Center(
            child: Column(children: [
          GestureDetector(
            onTap: () => _pickAndUploadPhoto(context, ref),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: _C.bluePale,
                  backgroundImage: user.profilePictureUrl != null
                      ? NetworkImage(resolveAvatarUrl(user.profilePictureUrl)!)
                      : null,
                  child: user.profilePictureUrl == null
                      ? Text(_avatarLetter(user),
                          style: const TextStyle(
                              fontSize: 36,
                              color: _C.slateBlue,
                              fontWeight: FontWeight.w800))
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: _C.slateBlue, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt,
                        size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('${user.firstName} ${user.lastName}',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _C.ink)),
          const SizedBox(height: 2),
          Text(user.email,
              style: const TextStyle(fontSize: 13, color: _C.inkSoft)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
                color: _C.bluePale, borderRadius: BorderRadius.circular(20)),
            child: const Text('老师 · Teacher',
                style: TextStyle(
                    fontSize: 12,
                    color: _C.slateBlue,
                    fontWeight: FontWeight.w700)),
          ),
        ])),
        const SizedBox(height: 24),

        // Stats
        Row(children: [
          _TEacherProfileStat('$totalSessions', 'Sessions\n总课程'),
          const SizedBox(width: 12),
          _TEacherProfileStat(user.email, 'Email\n邮箱'),
        ]),
        const SizedBox(height: 24),

        // Settings
        _TProfileSection('Teaching', '教学', [
          _TProfileTile(
            Icons.folder_copy_outlined,
            'Learning Modules',
            '教学资料',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ModulesScreen(currentUser: user)),
            ),
          ),
          _TProfileTile(
            Icons.edit_outlined,
            'Edit Bio & Subjects',
            '编辑简介',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditBioSubjectsScreen()),
            ),
          ),
          _TProfileTile(
            Icons.schedule_outlined,
            'Set Availability',
            '设置空闲时间',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SetAvailabilityScreen()),
            ),
          ),
          _TProfileTile(
            Icons.diamond_outlined,
            'Credits Per Session',
            '每节课积分',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CreditsPerSessionScreen()),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _TProfileSection('Account', '账户', [
          _TProfileTile(
            Icons.lock_outline,
            'Change Password',
            '修改密码',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          _TProfileTile(
              Icons.notifications_outlined, 'Notifications', '通知', () {}),
        ]),
        const SizedBox(height: 24),

        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Sign Out · 退出登录'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _C.burgundy,
            side: const BorderSide(color: _C.blushPink, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED TEACHER WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _StatsHero extends StatelessWidget {
  final List<dynamic> bookings;
  const _StatsHero({required this.bookings});
  @override
  Widget build(BuildContext context) {
    final total = bookings.length;
    final completed = bookings.where((b) => b['status'] == 'completed').length;
    final upcoming = bookings.where((b) => b['status'] == 'confirmed').length;
    final credits = bookings
        .where((b) => b['status'] == 'completed')
        .fold<int>(0, (s, b) => s + (b['credits_cost'] as int? ?? 0));

    return Row(children: [
      _MiniStat('$total', 'Total\n总计', _C.slateBlue, _C.bluePale),
      const SizedBox(width: 10),
      _MiniStat('$completed', 'Done\n已完成', _C.green, _C.greenPale),
      const SizedBox(width: 10),
      _MiniStat('$upcoming', 'Soon\n即将', _C.magenta, const Color(0xFFF9E1EA)),
      const SizedBox(width: 10),
      _MiniStat('$credits', 'Credits\n积分', const Color(0xFFE08AB2),
          const Color(0xFFFDE8F3)),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  final String value, label;
  final Color color, pale;
  const _MiniStat(this.value, this.label, this.color, this.pale);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: pale, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 9,
                    color: _C.inkSoft,
                    fontWeight: FontWeight.w600,
                    height: 1.3)),
          ]),
        ),
      );
}

class _TNextSessionBanner extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _TNextSessionBanner({required this.booking});
  @override
  Widget build(BuildContext context) {
    final dt = DateTime.parse(booking['scheduled_at']).toLocal();
    final name = (booking['student_name'] as String?) ?? 'Student';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.bluePale,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.slateBlue.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: _C.slateBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.video_call_rounded,
              color: _C.slateBlue, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Next Session · 下一节课',
              style: TextStyle(
                  fontSize: 11,
                  color: _C.slateBlue,
                  fontWeight: FontWeight.w700)),
          Text('with $name',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _C.ink)),
          Text(
              '${dt.day}/${dt.month}  '
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12, color: _C.inkSoft)),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: _C.slateBlue),
      ]),
    );
  }
}

class _TBookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool showComplete;
  final WidgetRef? ref;
  const _TBookingCard(
      {required this.booking, required this.showComplete, required this.ref});

  Future<void> _complete(BuildContext context) async {
    final repo = ref!.read(_tRepoProvider);
    final token = await repo.getAccessToken();
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/bookings/${booking['id']}/complete'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.statusCode == 200 ? 'Session completed ✓' : 'Failed'),
        backgroundColor: res.statusCode == 200 ? _C.green : _C.burgundy,
      ));
      if (res.statusCode == 200) ref!.invalidate(_tBookingsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (booking['student_name'] as String?) ?? 'Student';
    final status = booking['status'] as String;
    final dt = DateTime.parse(booking['scheduled_at']).toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _C.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.line)),
      child: Row(children: [
        CircleAvatar(
            radius: 20,
            backgroundColor: _C.softPink,
            child: Text(name.isNotEmpty ? name[0] : '?',
                style: const TextStyle(
                    color: _C.magenta, fontWeight: FontWeight.w800))),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _C.ink)),
          const SizedBox(height: 2),
          Text(
              '${dt.day}/${dt.month}/${dt.year}  '
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
          Text(
              '${booking['credits_cost']} credits · ${booking['duration_mins']} min',
              style: const TextStyle(
                  fontSize: 11,
                  color: _C.slateBlue,
                  fontWeight: FontWeight.w600)),
        ])),
        if (showComplete && status == 'confirmed')
          GestureDetector(
            onTap: () => _complete(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: _C.green, borderRadius: BorderRadius.circular(20)),
              child: const Text('Done',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: (status == 'completed' ? _C.green : _C.inkSoft)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Text(status,
                style: TextStyle(
                    fontSize: 10,
                    color: status == 'completed' ? _C.green : _C.inkSoft,
                    fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }
}

class _TScheduleCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _TScheduleCard({required this.booking});
  @override
  Widget build(BuildContext context) {
    final name = (booking['student_name'] as String?) ?? 'Student';
    final dt = DateTime.parse(booking['scheduled_at']).toLocal();
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _C.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.line)),
      child: Row(children: [
        SizedBox(
          width: 48,
          child: Column(children: [
            Text(dayNames[(dt.weekday - 1) % 7],
                style: const TextStyle(
                    fontSize: 11,
                    color: _C.inkSoft,
                    fontWeight: FontWeight.w600)),
            Text('${dt.day}',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _C.slateBlue)),
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
                  fontSize: 13, fontWeight: FontWeight.w700, color: _C.ink)),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.access_time_outlined, size: 12, color: _C.inkSoft),
            const SizedBox(width: 4),
            Text(
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}  '
                '· ${booking['duration_mins']} min',
                style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
          ]),
          Row(children: [
            const Icon(Icons.diamond_outlined, size: 12, color: _C.slateBlue),
            const SizedBox(width: 4),
            Text('${booking['credits_cost']} credits',
                style: const TextStyle(
                    fontSize: 11,
                    color: _C.slateBlue,
                    fontWeight: FontWeight.w600)),
          ]),
        ])),
      ]),
    );
  }
}

class _EarningRow extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _EarningRow({required this.booking});
  @override
  Widget build(BuildContext context) {
    final name = (booking['student_name'] as String?) ?? 'Student';
    final credits = booking['credits_cost'] as int? ?? 0;
    final dt = DateTime.parse(booking['scheduled_at']).toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: _C.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.line)),
      child: Row(children: [
        CircleAvatar(
            radius: 16,
            backgroundColor: _C.bluePale,
            child: Text(name.isNotEmpty ? name[0] : '?',
                style: const TextStyle(
                    color: _C.slateBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 12))),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _C.ink)),
          Text('${dt.day}/${dt.month}/${dt.year}',
              style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: _C.bluePale, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.diamond_outlined, size: 12, color: _C.slateBlue),
            const SizedBox(width: 4),
            Text('+$credits',
                style: const TextStyle(
                    fontSize: 12,
                    color: _C.slateBlue,
                    fontWeight: FontWeight.w800)),
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
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: pale, borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: _C.inkSoft,
                    fontWeight: FontWeight.w600,
                    height: 1.4)),
          ]),
        ),
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
          color: isToday ? _C.slateBlue : _C.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isToday ? _C.slateBlue : _C.line),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(dayName,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isToday ? Colors.white70 : _C.inkSoft)),
          const SizedBox(height: 2),
          Text('${day.day}',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isToday ? Colors.white : _C.ink)),
          if (hasSession)
            Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                    color: isToday ? Colors.white : _C.magenta,
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
                fontSize: 15, fontWeight: FontWeight.w800, color: _C.ink)),
        if (zh != null) ...[
          const SizedBox(width: 5),
          Text('· $zh',
              style: const TextStyle(
                  fontSize: 12,
                  color: _C.slateBlue,
                  fontWeight: FontWeight.w600)),
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
            color: _C.bluePale, borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          const Icon(Icons.calendar_today_outlined,
              size: 36, color: _C.slateBlue),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _C.ink)),
          Text('· $titleCn',
              style: const TextStyle(fontSize: 12, color: _C.slateBlue)),
        ]),
      );
}

class _TEacherProfileStat extends StatelessWidget {
  final String value, label;
  const _TEacherProfileStat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: _C.bluePale, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _C.slateBlue)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10,
                    color: _C.inkSoft,
                    fontWeight: FontWeight.w600,
                    height: 1.4)),
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
                      fontWeight: FontWeight.w700,
                      color: _C.inkSoft)),
              const SizedBox(width: 5),
              Text('· $zh',
                  style: const TextStyle(fontSize: 12, color: _C.slateBlue)),
            ]),
          ),
          Container(
            decoration: BoxDecoration(
                color: _C.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _C.line)),
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
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: _C.inkSoft, size: 20),
          title: Text('$label · $labelCn',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _C.ink)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded,
              size: 13, color: _C.inkSoft),
          dense: true,
        ),
      );
}
