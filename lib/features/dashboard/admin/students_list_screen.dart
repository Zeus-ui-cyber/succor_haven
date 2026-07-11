// lib/features/dashboard/admin/students_list_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../auth/repositories/auth_repository.dart';
import 'student_detail_screen.dart';

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
// crash the whole list on ''[0].
String _initials(String? first, String? last) {
  final f = (first ?? '').trim();
  final l = (last ?? '').trim();
  if (f.isEmpty && l.isEmpty) return '?';
  if (f.isEmpty) return l[0].toUpperCase();
  if (l.isEmpty) return f[0].toUpperCase();
  return '${f[0]}${l[0]}'.toUpperCase();
}

// Defensive numeric parser — Postgres COUNT(*) returns bigint, which
// node-postgres sends over the wire as a JS string, not a number. A plain
// `(x ?? 0) as int` cast crashes on that string since ?? only substitutes
// on null, not on a non-null value of the wrong type. This was the actual
// cause of the Students tab crash (upcoming_sessions came back as "0").
// The backend now casts with ::int, but this stays as a safety net in
// case any other numeric field on this screen is ever added without the
// same care.
int _asInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

// avatar_url from the backend is likely a relative path (multer saves to
// uploads/profile-pictures/, served statically at /uploads/... — separate
// from the /api/v1 routes AuthRepository.baseUrl points at). This builds
// the correct absolute URL regardless of whether the backend already
// returns a full URL or a relative one.
// ⚠️ VERIFY: check what settingsCtrl.uploadProfilePicture actually stores
// in the avatar_url column — if it already stores a full URL, this is
// still safe (the http:// check below short-circuits), but if it stores
// something other than a path starting with "/uploads", adjust below.
String? _resolveAvatarUrl(String? rawUrl) {
  if (rawUrl == null || rawUrl.isEmpty) return null;
  if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
    return rawUrl;
  }
  // Strip a trailing /api/v1 (or similar) so we hit the static file host,
  // not the API route.
  final apiBase = AuthRepository.baseUrl;
  final fileHost = apiBase.replaceFirst(RegExp(r'/api/v\d+/?$'), '');
  final path = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
  return '$fileHost$path';
}

final _studentsRepoProvider = Provider((_) => AuthRepository());

Future<Map<String, String>> _headers(AuthRepository repo) async {
  final token = await repo.getAccessToken();
  return {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

// ── Filter state ──────────────────────────────────────────────────────────────
class StudentsFilter {
  final String search;
  final String status; // 'all' | 'active' | 'inactive'
  final String verified; // 'all' | 'verified' | 'unverified'
  final String course; // '' = all
  final int page;
  const StudentsFilter({
    this.search = '',
    this.status = 'all',
    this.verified = 'all',
    this.course = '',
    this.page = 1,
  });

  StudentsFilter copyWith({
    String? search,
    String? status,
    String? verified,
    String? course,
    int? page,
  }) =>
      StudentsFilter(
        search: search ?? this.search,
        status: status ?? this.status,
        verified: verified ?? this.verified,
        course: course ?? this.course,
        page: page ?? this.page,
      );
}

final studentsFilterProvider =
    StateProvider<StudentsFilter>((ref) => const StudentsFilter());

final studentsSummaryProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(_studentsRepoProvider);
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/admin/students/summary'),
    headers: await _headers(repo),
  );
  if (res.statusCode != 200) throw Exception('Failed to load summary');
  return jsonDecode(res.body) as Map<String, dynamic>;
});

final studentsListProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final f = ref.watch(studentsFilterProvider);
  final repo = ref.read(_studentsRepoProvider);
  final params = <String, String>{
    'page': '${f.page}',
    'limit': '20',
    if (f.search.isNotEmpty) 'search': f.search,
    if (f.status != 'all') 'status': f.status,
    if (f.verified != 'all') 'verified': f.verified,
    if (f.course.isNotEmpty) 'course': f.course,
  };
  final uri = Uri.parse('${AuthRepository.baseUrl}/admin/students')
      .replace(queryParameters: params);
  final res = await http.get(uri, headers: await _headers(repo));
  if (res.statusCode != 200) throw Exception('Failed to load students');
  return jsonDecode(res.body) as Map<String, dynamic>;
});

// ═══════════════════════════════════════════════════════════════════════════
// `asTab: true` renders just the body content (no Scaffold/AppBar) so it can
// be embedded directly inside AdminDashboard's TabBarView, same as
// _TeachersTab / _UsersTab. `asTab: false` (default) renders as a
// standalone pushable screen with its own AppBar.
class StudentsListScreen extends ConsumerStatefulWidget {
  final bool asTab;
  const StudentsListScreen({super.key, this.asTab = false});

  @override
  ConsumerState<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends ConsumerState<StudentsListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);

    if (widget.asTab) {
      return SafeArea(child: body);
    }

    return Scaffold(
      backgroundColor: _C.cream,
      appBar: AppBar(
        backgroundColor: _C.cream,
        elevation: 0,
        foregroundColor: _C.ink,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Students List',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: _C.ink)),
            Text('学生列表', style: TextStyle(fontSize: 11, color: _C.burgundy)),
          ],
        ),
      ),
      body: SafeArea(child: body),
    );
  }

  Widget _buildBody(BuildContext context) {
    final summaryAsync = ref.watch(studentsSummaryProvider);
    final listAsync = ref.watch(studentsListProvider);
    final filter = ref.watch(studentsFilterProvider);

    return Column(
      children: [
        // ── Summary cards ────────────────────────────────────────────────
        summaryAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(color: _C.burgundy)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Text('$e', style: const TextStyle(color: _C.inkSoft)),
          ),
          data: (s) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(children: [
              Expanded(
                  child: _SummaryCard('${s['totalStudents']}', 'Total\n总数',
                      _C.burgundy, _C.blushPink)),
              const SizedBox(width: 8),
              Expanded(
                  child: _SummaryCard('${s['activeStudents']}', 'Active\n活跃',
                      _C.green, const Color(0xFFDCF7EE))),
              const SizedBox(width: 8),
              Expanded(
                  child: _SummaryCard('${s['inactiveStudents']}',
                      'Inactive\n未激活', _C.inkSoft, _C.softPink)),
              const SizedBox(width: 8),
              Expanded(
                  child: _SummaryCard(
                      '${s['studentsWithUpcomingSessions']}',
                      'Upcoming\n即将上课',
                      _C.slateBlue,
                      const Color(0xFFDCEBF5))),
            ]),
          ),
        ),

        // ── Search ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => ref.read(studentsFilterProvider.notifier).state =
                filter.copyWith(search: v, page: 1),
            decoration: InputDecoration(
              hintText: 'Search by name, ID, email, or course...',
              prefixIcon: const Icon(Icons.search, color: _C.inkSoft, size: 20),
              filled: true,
              fillColor: _C.softPink,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
        ),

        // ── Filter chips ─────────────────────────────────────────────────
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _FilterDropdown(
                label: 'Status',
                value: filter.status,
                options: const {
                  'all': 'All',
                  'active': 'Active',
                  'inactive': 'Inactive',
                },
                onChanged: (v) => ref.read(studentsFilterProvider.notifier).state =
                    filter.copyWith(status: v, page: 1),
              ),
              const SizedBox(width: 8),
              _FilterDropdown(
                label: 'Verified',
                value: filter.verified,
                options: const {
                  'all': 'All',
                  'verified': 'Verified',
                  'unverified': 'Unverified',
                },
                onChanged: (v) => ref.read(studentsFilterProvider.notifier).state =
                    filter.copyWith(verified: v, page: 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── List ─────────────────────────────────────────────────────────
        Expanded(
          child: listAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: _C.burgundy)),
            error: (e, _) => Center(child: Text('$e')),
            data: (data) {
              final students = data['students'] as List;
              final pagination = data['pagination'] as Map<String, dynamic>;

              if (students.isEmpty) {
                return const Center(
                  child: Text('No students found',
                      style: TextStyle(color: _C.inkSoft)),
                );
              }

              return Column(children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    itemCount: students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _StudentRow(student: students[i]),
                  ),
                ),
                _Pagination(
                  page: pagination['page'],
                  totalPages: pagination['totalPages'],
                  onPrev: pagination['page'] > 1
                      ? () => ref.read(studentsFilterProvider.notifier).state =
                          filter.copyWith(page: pagination['page'] - 1)
                      : null,
                  onNext: pagination['page'] < pagination['totalPages']
                      ? () => ref.read(studentsFilterProvider.notifier).state =
                          filter.copyWith(page: pagination['page'] + 1)
                      : null,
                ),
              ]);
            },
          ),
        ),
      ],
    );
  }
}

class _StudentRow extends ConsumerWidget {
  final Map<String, dynamic> student;
  const _StudentRow({required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = student['is_active'] == true;
    final verified = student['phone_verified'] == true;
    final upcoming = _asInt(student['upcoming_sessions']);
    final firstName = student['first_name'] as String?;
    final lastName = student['last_name'] as String?;
    final displayName = [firstName, lastName]
        .where((n) => n != null && n.trim().isNotEmpty)
        .join(' ');
    final avatarUrl = _resolveAvatarUrl(student['avatar_url'] as String?);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: Row(children: [
        _Avatar(
          avatarUrl: avatarUrl,
          initials: _initials(firstName, lastName),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(displayName.isEmpty ? 'Unnamed' : displayName,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _C.ink)),
          Text(student['email'] ?? student['phone'] ?? '',
              style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _Badge(active ? 'Active' : 'Inactive', active ? _C.green : _C.inkSoft),
            _Badge(verified ? 'Verified' : 'Unverified',
                verified ? _C.slateBlue : _C.amber),
            if (upcoming > 0) _Badge('$upcoming upcoming', _C.magenta),
          ]),
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => StudentDetailScreen(studentId: student['id'])),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _C.burgundy,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('View',
                style: TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// Falls back to initials if avatarUrl is null OR fails to load (broken
// link, 404, wrong host). Without this, a bad avatar_url just renders a
// blank grey circle with no indication anything went wrong.
class _Avatar extends StatefulWidget {
  final String? avatarUrl;
  final String initials;
  const _Avatar({required this.avatarUrl, required this.initials});

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
      radius: 22,
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
              style: const TextStyle(
                  color: _C.burgundy,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10)),
        child: Text(label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
      );
}

class _SummaryCard extends StatelessWidget {
  final String value, label;
  final Color color, pale;
  const _SummaryCard(this.value, this.label, this.color, this.pale);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration:
            BoxDecoration(color: pale, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  color: _C.inkSoft,
                  fontWeight: FontWeight.w600,
                  height: 1.3)),
        ]),
      );
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value != 'all';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isActive ? _C.magenta : _C.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? _C.magenta : _C.line),
      ),
      alignment: Alignment.center,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(Icons.arrow_drop_down,
              color: isActive ? Colors.white : _C.inkSoft, size: 18),
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : _C.inkSoft),
          dropdownColor: _C.paper,
          items: options.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.key == 'all' ? '$label: All' : e.value,
                        style: const TextStyle(color: _C.ink)),
                  ))
              .toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  final int page, totalPages;
  final VoidCallback? onPrev, onNext;
  const _Pagination(
      {required this.page, required this.totalPages, this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              onPressed: onPrev, icon: const Icon(Icons.chevron_left, color: _C.burgundy)),
          Text('Page $page of $totalPages',
              style: const TextStyle(fontSize: 12, color: _C.inkSoft)),
          IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right, color: _C.burgundy)),
        ]),
      );
}