// lib/features/dashboard/student_dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../auth/controllers/auth_controller.dart';
import '../auth/repositories/auth_repository.dart';
import '../../models/user.dart';

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

// ── Providers ─────────────────────────────────────────────────────────────────
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

final _sTeachersProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(_sRepoProvider);
  final token = await repo.getAccessToken();
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/teachers?limit=6'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (res.statusCode != 200) return [];
  return jsonDecode(res.body) as List;
});

final _sRewardsProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(_sRepoProvider);
  final token = await repo.getAccessToken();
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/admin/rewards'),
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
              _HomeTab(user: user),
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
      decoration: BoxDecoration(
        color: _C.paper,
        border: Border(top: BorderSide(color: _C.line, width: 1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
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
  const _HomeTab({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_sBookingsProvider);
    final teachersAsync = ref.watch(_sTeachersProvider);

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
                en: 'Featured Teachers', zh: '推荐老师', onSeeAll: () {}),
          ),
        ),
        SliverToBoxAdapter(
          child: teachersAsync.when(
            loading: () => const SizedBox(
                height: 140,
                child: Center(
                    child: CircularProgressIndicator(color: _C.magenta))),
            error: (_, __) => const SizedBox.shrink(),
            data: (teachers) => _TeacherCarousel(teachers: teachers),
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
                if (recent.isEmpty)
                  return _EmptyCard(
                    icon: Icons.calendar_today_outlined,
                    title: 'No sessions yet',
                    titleCn: '暂无课程',
                    subtitle: 'Book a session with a teacher to get started.',
                  );
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
          child: Text(user.firstName[0].toUpperCase(),
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
        boxShadow: [
          BoxShadow(
              color: _C.magenta.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
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
    final teachersAsync = ref.watch(_sTeachersProvider);

    return Column(children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Row(children: [
          const Expanded(
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
      // Search bar
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
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
      // Subject filter chips
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
      // Teacher grid
      Expanded(
        child: teachersAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _C.magenta)),
          error: (e, _) => Center(child: Text('$e')),
          data: (teachers) {
            final filtered = teachers.where((t) {
              final q = _searchCtrl.text.toLowerCase();
              final name = '${t['first_name']} ${t['last_name']}'.toLowerCase();
              final subjects =
                  (t['subjects'] as List?)?.join(' ').toLowerCase() ?? '';
              final matchSearch =
                  q.isEmpty || name.contains(q) || subjects.contains(q);
              final matchSubject = _selected == 'All' ||
                  (t['subjects'] as List?)?.contains(_selected) == true;
              return matchSearch && matchSubject;
            }).toList();

            if (filtered.isEmpty)
              return _EmptyCard(
                icon: Icons.person_search_outlined,
                title: 'No teachers found',
                titleCn: '未找到老师',
                subtitle: 'Try a different subject or search term.',
              );

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: filtered.length,
              itemBuilder: (_, i) => _TeacherCard(teacher: filtered[i]),
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
            if (bookings.isEmpty)
              return Center(
                  child: _EmptyCard(
                icon: Icons.calendar_today_outlined,
                title: 'No sessions yet',
                titleCn: '暂无课程',
                subtitle: 'Book a session to get started.',
              ));
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
                  _GroupLabel(label: 'Upcoming · 即将上课'),
                  ...upcoming.map((b) => _BookingCard(booking: b)),
                  const SizedBox(height: 16),
                ],
                if (past.isNotEmpty) ...[
                  _GroupLabel(label: 'Past · 历史课程'),
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
class _ProfileTab extends StatelessWidget {
  final UserModel user;
  final VoidCallback onLogout;
  const _ProfileTab({required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        // Avatar
        Center(
            child: Column(children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: _C.blushPink,
            child: Text(user.firstName[0].toUpperCase(),
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
          _ProfileTile(Icons.person_outline, 'Edit Profile', '编辑资料', () {}),
          _ProfileTile(Icons.lock_outline, 'Change Password', '修改密码', () {}),
          _ProfileTile(Icons.phone_outlined, 'Phone Number', '手机号码', () {}),
        ]),
        const SizedBox(height: 16),
        _ProfileSection('Preferences', '偏好', [
          _ProfileTile(Icons.language, 'Language', '语言', () {}),
          _ProfileTile(
              Icons.notifications_outlined, 'Notifications', '通知', () {}),
        ]),
        const SizedBox(height: 16),
        _ProfileSection('Support', '支持', [
          _ProfileTile(Icons.help_outline, 'Help Center', '帮助中心', () {}),
          _ProfileTile(
              Icons.privacy_tip_outlined, 'Privacy Policy', '隐私政策', () {}),
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

class _NextSessionBanner extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _NextSessionBanner({required this.booking});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.parse(booking['scheduled_at']).toLocal();
    final name = '${booking['teacher_first']} ${booking['teacher_last']}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.greenPale,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.green.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: _C.green.withOpacity(0.15),
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

class _TeacherCarousel extends StatelessWidget {
  final List<dynamic> teachers;
  const _TeacherCarousel({required this.teachers});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: teachers.length,
        itemBuilder: (_, i) {
          final t = teachers[i];
          final name = '${t['first_name']} ${t['last_name']}';
          final subjects = (t['subjects'] as List?)?.take(2).join(', ') ?? '';
          final rating = (t['rating'] ?? 0).toStringAsFixed(1);
          return Container(
            width: 130,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _C.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _C.line),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(
                    radius: 18,
                    backgroundColor: _C.blushPink,
                    child: Text(name[0],
                        style: const TextStyle(
                            color: _C.burgundy, fontWeight: FontWeight.w800))),
                const Spacer(),
                const Icon(Icons.star_rounded,
                    color: Color(0xFFFFC107), size: 14),
                const SizedBox(width: 2),
                Text(rating,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _C.ink)),
              ]),
              const SizedBox(height: 10),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _C.ink)),
              const SizedBox(height: 3),
              Text(subjects,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: _C.inkSoft)),
              const Spacer(),
              Row(children: [
                const Icon(Icons.diamond_outlined, size: 11, color: _C.magenta),
                const SizedBox(width: 3),
                Text('${t['credits_per_session']} credits',
                    style: const TextStyle(
                        fontSize: 10,
                        color: _C.magenta,
                        fontWeight: FontWeight.w700)),
              ]),
            ]),
          );
        },
      ),
    );
  }
}

class _TeacherCard extends StatelessWidget {
  final Map<String, dynamic> teacher;
  const _TeacherCard({required this.teacher});

  @override
  Widget build(BuildContext context) {
    final name = '${teacher['first_name']} ${teacher['last_name']}';
    final subjects = (teacher['subjects'] as List?)?.take(3).join(' · ') ?? '';
    final rating = (teacher['rating'] ?? 0).toStringAsFixed(1);
    final sessions = teacher['total_sessions'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
              radius: 22,
              backgroundColor: _C.blushPink,
              child: Text(name[0],
                  style: const TextStyle(
                      color: _C.burgundy,
                      fontWeight: FontWeight.w800,
                      fontSize: 16))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.star_rounded,
                  color: Color(0xFFFFC107), size: 12),
              const SizedBox(width: 2),
              Text(rating,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7A5C00))),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Text(name,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: _C.ink)),
        const SizedBox(height: 3),
        Text(subjects,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
        const Spacer(),
        Row(children: [
          const Icon(Icons.diamond_outlined, size: 12, color: _C.magenta),
          const SizedBox(width: 4),
          Text('${teacher['credits_per_session']} / session',
              style: const TextStyle(
                  fontSize: 11,
                  color: _C.magenta,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        Text('$sessions sessions',
            style: const TextStyle(fontSize: 10, color: _C.inkSoft)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.magenta,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
              textStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            child: const Text('Book Now · 预约'),
          ),
        ),
      ]),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final name = '${booking['teacher_first']} ${booking['teacher_last']}';
    final status = booking['status'] as String;
    final dt = DateTime.parse(booking['scheduled_at']).toLocal();
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
            child: Text(name[0],
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
              '${booking['credits_cost']} credits · ${booking['duration_mins']} min',
              style: const TextStyle(
                  fontSize: 11,
                  color: _C.magenta,
                  fontWeight: FontWeight.w600)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
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
        border:
            Border.all(color: unlocked ? _C.green.withOpacity(0.3) : _C.line),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: unlocked ? _C.green.withOpacity(0.15) : _C.softPink,
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
                    color: _C.magenta.withOpacity(0.8),
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
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Icon(icon, color: _C.inkSoft, size: 20),
        title: Text('$label · $labelCn',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _C.ink)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 13, color: _C.inkSoft),
        dense: true,
      );
}
