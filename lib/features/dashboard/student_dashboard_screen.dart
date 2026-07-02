// lib/features/dashboard/student_dashboard_screen.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../auth/controllers/auth_controller.dart';
import '../auth/repositories/auth_repository.dart';
import '../../models/user.dart';
import '../../models/booking.dart';
import '../../models/course.dart';

// ── Palette (premium navy / light pink) ───────────────────────────────────────
class _C {
  static const navy = Color(0xFF1B1F6B);         // primary
  static const navySoft = Color(0xFF33397F);
  static const pink = Color(0xFFE8A9C6);         // secondary
  static const pinkDeep = Color(0xFFD888AC);
  static const pinkGlow = Color(0xFFF6DCE8);

  // Remapped legacy names so every existing reference in this file
  // (bottom nav, chips, badges, cards, etc.) automatically picks up
  // the new navy/pink palette without touching those widgets.
  static const coral = Color(0xFFE8A9C6);
  static const coralSoft = Color(0xFFF6DCE8);
  static const blush = Color(0xFFE8A9C6);
  static const blushSoft = Color(0xFFF6DCE8);
  static const sunshine = Color(0xFFE8A9C6);
  static const sunshineDeep = Color(0xFF1B1F6B);
  static const sunshineGlow = Color(0xFFF6DCE8);

  static const cream = Color(0xFFFAF7FB);         // page bg, soft lavender-white
  static const paper = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1B1F6B);
  static const inkSoft = Color(0xFF6E7090);
  static const line = Color(0xFFF0E3EC);
  static const green = Color(0xFF00C48C);
  static const greenPale = Color(0xFFDFFBEF);
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _sRepoProvider = Provider((_) => AuthRepository());

final _sMeProvider =
    FutureProvider<UserModel>((ref) => ref.read(_sRepoProvider).getMe());

// ⚠️ CHANGED: parses into BookingModel now (b.*, student_name, teacher_name,
// teacher_avatar, pricing_name, session_type — see bookings.controller.js
// list()). The old code read booking['teacher_first']/['teacher_last'],
// which never existed on the real response.
final _sBookingsProvider = FutureProvider<List<BookingModel>>((ref) async {
  final repo = ref.read(_sRepoProvider);
  final token = await repo.getAccessToken();
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/bookings'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (res.statusCode != 200) return [];
  final decoded = jsonDecode(res.body) as List;
  return decoded
      .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ⚠️ CHANGED: teachers.controller.js browse() returns u.full_name (no
// first_name/last_name) and no credits_per_session — session cost now
// comes from the pricing table via the course a student picks in Book tab.
// Kept as raw maps (not TeacherProfileModel) since that model file still
// expects the old first_name/last_name/credits_per_session shape and would
// silently produce blank names against the real API.
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

// ✅ NEW: Book tab — course categories, e.g. ["Major Course", "Spanish
// Course", "Speaking Course", ...]. Defensive parsing since the exact
// categories() response shape (plain strings vs {category,count}) isn't
// confirmed — handles either.
final _sCourseCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.read(_sRepoProvider);
  final token = await repo.getAccessToken();
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/courses/categories'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (res.statusCode != 200) return [];
  final decoded = jsonDecode(res.body);
  if (decoded is! List) return [];
  return decoded
      .map((e) {
        if (e is String) return e;
        if (e is Map) return (e['category'] ?? e['name'] ?? '').toString();
        return e.toString();
      })
      .where((s) => s.isNotEmpty)
      .toList();
});

// ✅ NEW: Book tab — course grid, filtered by category.
// ⚠️ ASSUMPTION: /courses accepts ?category= the same way /teachers accepts
// ?subject=. If courses.controller.js filters on a different query param,
// update the key below.
final _sCoursesProvider =
    FutureProvider.family<List<CourseModel>, String?>((ref, category) async {
  final repo = ref.read(_sRepoProvider);
  final token = await repo.getAccessToken();
  final uri = Uri.parse('${AuthRepository.baseUrl}/courses').replace(
    queryParameters:
        (category != null && category != 'All') ? {'category': category} : null,
  );
  final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
  if (res.statusCode != 200) return [];
  final decoded = jsonDecode(res.body);
  if (decoded is! List) return [];
  return decoded
      .map((e) => CourseModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ═══════════════════════════════════════════════════════════════════════════════
class StudentDashboard extends ConsumerStatefulWidget {
  const StudentDashboard({super.key});
  @override
  ConsumerState<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<StudentDashboard> {
  int _navIndex = 0;

  void _goTo(int index) => setState(() => _navIndex = index);

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(_sMeProvider);

    return meAsync.when(
      loading: () => const Scaffold(
        backgroundColor: _C.cream,
        body: Center(child: CircularProgressIndicator(color: _C.pink)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _C.cream,
        body: Center(child: Text('$e')),
      ),
      data: (user) => Scaffold(
        backgroundColor: _C.cream,
        body: SafeArea(
          child: Stack(
            children: [
              // Background glow blobs (kept behind everything, ignored for hit testing)
              const _BackgroundBlobs(),
              IndexedStack(
                index: _navIndex,
                children: [
                  _HomeTab(user: user, onNavigate: _goTo),
                  _BookTab(user: user, onNavigate: _goTo),
                  _FindTeachersTab(user: user, onNavigate: _goTo),
                  _SessionsTab(user: user),
                  _RewardsTab(user: user),
                  _ProfileTab(user: user, onLogout: _logout),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    // ✅ NEW: 'Book' entry inserted at index 1 — categories → course grid.
    const items = [
      (Icons.home_rounded, Icons.home_outlined, 'Home', '首页'),
      (Icons.menu_book_rounded, Icons.menu_book_outlined, 'Book', '预约'),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: _C.sunshineDeep.withOpacity(0.28),
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
                            colors: [_C.navy, _C.pink],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: active ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: active
                        ? [
                            BoxShadow(
                                color: _C.pink.withOpacity(0.45),
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
                          fontSize: 9.5,
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

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }
}

// ── Decorative background blobs ───────────────────────────────────────────────
class _BackgroundBlobs extends StatelessWidget {
  const _BackgroundBlobs();
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(children: [
        Positioned(
          top: -60,
          right: -70,
          child: _glowCircle(180, _C.pinkGlow.withOpacity(0.55)),
        ),
        Positioned(
          top: 140,
          left: -80,
          child: _glowCircle(150, _C.blushSoft.withOpacity(0.6)),
        ),
        Positioned(
          bottom: 80,
          right: -60,
          child: _glowCircle(140, _C.coralSoft.withOpacity(0.5)),
        ),
      ]),
    );
  }

  Widget _glowCircle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      );
}

// ── Waving mascot with a little bounce/wiggle animation ──────────────────────
class _WavingMascot extends StatefulWidget {
  final double size;
  const _WavingMascot({this.size = 56});
  @override
  State<_WavingMascot> createState() => _WavingMascotState();
}

class _WavingMascotState extends State<_WavingMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
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
        final wiggle = math.sin(_ctrl.value * math.pi) * 0.18; // radians
        final bob = math.sin(_ctrl.value * math.pi) * -4;
        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(
            angle: wiggle,
            alignment: Alignment.bottomCenter,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_C.navy, _C.navySoft],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                      color: _C.navy.withOpacity(0.45),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 6)),
                ],
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Center(
                child: Text('👋',
                    style: TextStyle(fontSize: widget.size * 0.5)),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── PREMIUM HERO BANNER (VIPKid-style) ────────────────────────────────────────
/// Reusable premium hero banner used at the top of the Home tab.
/// Image blends into the gradient background via ShaderMask instead of
/// sitting on top as a separate rectangular widget.
class HomeHeroBanner extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? imageAsset;
  final IconData fallbackIcon;
  final VoidCallback? onButtonTap;
  final String? buttonLabel;
  final List<Color>? gradientColors;

  const HomeHeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageAsset,
    this.fallbackIcon = Icons.school_rounded,
    this.onButtonTap,
    this.buttonLabel,
    this.gradientColors,
  });

  @override
  State<HomeHeroBanner> createState() => _HomeHeroBannerState();
}

class _HomeHeroBannerState extends State<HomeHeroBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.gradientColors ??
        const [_C.navy, Color(0xFF2B2F86), _C.pink];

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = width * 0.52; // responsive aspect ratio

      return ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              stops: const [0.0, 0.55, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _C.navy.withOpacity(0.30),
                blurRadius: 26,
                spreadRadius: -6,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── layered decorative blobs, drift slowly ──
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final t = _ctrl.value;
                  return Stack(children: [
                    Positioned(
                      right: -40 + (t * 10),
                      top: -50,
                      child: _blob(160, _C.pinkGlow.withOpacity(0.35)),
                    ),
                    Positioned(
                      left: -60,
                      bottom: -60 - (t * 8),
                      child: _blob(140, _C.pink.withOpacity(0.25)),
                    ),
                    Positioned(
                      right: width * 0.32,
                      bottom: -30,
                      child: _blob(90, Colors.white.withOpacity(0.10)),
                    ),
                  ]);
                },
              ),

              // ── abstract curved shape separating text/image zones ──
              Positioned.fill(
                child: CustomPaint(
                  painter: _HeroCurvePainter(),
                ),
              ),

              // ── floating soft circles (subtle accent dots) ──
              Positioned(
                top: height * 0.18,
                right: width * 0.40,
                child: _dot(10, Colors.white.withOpacity(0.5)),
              ),
              Positioned(
                top: height * 0.65,
                right: width * 0.46,
                child: _dot(6, _C.pinkGlow.withOpacity(0.8)),
              ),

              // ── text content (left) ──
              Positioned(
                left: 24,
                top: 0,
                bottom: 0,
                right: width * 0.46,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    if (widget.buttonLabel != null) ...[
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: widget.onButtonTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            widget.buttonLabel!,
                            style: const TextStyle(
                              color: _C.navy,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── image/mascot (right), blended via gradient mask ──
              Positioned(
                right: -10,
                bottom: 0,
                top: 0,
                width: width * 0.5,
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.center,
                    colors: [Colors.transparent, Colors.white],
                    stops: [0.0, 0.35],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: widget.imageAsset != null
                      ? Image.asset(
                          widget.imageAsset!,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomRight,
                        )
                      : Align(
                          alignment: Alignment.center,
                          child: Icon(
                            widget.fallbackIcon,
                            size: width * 0.30,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      );

  Widget _dot(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

/// Soft abstract curve that separates the text zone from the image zone,
/// so the image feels woven into the banner rather than pasted on top.
class _HeroCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(size.width * 0.50, 0)
      ..quadraticBezierTo(
        size.width * 0.40, size.height * 0.45,
        size.width * 0.55, size.height,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── HOME TAB ──────────────────────────────────────────────────────────────────
class _HomeTab extends ConsumerWidget {
  final UserModel user;
  final void Function(int) onNavigate;
  const _HomeTab({required this.user, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(_sBookingsProvider);
    final teachersAsync = ref.watch(_sTeachersProvider);

    return CustomScrollView(
      slivers: [
        // ── Header ────────────────────────────────────────────────────────
        SliverToBoxAdapter(child: _buildHeader(context)),

        // ── Hero banner (premium, VIPKid-style) ─────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          sliver: SliverToBoxAdapter(
            child: HomeHeroBanner(
              title: 'Hi, ${user.firstName}! 你好',
              subtitle:
                  "Let's continue your learning journey today.\n继续您的学习之旅",
              buttonLabel: 'Browse Courses',
              onButtonTap: () => onNavigate(1), // → Book tab
            ),
          ),
        ),

        // ── Points progress ───────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver:
              SliverToBoxAdapter(child: _PointsProgress(points: user.points)),
        ),

        // ── "Let's Learn!" playful CTA strip ────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: const SliverToBoxAdapter(child: _LetsLearnStrip()),
        ),

        // ── Next session banner ───────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(
            child: bookingsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (bookings) {
                final next = bookings
                    .where((b) => b.status == BookingStatus.confirmed)
                    .toList();
                if (next.isEmpty) return const SizedBox.shrink();
                return _NextSessionBanner(booking: next.first);
              },
            ),
          ),
        ),

        // ── Featured teachers ─────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 26, 0, 8),
          sliver: SliverToBoxAdapter(
            child: _SectionRow(
                en: 'Featured Teachers',
                zh: '推荐老师',
                onSeeAll: () => onNavigate(2)),
          ),
        ),
        SliverToBoxAdapter(
          child: teachersAsync.when(
            loading: () => const SizedBox(
                height: 150,
                child: Center(
                    child: CircularProgressIndicator(color: _C.pink))),
            error: (_, __) => const SizedBox.shrink(),
            data: (teachers) => _TeacherCarousel(teachers: teachers),
          ),
        ),

        // ── Recent sessions ───────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 8),
          sliver: SliverToBoxAdapter(
            child: _SectionRow(
                en: 'Recent Sessions', zh: '最近课程', onSeeAll: () => onNavigate(3)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverToBoxAdapter(
            child: bookingsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: _C.pink)),
              error: (e, _) => Text('$e'),
              data: (bookings) {
                final recent = bookings.take(3).toList();
                if (recent.isEmpty) {
                  return _EmptyCard(
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
        const _WavingMascot(size: 52),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hi, ${user.firstName}! 你好 👋',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: _C.navy)),
          const Text('学生 · Let\'s learn today!',
              style: TextStyle(
                  fontSize: 11,
                  color: _C.pinkDeep,
                  fontWeight: FontWeight.w700)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_C.navy, _C.pink]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: _C.navy.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.diamond_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text('${user.credits} credits',
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );
  }
}

// ── "Let's Learn!" playful strip (inspired by kiddy learning-app reference) ──
class _LetsLearnStrip extends StatelessWidget {
  const _LetsLearnStrip();

  @override
  Widget build(BuildContext context) {
    const tasks = [
      ('🎧', 'Listen · 听', _C.navy),
      ('👀', 'Watch · 看', _C.pink),
      ('🗣️', 'Speak · 说', _C.pinkDeep),
      ('📖', 'Read · 读', _C.navySoft),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _C.line, width: 1.4),
        boxShadow: [
          BoxShadow(
              color: _C.navy.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Text('✨', style: TextStyle(fontSize: 16)),
          SizedBox(width: 6),
          Text("Let's Learn!",
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900, color: _C.navy)),
          SizedBox(width: 6),
          Text('· 一起学习', style: TextStyle(fontSize: 11, color: _C.pinkDeep)),
        ]),
        const SizedBox(height: 12),
        Row(
          children: tasks
              .map((t) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (t.$3 as Color).withOpacity(0.18),
                            boxShadow: [
                              BoxShadow(
                                  color: (t.$3 as Color).withOpacity(0.35),
                                  blurRadius: 12,
                                  spreadRadius: 1),
                            ],
                          ),
                          child: Center(
                              child: Text(t.$1,
                                  style: const TextStyle(fontSize: 22))),
                        ),
                        const SizedBox(height: 6),
                        Text(t.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _C.inkSoft)),
                      ]),
                    ),
                  ))
              .toList(),
        ),
      ]),
    );
  }
}

// ── BOOK TAB (✅ NEW — Screen 1: categories → course grid) ───────────────────
// Wired to real /courses and /courses/categories. Tapping "Details" opens a
// bottom sheet built from the CourseModel fields already fetched (no extra
// round trip), matching the Course Details screens in the reference app.
class _BookTab extends ConsumerStatefulWidget {
  final UserModel user;
  final void Function(int) onNavigate;
  const _BookTab({required this.user, required this.onNavigate});

  @override
  ConsumerState<_BookTab> createState() => _BookTabState();
}

class _BookTabState extends ConsumerState<_BookTab> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(_sCourseCategoriesProvider);
    final coursesAsync = ref.watch(_sCoursesProvider(_selectedCategory));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Row(children: const [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Book Class',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _C.navy)),
                Text('预约课程 📚',
                    style: TextStyle(
                        fontSize: 12,
                        color: _C.pinkDeep,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ]),
      ),
      // Category chips
      SizedBox(
        height: 38,
        child: categoriesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (cats) {
            final all = ['All', ...cats];
            return ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: all.length,
              itemBuilder: (_, i) {
                final c = all[i];
                final active = c == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: active
                          ? const LinearGradient(colors: [_C.navy, _C.pink])
                          : null,
                      color: active ? null : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active ? Colors.transparent : _C.line),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                  color: _C.navy.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3))
                            ]
                          : null,
                    ),
                    child: Text(c,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: active ? Colors.white : _C.inkSoft)),
                  ),
                );
              },
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      // Course grid
      Expanded(
        child: coursesAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _C.pink)),
          error: (e, _) => Center(child: Text('$e')),
          data: (courses) {
            if (courses.isEmpty) {
              return Center(
                child: _EmptyCard(
                  icon: Icons.menu_book_outlined,
                  title: 'No courses found',
                  titleCn: '未找到课程',
                  subtitle: 'Try a different category.',
                ),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.66,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: courses.length,
              itemBuilder: (_, i) {
                final course = courses[i];
                return _CourseCard(
                  course: course,
                  onDetails: () => _showCourseDetail(
                    context,
                    course,
                    () => widget.onNavigate(2), // → Teachers tab
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

class _CourseCard extends StatelessWidget {
  final CourseModel course;
  final VoidCallback onDetails;
  const _CourseCard({required this.course, required this.onDetails});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.line, width: 1.4),
        boxShadow: [
          BoxShadow(
              color: _C.navy.withOpacity(0.10),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(children: [
            Container(
              height: 78,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_C.navy, _C.pink],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: course.thumbnailUrl != null
                  ? Image.network(
                      course.thumbnailUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 78,
                      errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.menu_book_rounded,
                              color: Colors.white, size: 28)),
                    )
                  : const Center(
                      child: Icon(Icons.menu_book_rounded,
                          color: Colors.white, size: 28)),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('1v1',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: _C.navy,
                          height: 1.2)),
                  if (course.titleCn.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(course.titleCn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10, color: _C.pinkDeep)),
                  ],
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (course.ageGroup != null) _tag(course.ageGroup!),
                    if (course.category.isNotEmpty) _tag(course.category),
                  ]),
                  const Spacer(),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                        textStyle: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                      child: const Text('Details · 详情'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: _C.pinkGlow, borderRadius: BorderRadius.circular(10)),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _C.navy)),
      );
}

void _showCourseDetail(
    BuildContext context, CourseModel course, VoidCallback onFindTeachers) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _C.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _C.line, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Text(course.title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, color: _C.navy)),
            if (course.titleCn.isNotEmpty)
              Text(course.titleCn,
                  style: const TextStyle(fontSize: 12, color: _C.pinkDeep)),
            const SizedBox(height: 12),
            if (course.description != null && course.description!.isNotEmpty)
              Text(course.description!,
                  style: const TextStyle(
                      fontSize: 13, color: _C.inkSoft, height: 1.5)),
            if (course.features.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Learning Features · 学习特色',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _C.navy)),
              const SizedBox(height: 8),
              ...course.features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ',
                            style: TextStyle(
                                color: _C.pinkDeep,
                                fontWeight: FontWeight.w900)),
                        Expanded(
                            child: Text(f,
                                style: const TextStyle(
                                    fontSize: 12, color: _C.inkSoft))),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 16),
            if (course.pricingName != null || course.creditsPerSession != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: _C.pinkGlow.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  const Icon(Icons.diamond_rounded,
                      color: _C.pinkDeep, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${course.pricingName ?? course.sessionType ?? 'Pricing'} · '
                      '${course.creditsPerSession ?? '-'} credits / class',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _C.navy),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onFindTeachers();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Find a Teacher · 找老师',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── FIND TEACHERS TAB ─────────────────────────────────────────────────────────
class _FindTeachersTab extends ConsumerStatefulWidget {
  final UserModel user;
  final void Function(int) onNavigate;
  const _FindTeachersTab({required this.user, required this.onNavigate});
  @override
  ConsumerState<_FindTeachersTab> createState() => _FindTeachersTabState();
}

class _FindTeachersTabState extends ConsumerState<_FindTeachersTab> {
  final _searchCtrl = TextEditingController();
  String _selected = 'All';
  final _subjectFilters = [
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
                        fontWeight: FontWeight.w900,
                        color: _C.navy)),
                Text('找老师 🔍',
                    style: TextStyle(
                        fontSize: 12,
                        color: _C.pinkDeep,
                        fontWeight: FontWeight.w700)),
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
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: _C.line, width: 1.4)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: _C.line, width: 1.4)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _C.pinkDeep, width: 1.6)),
          ),
        ),
      ),
      const SizedBox(height: 12),
      // Subject filter chips
      SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _subjectFilters.length,
          itemBuilder: (_, i) {
            final s = _subjectFilters[i];
            final active = s == _selected;
            return GestureDetector(
              onTap: () => setState(() => _selected = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: active
                      ? const LinearGradient(
                          colors: [_C.navy, _C.pink])
                      : null,
                  color: active ? null : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active ? Colors.transparent : _C.line),
                  boxShadow: active
                      ? [
                          BoxShadow(
                              color: _C.navy.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3))
                        ]
                      : null,
                ),
                child: Text(s,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
              const Center(child: CircularProgressIndicator(color: _C.pink)),
          error: (e, _) => Center(child: Text('$e')),
          data: (teachers) {
            final filtered = teachers.where((t) {
              final q = _searchCtrl.text.toLowerCase();
              final name = (t['full_name'] ?? '').toString().toLowerCase();
              final subjects =
                  (t['subjects'] as List?)?.join(' ').toLowerCase() ?? '';
              final matchSearch =
                  q.isEmpty || name.contains(q) || subjects.contains(q);
              final matchSubject = _selected == 'All' ||
                  (t['subjects'] as List?)?.contains(_selected) == true;
              return matchSearch && matchSubject;
            }).toList();

            if (filtered.isEmpty) {
              return _EmptyCard(
                icon: Icons.person_search_outlined,
                title: 'No teachers found',
                titleCn: '未找到老师',
                subtitle: 'Try a different subject or search term.',
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: filtered.length,
              itemBuilder: (_, i) => _TeacherCard(
                teacher: filtered[i],
                onBook: () => widget.onNavigate(1), // → Book tab
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
                    fontSize: 20, fontWeight: FontWeight.w900, color: _C.navy)),
            Text('我的课程 📅',
                style: TextStyle(
                    fontSize: 12,
                    color: _C.pinkDeep,
                    fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
      Expanded(
        child: bookingsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _C.pink)),
          error: (e, _) => Center(child: Text('$e')),
          data: (bookings) {
            if (bookings.isEmpty) {
              return Center(
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
                    b.status == BookingStatus.confirmed ||
                    b.status == BookingStatus.pending)
                .toList();
            final past = bookings
                .where((b) =>
                    b.status == BookingStatus.completed ||
                    b.status == BookingStatus.cancelled)
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
              colors: [_C.navy, _C.navySoft],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: _C.navy.withOpacity(0.35),
                blurRadius: 22,
                spreadRadius: -4,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Text('🏆', style: TextStyle(fontSize: 16)),
            SizedBox(width: 6),
            Text('Your Points · 您的积分',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text('${user.points}',
              style: const TextStyle(
                  color: _C.pink,
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
                  fontSize: 16, fontWeight: FontWeight.w900, color: _C.navy)),
          SizedBox(width: 6),
          Text('· 里程碑奖励 🎁',
              style: TextStyle(
                  fontSize: 12,
                  color: _C.pinkDeep,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: rewardsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _C.pink)),
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
          const _WavingMascot(size: 84),
          const SizedBox(height: 12),
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
                    const LinearGradient(colors: [_C.navy, _C.pink]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: _C.navy.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ]),
            child: const Text('学生 · Student',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w800)),
          ),
        ])),
        const SizedBox(height: 28),
        // Stats row
        Row(children: [
          _ProfileStat(
              '${user.credits}', 'Credits\n积分', _C.navy, _C.pinkGlow),
          const SizedBox(width: 12),
          _ProfileStat(
              '${user.points}', 'Points\n奖励点', _C.pinkDeep, _C.pinkGlow),
        ]),
        const SizedBox(height: 24),
        // Settings list
        _ProfileSection('Account', '账户', [
          _ProfileTile(Icons.person_outline, 'Edit Profile', '编辑资料', () {}),
          _ProfileTile(Icons.lock_outline, 'Change Password', '修改密码', () {}),
          _ProfileTile(Icons.language, 'Language', '语言', () {}),
        ]),
        const SizedBox(height: 16),
        _ProfileSection('Preferences', '偏好', [
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
            foregroundColor: _C.pinkDeep,
            side: const BorderSide(color: _C.pinkDeep, width: 1.6),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 8,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.18)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_C.navy, _C.pink]),
                boxShadow: [
                  BoxShadow(
                      color: _C.pink.withOpacity(0.6), blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _NextSessionBanner extends StatelessWidget {
  final BookingModel booking;
  const _NextSessionBanner({required this.booking});

  @override
  Widget build(BuildContext context) {
    final dt = booking.scheduledAt.toLocal();
    final name = booking.teacherName ?? 'your teacher';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.greenPale,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.green.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: _C.green.withOpacity(0.18),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: _C.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14)),
          child:
              const Icon(Icons.video_call_rounded, color: _C.green, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Next Session · 下一节课',
              style: TextStyle(
                  fontSize: 11, color: _C.green, fontWeight: FontWeight.w800)),
          Text('with $name',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _C.navy)),
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
      height: 168,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: teachers.length,
        itemBuilder: (_, i) {
          final t = teachers[i];
          final name = (t['full_name'] ?? '').toString();
          final initial = name.isNotEmpty ? name[0] : '?';
          final subjects = (t['subjects'] as List?)?.take(2).join(', ') ?? '';
          final rating = (t['rating'] ?? 0).toStringAsFixed(1);
          final sessions = t['total_sessions'] ?? 0;
          return Container(
            width: 134,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _C.line, width: 1.4),
              boxShadow: [
                BoxShadow(
                    color: _C.navy.withOpacity(0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 6)),
              ],
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(
                    radius: 18,
                    backgroundColor: _C.pinkGlow,
                    child: Text(initial,
                        style: const TextStyle(
                            color: _C.navy, fontWeight: FontWeight.w900))),
                const Spacer(),
                const Icon(Icons.star_rounded,
                    color: _C.pinkDeep, size: 14),
                const SizedBox(width: 2),
                Text(rating,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _C.navy)),
              ]),
              const SizedBox(height: 10),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _C.navy)),
              const SizedBox(height: 3),
              Text(subjects,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: _C.inkSoft)),
              const Spacer(),
              Row(children: [
                const Icon(Icons.groups_rounded, size: 11, color: _C.pinkDeep),
                const SizedBox(width: 3),
                Text('$sessions sessions',
                    style: const TextStyle(
                        fontSize: 10,
                        color: _C.pinkDeep,
                        fontWeight: FontWeight.w800)),
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
  final VoidCallback onBook;
  const _TeacherCard({required this.teacher, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final name = (teacher['full_name'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0] : '?';
    final subjects =
        (teacher['subjects'] as List?)?.take(3).join(' · ') ?? '';
    final rating = (teacher['rating'] ?? 0).toStringAsFixed(1);
    final sessions = teacher['total_sessions'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.line, width: 1.4),
        boxShadow: [
          BoxShadow(
              color: _C.navy.withOpacity(0.10),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
              radius: 22,
              backgroundColor: _C.pinkGlow,
              child: Text(initial,
                  style: const TextStyle(
                      color: _C.navy,
                      fontWeight: FontWeight.w900,
                      fontSize: 16))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
                color: _C.pinkGlow,
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.star_rounded,
                  color: _C.pinkDeep, size: 12),
              const SizedBox(width: 2),
              Text(rating,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _C.navy)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900, color: _C.navy)),
        const SizedBox(height: 3),
        Text(subjects,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
        const Spacer(),
        // ⚠️ CHANGED: credits_per_session no longer lives on the teacher —
        // cost is set per-course via pricing, chosen in the Book tab.
        Row(children: [
          const Icon(Icons.groups_rounded, size: 12, color: _C.pinkDeep),
          const SizedBox(width: 4),
          Text('$sessions sessions taught',
              style: const TextStyle(
                  fontSize: 11,
                  color: _C.pinkDeep,
                  fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onBook,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 9),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
              textStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
            child: const Text('Book Now · 预约'),
          ),
        ),
      ]),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final name = booking.teacherName ?? 'Teacher';
    final initial = name.isNotEmpty ? name[0] : '?';
    final status = booking.status;
    final dt = booking.scheduledAt.toLocal();
    final statusColor = {
          BookingStatus.confirmed: _C.green,
          BookingStatus.completed: _C.navySoft,
          BookingStatus.cancelled: _C.inkSoft,
          BookingStatus.pending: _C.pinkDeep,
        }[status] ??
        _C.inkSoft;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.line, width: 1.4),
          boxShadow: [
            BoxShadow(
                color: _C.navy.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ]),
      child: Row(children: [
        CircleAvatar(
            radius: 20,
            backgroundColor: _C.pinkGlow,
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
              '${booking.creditsCost} credits · ${booking.durationMins} min'
              '${booking.pricingName != null ? ' · ${booking.pricingName}' : ''}',
              style: const TextStyle(
                  fontSize: 11,
                  color: _C.pinkDeep,
                  fontWeight: FontWeight.w700)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: statusColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20)),
          child: Text(status.label,
              style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w800)),
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
        color: unlocked ? _C.greenPale : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: unlocked ? _C.green.withOpacity(0.3) : _C.line, width: 1.4),
        boxShadow: [
          BoxShadow(
              color: (unlocked ? _C.green : _C.navy).withOpacity(0.10),
              blurRadius: 12,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: unlocked ? _C.green.withOpacity(0.15) : _C.pinkGlow,
              borderRadius: BorderRadius.circular(14)),
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
                  fontSize: 13, fontWeight: FontWeight.w800, color: _C.navy)),
          Text(reward['description'] ?? '',
              style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
          const SizedBox(height: 4),
          Text('$required pts required',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: unlocked ? _C.green : _C.pinkDeep)),
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
                    fontWeight: FontWeight.w800)),
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
                fontSize: 16, fontWeight: FontWeight.w900, color: _C.navy)),
        const SizedBox(width: 5),
        Text('· $zh',
            style: const TextStyle(
                fontSize: 12, color: _C.pinkDeep, fontWeight: FontWeight.w700)),
        const Spacer(),
        GestureDetector(
          onTap: onSeeAll,
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text('See all',
                style: TextStyle(
                    fontSize: 12,
                    color: _C.pinkDeep.withOpacity(0.85),
                    fontWeight: FontWeight.w800)),
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
                fontSize: 13, fontWeight: FontWeight.w800, color: _C.inkSoft)),
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
            color: _C.pinkGlow.withOpacity(0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _C.line, width: 1.4)),
        child: Column(children: [
          const Text('🦉', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: _C.navy)),
          Text('· $titleCn',
              style: const TextStyle(fontSize: 12, color: _C.pinkDeep)),
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
              color: pale,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 5)),
              ]),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w900, color: color)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10,
                    color: _C.inkSoft,
                    fontWeight: FontWeight.w700,
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
                      fontWeight: FontWeight.w800,
                      color: _C.inkSoft)),
              const SizedBox(width: 5),
              Text('· $zh',
                  style: const TextStyle(fontSize: 12, color: _C.pinkDeep)),
            ]),
          ),
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.line, width: 1.4),
                boxShadow: [
                  BoxShadow(
                      color: _C.navy.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ]),
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
        leading: Icon(icon, color: _C.pinkDeep, size: 20),
        title: Text('$label · $labelCn',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: _C.navy)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 13, color: _C.inkSoft),
        dense: true,
      );
}