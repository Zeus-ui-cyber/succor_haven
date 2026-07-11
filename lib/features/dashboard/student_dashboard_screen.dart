// lib/features/dashboard/student_dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../auth/controllers/auth_controller.dart';
import '../auth/repositories/auth_repository.dart';
import '../../models/user.dart';
import '../../models/teacher_profile.dart';
import '../booking/controllers/booking_controller.dart';
import '../booking/widgets/teacher_card.dart';
import '../booking/utils/avatar_url.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
class _C {
  static const magenta = Color(0xFFD64577);
  static const burgundy = Color(0xFF7D002B);
  static const blushPink = Color(0xFFF2C6D6);
  static const softPink = Color(0xFFF9E1EA);
  static const slateBlue = Color(0xFF3E678A);
  static const mauve = Color(0xFFE08AB2);
  static const cream = Color(0xFFFFF5F7);
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
  static const line = Color(0xFFF0DCE5);
  static const paper = Color(0xFFFFFFFF);
  static const green = Color(0xFF00C48C);
  static const greenPale = Color(0xFFDCF7EE);
}

// Guards against an empty firstName string (e.g. a malformed/blank name
// somehow slipping through) crashing on ''[0]. Cheap safety net matching
// the _initials() pattern used across the admin screens this session.
String _avatarLetter(UserModel user) {
  final f = user.firstName.trim();
  if (f.isNotEmpty) return f[0].toUpperCase();
  final l = user.lastName.trim();
  if (l.isNotEmpty) return l[0].toUpperCase();
  return '?';
}

// ── Providers ─────────────────────────────────────────────────────────────────
// NOTE: the old `_sTeachersProvider` here parsed raw `/teachers` JSON as
// `first_name`/`last_name`/`credits_per_session` — none of those fields
// exist anymore (teachers.controller.js returns `full_name`, and pricing
// moved off teacher_profiles entirely). It's been removed in favor of
// `teachersListProvider` from booking_controller.dart, which goes through
// `BookingRepository` + `TeacherProfileModel.fromJson` and parses the
// *actual* current API shape. That's also why the teacher list/carousel
// was rendering empty before.
final _sRepoProvider = Provider((_) => AuthRepository());

final _sMeProvider =
    FutureProvider<UserModel>((ref) => ref.read(_sRepoProvider).getMe());

final _sBookingsProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(_sRepoProvider);
  final token = await repo.getAccessToken();
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/bookings'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (res.statusCode != 200) return [];
  return jsonDecode(res.body) as List;
});

// ⚠️ FIXED: this previously hit /admin/rewards, which requires
// requireRole("admin") server-side — every student request got a 403
// Forbidden (visible in the debug console screenshots throughout this
// session). Points to the new /rewards route (added to routes/index.js,
// reusing adminCtrl.listRewards without the admin gate — it's a read-only
// SELECT, safe to expose to any authenticated user).
final _sRewardsProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(_sRepoProvider);
  final token = await repo.getAccessToken();
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/rewards'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (res.statusCode != 200) return [];
  return jsonDecode(res.body) as List;
});

// ═══════════════════════════════════════════════════════════════════════════════
class StudentDashboard extends ConsumerStatefulWidget {
  const StudentDashboard({super.key});
  @override
  ConsumerState<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<StudentDashboard> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(_sMeProvider);

    return meAsync.when(
      loading: () => const Scaffold(
        backgroundColor: _C.cream,
        body: Center(child: CircularProgressIndicator(color: _C.magenta)),
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
              _HomeTab(user: user, onSeeAllTeachers: () => setState(() => _navIndex = 1)),
              _FindTeachersTab(user: user),
              _SessionsTab(user: user),
              _RewardsTab(user: user),
              _ProfileTab(user: user, onLogout: _logout),
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
      (Icons.search_rounded, Icons.search_outlined, 'Teachers', '老师'),
      (
        Icons.calendar_month_rounded,
        Icons.calendar_month_outlined,
        'Sessions',
        '课程'
      ),
      (
        Icons.emoji_events_rounded,
        Icons.emoji_events_outlined,
        'Rewards',
        '奖励'
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
                    color: active ? _C.blushPink : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(active ? item.$1 : item.$2,
                        color: active ? _C.magenta : _C.inkSoft, size: 22),
                    const SizedBox(height: 2),
                    Text(active ? item.$3 : item.$4,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: active ? _C.magenta : _C.inkSoft,
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

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }
}

// ── HOME TAB ──────────────────────────────────────────────────────────────────
class _HomeTab extends ConsumerWidget {
  final UserModel user;
  final VoidCallback onSeeAllTeachers;
  const _HomeTab({required this.user, required this.onSeeAllTeachers});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_sBookingsProvider);
    // Real teacher directory, backed by BookingRepository + TeacherProfileModel.
    final teachersAsync = ref.watch(teachersListProvider);

    return CustomScrollView(
      slivers: [
        // ── Header ────────────────────────────────────────────────────────
        SliverToBoxAdapter(child: _buildHeader(context)),

        // ── Hero credits + points ─────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          sliver: SliverToBoxAdapter(child: _buildHeroCard()),
        ),

        // ── Points progress ───────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver:
              SliverToBoxAdapter(child: _PointsProgress(points: user.points)),
        ),

        // ── Next session banner ───────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(
            child: bookingsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (bookings) {
                final next =
                    bookings.where((b) => b['status'] == 'confirmed').toList();
                if (next.isEmpty) return const SizedBox.shrink();
                return _NextSessionBanner(booking: next.first);
              },
            ),
          ),
        ),

        // ── Featured teachers ─────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 0, 8),
          sliver: SliverToBoxAdapter(
            child: _SectionRow(
                en: 'Featured Teachers', zh: '推荐老师', onSeeAll: onSeeAllTeachers),
          ),
        ),
        SliverToBoxAdapter(
          child: teachersAsync.when(
            loading: () => const SizedBox(
                height: 160,
                child: Center(
                    child: CircularProgressIndicator(color: _C.magenta))),
            error: (e, _) => SizedBox(
              height: 100,
              child: Center(
                child: Text('Could not load teachers: $e',
                    style: const TextStyle(fontSize: 12, color: _C.inkSoft)),
              ),
            ),
            data: (teachers) => _TeacherCarousel(
              teachers: teachers.take(6).toList(),
              onSeeAll: onSeeAllTeachers,
            ),
          ),
        ),

        // ── Recent sessions ───────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          sliver: SliverToBoxAdapter(
            child:
                _SectionRow(en: 'Recent Sessions', zh: '最近课程', onSeeAll: () {}),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverToBoxAdapter(
            child: bookingsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: _C.magenta)),
              error: (e, _) => Text('$e'),
              data: (bookings) {
                final recent = bookings.take(3).toList();
                if (recent.isEmpty) {
                  return const _EmptyCard(
                    icon: Icons.calendar_today_outlined,
                    title: 'No sessions yet',
                    titleCn: '暂无课程',
                    subtitle: 'Book a session with a teacher to get started.',
                  );
                }
                return Column(
                    children:
                        recent.map((b) => _BookingCard(booking: b)).toList());
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: _C.blushPink,
          child: Text(_avatarLetter(user),
              style: const TextStyle(
                  color: _C.burgundy,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hi, ${user.firstName}! 👋',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _C.ink)),
          const Text('学生 · Student',
              style: TextStyle(fontSize: 11, color: _C.inkSoft)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _C.blushPink,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.diamond_outlined, color: _C.magenta, size: 14),
            const SizedBox(width: 4),
            Text('${user.credits} credits',
                style: const TextStyle(
                    fontSize: 11,
                    color: _C.magenta,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.burgundy, _C.magenta],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Credits · 积分',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${user.credits}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          const Text('spendable on sessions',
              style: TextStyle(color: Colors.white60, fontSize: 11)),
        ])),
        Container(width: 1, height: 60, color: Colors.white24),
        const SizedBox(width: 20),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Points · 奖励点',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${user.points}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          const Text('earn by completing sessions',
              style: TextStyle(color: Colors.white60, fontSize: 11)),
        ])),
      ]),
    );
  }
}

// ── FIND TEACHERS TAB ─────────────────────────────────────────────────────────
// Now driven entirely by teachersListProvider / teacherSearchQueryProvider
// (booking_controller.dart), which hits the real GET /teachers endpoint via
// BookingRepository. Server does the search filtering; the subject chips
// filter client-side over whatever page is loaded.
class _FindTeachersTab extends ConsumerStatefulWidget {
  final UserModel user;
  const _FindTeachersTab({required this.user});
  @override
  ConsumerState<_FindTeachersTab> createState() => _FindTeachersTabState();
}

class _FindTeachersTabState extends ConsumerState<_FindTeachersTab> {
  final _searchCtrl = TextEditingController();
  String _selected = 'All';
  final subjects = [
    'All',
    'English',
    'Mandarin',
    'Korean',
    'Math',
    'Business',
    'IELTS'
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(teachersListProvider);

    return Column(children: [
      // Header
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Find Teachers',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _C.ink)),
                Text('找老师',
                    style: TextStyle(
                        fontSize: 12,
                        color: _C.magenta,
                        fontWeight: FontWeight.w600)),
              ])),
        ]),
      ),
      // Search bar — pushes into teacherSearchQueryProvider, which
      // teachersListProvider watches and re-fetches from the server on.
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) =>
              ref.read(teacherSearchQueryProvider.notifier).state = v,
          decoration: InputDecoration(
            hintText: 'Search teachers...',
            prefixIcon: const Icon(Icons.search, color: _C.inkSoft, size: 20),
            filled: true,
            fillColor: _C.softPink,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
      ),
      const SizedBox(height: 12),
      // Subject filter chips (client-side, over the current page of results)
      SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: subjects.length,
          itemBuilder: (_, i) {
            final s = subjects[i];
            final active = s == _selected;
            return GestureDetector(
              onTap: () => setState(() => _selected = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? _C.magenta : _C.paper,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? _C.magenta : _C.line),
                ),
                child: Text(s,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : _C.inkSoft)),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      // Teacher list — TeacherProfileModel objects, TeacherCard widget.
      Expanded(
        child: teachersAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _C.magenta)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load teachers: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: _C.inkSoft)),
            ),
          ),
          data: (teachers) {
            final filtered = _selected == 'All'
                ? teachers
                : teachers
                    .where((t) => t.subjects.contains(_selected))
                    .toList();

            if (filtered.isEmpty) {
              return const _EmptyCard(
                icon: Icons.person_search_outlined,
                title: 'No teachers found',
                titleCn: '未找到老师',
                subtitle: 'Try a different subject or search term.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              itemCount: filtered.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TeacherCard(
                  teacher: filtered[i],
                  onDetails: () => Navigator.pushNamed(
                    context,
                    '/teachers/${filtered[i].id}',
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ── SESSIONS TAB ──────────────────────────────────────────────────────────────
class _SessionsTab extends ConsumerWidget {
  final UserModel user;
  const _SessionsTab({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_sBookingsProvider);

    return Column(children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('My Sessions',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: _C.ink)),
            Text('我的课程',
                style: TextStyle(
                    fontSize: 12,
                    color: _C.magenta,
                    fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
      Expanded(
        child: bookingsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _C.magenta)),
          error: (e, _) => Center(child: Text('$e')),
          data: (bookings) {
            if (bookings.isEmpty) {
              return const Center(
                  child: _EmptyCard(
                icon: Icons.calendar_today_outlined,
                title: 'No sessions yet',
                titleCn: '暂无课程',
                subtitle: 'Book a session to get started.',
              ));
            }
            // Group: upcoming / past
            final upcoming = bookings
                .where((b) =>
                    b['status'] == 'confirmed' || b['status'] == 'pending')
                .toList();
            final past = bookings
                .where((b) =>
                    b['status'] == 'completed' || b['status'] == 'cancelled')
                .toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                if (upcoming.isNotEmpty) ...[
                  const _GroupLabel(label: 'Upcoming · 即将上课'),
                  ...upcoming.map((b) => _BookingCard(booking: b)),
                  const SizedBox(height: 16),
                ],
                if (past.isNotEmpty) ...[
                  const _GroupLabel(label: 'Past · 历史课程'),
                  ...past.map((b) => _BookingCard(booking: b)),
                ],
              ],
            );
          },
        ),
      ),
    ]);
  }
}

// ── REWARDS TAB ───────────────────────────────────────────────────────────────
class _RewardsTab extends ConsumerWidget {
  final UserModel user;
  const _RewardsTab({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(_sRewardsProvider);

    return Column(children: [
      // Points hero
      Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF7D002B), Color(0xFFD64577)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your Points · 您的积分',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('${user.points}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _PointsProgress(points: user.points),
        ]),
      ),
      const SizedBox(height: 20),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Text('Milestone Rewards',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: _C.ink)),
          SizedBox(width: 6),
          Text('· 里程碑奖励',
              style: TextStyle(
                  fontSize: 12,
                  color: _C.magenta,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: rewardsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _C.magenta)),
          error: (_, __) => const SizedBox.shrink(),
          data: (rewards) => ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            itemCount: rewards.length,
            itemBuilder: (_, i) =>
                _RewardTile(reward: rewards[i], currentPoints: user.points),
          ),
        ),
      ),
    ]);
  }
}

// ── PROFILE TAB ───────────────────────────────────────────────────────────────
// NOTE: ConsumerWidget so it can invalidate _sMeProvider after Edit Profile /
// Language saves, and so it can Navigator.pushNamed to routes in main.dart.
class _ProfileTab extends ConsumerWidget {
  final UserModel user;
  final VoidCallback onLogout;
  const _ProfileTab({required this.user, required this.onLogout});

  Future<void> _openEditProfile(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.pushNamed(
      context,
      '/settings/edit-profile',
      arguments: user,
    );
    // EditProfileScreen does Navigator.pop(context, true) on success —
    // refresh the cached profile (first/last name, avatar, etc.) so the
    // dashboard reflects the change immediately.
    if (result == true) {
      ref.invalidate(_sMeProvider);
    }
  }

  void _openChangePassword(BuildContext context) {
    // No arguments needed — backend identifies the user via JWT.
    Navigator.pushNamed(context, '/settings/change-password');
  }

  void _openPhoneSettings(BuildContext context) {
    // No arguments needed — backend identifies the user via JWT.
    Navigator.pushNamed(context, '/settings/phone');
  }

  Future<void> _openLanguageSettings(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.pushNamed(
      context,
      '/settings/language',
      arguments: user.languagePref,
    );
    // LanguageSettingsScreen pops with the new language code on success —
    // refresh the cached profile so the UI reflects the change.
    if (result != null) {
      ref.invalidate(_sMeProvider);
    }
  }

  void _openNotificationSettings(BuildContext context) {
    Navigator.pushNamed(context, '/settings/notifications');
  }

  void _openHelpCenter(BuildContext context) {
    Navigator.pushNamed(context, '/settings/help-center');
  }

  void _openPrivacyPolicy(BuildContext context) {
    Navigator.pushNamed(context, '/settings/privacy-policy');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        // Avatar
        Center(
            child: Column(children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: _C.blushPink,
            child: Text(_avatarLetter(user),
                style: const TextStyle(
                    fontSize: 36,
                    color: _C.burgundy,
                    fontWeight: FontWeight.w800)),
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
                color: _C.blushPink, borderRadius: BorderRadius.circular(20)),
            child: const Text('学生 · Student',
                style: TextStyle(
                    fontSize: 12,
                    color: _C.magenta,
                    fontWeight: FontWeight.w700)),
          ),
        ])),
        const SizedBox(height: 28),
        // Stats row
        Row(children: [
          _ProfileStat(
              '${user.credits}', 'Credits\n积分', _C.magenta, _C.blushPink),
          const SizedBox(width: 12),
          _ProfileStat('${user.points}', 'Points\n奖励点', _C.slateBlue,
              const Color(0xFFDCEBF5)),
        ]),
        const SizedBox(height: 24),
        // Settings list
        _ProfileSection('Account', '账户', [
          _ProfileTile(
            Icons.person_outline,
            'Edit Profile',
            '编辑资料',
            () => _openEditProfile(context, ref),
          ),
          _ProfileTile(
            Icons.lock_outline,
            'Change Password',
            '修改密码',
            () => _openChangePassword(context),
          ),
          _ProfileTile(
            Icons.phone_outlined,
            'Phone Number',
            '手机号码',
            () => _openPhoneSettings(context),
          ),
        ]),
        const SizedBox(height: 16),
        _ProfileSection('Preferences', '偏好', [
          _ProfileTile(
            Icons.language,
            'Language',
            '语言',
            () => _openLanguageSettings(context, ref),
          ),
          _ProfileTile(
            Icons.notifications_outlined,
            'Notifications',
            '通知',
            () => _openNotificationSettings(context),
          ),
        ]),
        const SizedBox(height: 16),
        _ProfileSection('Support', '支持', [
          _ProfileTile(
            Icons.help_outline,
            'Help Center',
            '帮助中心',
            () => _openHelpCenter(context),
          ),
          _ProfileTile(
            Icons.privacy_tip_outlined,
            'Privacy Policy',
            '隐私政策',
            () => _openPrivacyPolicy(context),
          ),
        ]),
        const SizedBox(height: 24),
        // Logout
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
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _PointsProgress extends StatelessWidget {
  final int points;
  const _PointsProgress({required this.points});
  static const milestones = [50, 100, 200, 500];

  @override
  Widget build(BuildContext context) {
    final next = milestones.firstWhere((m) => m > points, orElse: () => 500);
    final prev = milestones.lastWhere((m) => m <= points, orElse: () => 0);
    final progress = next == prev ? 1.0 : (points - prev) / (next - prev);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('🏆', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text('$points / $next pts to next reward',
            style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation(Colors.white),
        ),
      ),
    ]);
  }
}

// ⚠️ FIXED: bookings.controller.js returns `teacher_name` (a single joined
// full_name column) and `teacher_avatar`, not `teacher_first`/`teacher_last`
// — those never existed on the response and always evaluated to "null null".
class _NextSessionBanner extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _NextSessionBanner({required this.booking});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.parse(booking['scheduled_at']).toLocal();
    final name = (booking['teacher_name'] as String?) ?? 'Your teacher';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.greenPale,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.green.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: _C.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12)),
          child:
              const Icon(Icons.video_call_rounded, color: _C.green, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Next Session · 下一节课',
              style: TextStyle(
                  fontSize: 11, color: _C.green, fontWeight: FontWeight.w700)),
          Text('with $name',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _C.ink)),
          Text(
              '${dt.day}/${dt.month}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12, color: _C.inkSoft)),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _C.green),
      ]),
    );
  }
}

// Home tab carousel — now consumes real TeacherProfileModel objects. No more
// `credits_per_session` (removed from teacher_profiles; pricing lives in the
// `pricing` table and is chosen at booking time, not shown per-teacher here).
class _TeacherCarousel extends StatelessWidget {
  final List<TeacherProfileModel> teachers;
  final VoidCallback onSeeAll;
  const _TeacherCarousel({required this.teachers, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    if (teachers.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text('No teachers available yet',
              style: TextStyle(fontSize: 12, color: _C.inkSoft)),
        ),
      );
    }
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: teachers.length,
        itemBuilder: (_, i) {
          final t = teachers[i];
          final avatarUrl = resolveAvatarUrl(t.avatarUrl);
          final subjectsPreview = t.subjects.take(2).join(', ');
          return GestureDetector(
            onTap: () =>
                Navigator.pushNamed(context, '/teachers/${t.id}'),
            child: Container(
              width: 130,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _C.paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _C.line),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: _C.blushPink,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(t.initials.characters.first,
                                style: const TextStyle(
                                    color: _C.burgundy,
                                    fontWeight: FontWeight.w800))
                            : null,
                      ),
                      const Spacer(),
                      if (t.hasRating) ...[
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFFC107), size: 14),
                        const SizedBox(width: 2),
                        Text(t.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _C.ink)),
                      ],
                    ]),
                    const SizedBox(height: 10),
                    Text(t.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _C.ink)),
                    const SizedBox(height: 3),
                    Text(
                        subjectsPreview.isEmpty
                            ? 'No subjects listed'
                            : subjectsPreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: _C.inkSoft)),
                    const Spacer(),
                    Text(
                        t.isNewTeacher
                            ? 'New teacher'
                            : '${t.totalSessions} sessions',
                        style: const TextStyle(
                            fontSize: 10,
                            color: _C.magenta,
                            fontWeight: FontWeight.w700)),
                  ]),
            ),
          );
        },
      ),
    );
  }
}

// ⚠️ FIXED: `bookings` rows come back with `teacher_name` (single full_name
// column, per bookings.controller.js), not `teacher_first`/`teacher_last`.
// Also surfaces `pricing_name` / `session_type` now that those are joined in.
class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final name = (booking['teacher_name'] as String?) ?? 'Teacher';
    final status = booking['status'] as String;
    final dt = DateTime.parse(booking['scheduled_at']).toLocal();
    final pricingName = booking['pricing_name'] as String?;
    final statusColor = {
          'confirmed': _C.green,
          'completed': _C.slateBlue,
          'cancelled': _C.inkSoft,
          'pending': _C.mauve,
        }[status] ??
        _C.inkSoft;

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
            backgroundColor: _C.blushPink,
            child: Text(name.isNotEmpty ? name[0] : '?',
                style: const TextStyle(
                    color: _C.burgundy, fontWeight: FontWeight.w800))),
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
              [
                if (pricingName != null && pricingName.isNotEmpty) pricingName,
                '${booking['credits_cost']} credits · ${booking['duration_mins']} min',
              ].join(' · '),
              style: const TextStyle(
                  fontSize: 11,
                  color: _C.magenta,
                  fontWeight: FontWeight.w600)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20)),
          child: Text(status,
              style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

class _RewardTile extends StatelessWidget {
  final Map<String, dynamic> reward;
  final int currentPoints;
  const _RewardTile({required this.reward, required this.currentPoints});

  @override
  Widget build(BuildContext context) {
    final required = reward['points_required'] as int;
    final unlocked = currentPoints >= required;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unlocked ? _C.greenPale : _C.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: unlocked ? _C.green.withValues(alpha: 0.3) : _C.line),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: unlocked ? _C.green.withValues(alpha: 0.15) : _C.softPink,
              borderRadius: BorderRadius.circular(12)),
          child: Center(
              child: Text(
                  reward['reward_type'] == 'badge'
                      ? '🏅'
                      : reward['reward_type'] == 'credit'
                          ? '💎'
                          : '🎁',
                  style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(reward['name'],
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _C.ink)),
          Text(reward['description'] ?? '',
              style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
          const SizedBox(height: 4),
          Text('$required pts required',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: unlocked ? _C.green : _C.magenta)),
        ])),
        if (unlocked)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: _C.green, borderRadius: BorderRadius.circular(20)),
            child: const Text('Redeem',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
          )
        else
          Text('${required - currentPoints} more',
              style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
      ]),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final String en, zh;
  final VoidCallback onSeeAll;
  const _SectionRow(
      {required this.en, required this.zh, required this.onSeeAll});

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(en,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: _C.ink)),
        const SizedBox(width: 5),
        Text('· $zh',
            style: const TextStyle(
                fontSize: 12, color: _C.magenta, fontWeight: FontWeight.w600)),
        const Spacer(),
        GestureDetector(
          onTap: onSeeAll,
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text('See all',
                style: TextStyle(
                    fontSize: 12,
                    color: _C.magenta.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]);
}

class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: _C.inkSoft)),
      );
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title, titleCn, subtitle;
  const _EmptyCard(
      {required this.icon,
      required this.title,
      required this.titleCn,
      required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: _C.softPink, borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          Icon(icon, size: 40, color: _C.inkSoft),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _C.ink)),
          Text('· $titleCn',
              style: const TextStyle(fontSize: 12, color: _C.magenta)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: _C.inkSoft)),
        ]),
      );
}

class _ProfileStat extends StatelessWidget {
  final String value, label;
  final Color color, pale;
  const _ProfileStat(this.value, this.label, this.color, this.pale);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: pale, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w900, color: color)),
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

class _ProfileSection extends StatelessWidget {
  final String en, zh;
  final List<Widget> tiles;
  const _ProfileSection(this.en, this.zh, this.tiles);
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
                  style: const TextStyle(fontSize: 12, color: _C.magenta)),
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

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label, labelCn;
  final VoidCallback onTap;
  const _ProfileTile(this.icon, this.label, this.labelCn, this.onTap);
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