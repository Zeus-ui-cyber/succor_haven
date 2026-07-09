// lib/features/dashboard/admin/milestone_rewards_screen.dart
//
// Admin screen — Milestone Rewards (里程碑奖励)
// Milestones are achievements that automatically trigger a reward (credits or
// points) when a student / teacher hits a threshold (e.g. "Complete 10 sessions").
//
// API assumed endpoints
//   GET    /admin/milestones          → List<Milestone>
//   POST   /admin/milestones          → Milestone   (body: MilestonePayload)
//   PATCH  /admin/milestones/:id      → Milestone
//   DELETE /admin/milestones/:id      → { deleted: true }
//
// Milestone JSON shape
// {
//   "id": "uuid",
//   "title": "First Booking",
//   "title_cn": "首次预约",
//   "description": "Complete your very first session",
//   "emoji": "🎉",
//   "threshold": 1,
//   "metric": "sessions_completed" | "sessions_booked" | "referrals" | "streak_days" | "credits_spent",
//   "reward_credits": 0,
//   "reward_points": 50,
//   "applies_to": "student" | "teacher" | "all",
//   "is_active": true,
//   "created_at": "ISO8601"
// }
//
// ⚠️ UNVERIFIED: milestones.controller.js and the migration that created
// this table have not been reviewed yet. Every other admin screen in this
// codebase turned out to have at least one column-name or type mismatch
// against the real schema (full_name vs first_name/last_name, avatar_url
// on the wrong table, discount_pct arriving as a NUMERIC string instead of
// a number, a pricing controller pointed at a table that didn't exist).
// Given that track record, treat this screen as unconfirmed until the
// backend controller and the milestones table schema are checked directly
// — run `SELECT column_name, data_type FROM information_schema.columns
// WHERE table_name = 'milestones';` against Neon and compare against the
// field names used below.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../auth/repositories/auth_repository.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
class _C {
  static const sunshine = Color(0xFFFFC93C);
  static const sunshineDeep = Color(0xFFFFB100);
  static const sunshineGlow = Color(0xFFFFE49A);
  static const navy = Color(0xFF142850);
  static const coral = Color(0xFFFF6F61);
  static const coralSoft = Color(0xFFFFD9CC);
  static const blushSoft = Color(0xFFFCE0E6);
  static const cream = Color(0xFFFFF8E7);
  static const paper = Color(0xFFFFFFFF);
  static const inkSoft = Color(0xFF6E7593);
  static const line = Color(0xFFFFE8B8);
  static const green = Color(0xFF00C48C);
  static const greenPale = Color(0xFFDFFBEF);
  static const purple = Color(0xFF7C5CBF);
  static const purplePale = Color(0xFFEDE7FF);
}

// Defensive numeric parser — same pattern applied to session_pricing_screen.dart
// after discount_pct there turned out to arrive as a NUMERIC string rather
// than a number. Applied pre-emptively here since threshold/reward_credits/
// reward_points could hit the same issue depending on the real column types
// in `milestones`, which haven't been confirmed yet.
num _asNum(dynamic v, [num fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? fallback;
  return fallback;
}

// ── Providers ────────────────────────────────────────────────────────────────
final _repoProvider = Provider((_) => AuthRepository());

Future<Map<String, String>> _headers(AuthRepository repo) async {
  final token = await repo.getAccessToken();
  return {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

final _milestonesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(_repoProvider);
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/admin/milestones'),
    headers: await _headers(repo),
  );
  if (res.statusCode != 200) {
    throw Exception('Failed to load milestones (${res.statusCode})');
  }
  return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
});

// ════════════════════════════════════════════════════════════════════════════
class MilestoneRewardsScreen extends ConsumerWidget {
  const MilestoneRewardsScreen({super.key});

  Future<void> _delete(BuildContext ctx, WidgetRef ref, String id) async {
    final repo = ref.read(_repoProvider);
    final res = await http.delete(
      Uri.parse('${AuthRepository.baseUrl}/admin/milestones/$id'),
      headers: await _headers(repo),
    );
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(res.statusCode == 200 ? 'Milestone deleted' : 'Failed'),
        backgroundColor: res.statusCode == 200 ? _C.green : _C.coral,
      ));
      if (res.statusCode == 200) ref.invalidate(_milestonesProvider);
    }
  }

  Future<void> _toggle(WidgetRef ref, Map<String, dynamic> m) async {
    final repo = ref.read(_repoProvider);
    final updated = Map<String, dynamic>.from(m)
      ..['is_active'] = !(m['is_active'] as bool? ?? true);
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/admin/milestones/${m['id']}'),
      headers: await _headers(repo),
      body: jsonEncode(updated),
    );
    if (res.statusCode == 200) ref.invalidate(_milestonesProvider);
  }

  void _openSheet(BuildContext ctx, WidgetRef ref,
      {Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MilestoneSheet(
        existing: existing,
        onSaved: () => ref.invalidate(_milestonesProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_milestonesProvider);

    return Scaffold(
      backgroundColor: _C.cream,
      body: SafeArea(
        child: Stack(children: [
          const _BackgroundBlobs(),
          Column(children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _C.paper,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _C.line, width: 1.4),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: _C.navy),
                  ),
                ),
                const SizedBox(width: 12),
                const _HeaderTitle('Milestone Rewards', '里程碑奖励', '🏆'),
              ]),
            ),
            const SizedBox(height: 8),
            // ── summary strip ────────────────────────────────────────────
            async.maybeWhen(
              data: (milestones) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  _SummaryPill(
                    label: '${milestones.length} Total',
                    labelCn: '共计',
                    color: _C.navy,
                    pale: _C.sunshineGlow,
                  ),
                  const SizedBox(width: 8),
                  _SummaryPill(
                    label:
                        '${milestones.where((m) => m['is_active'] == true).length} Active',
                    labelCn: '启用',
                    color: _C.green,
                    pale: _C.greenPale,
                  ),
                  const SizedBox(width: 8),
                  _SummaryPill(
                    label:
                        '${milestones.where((m) => m['applies_to'] == 'student').length} Student',
                    labelCn: '学生',
                    color: _C.coral,
                    pale: _C.coralSoft,
                  ),
                ]),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            // ── List ────────────────────────────────────────────────────
            Expanded(
              child: async.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: _C.coral)),
                error: (e, _) => _ErrorView(
                    error: '$e',
                    onRetry: () => ref.invalidate(_milestonesProvider)),
                data: (milestones) {
                  if (milestones.isEmpty) {
                    return const _NiceEmpty(
                      emoji: '🏅',
                      title: 'No milestones yet',
                      titleCn: '暂无里程碑',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    itemCount: milestones.length,
                    itemBuilder: (_, i) => _MilestoneCard(
                      milestone: milestones[i],
                      onEdit: () =>
                          _openSheet(context, ref, existing: milestones[i]),
                      onDelete: () =>
                          _delete(context, ref, milestones[i]['id']),
                      onToggle: () => _toggle(ref, milestones[i]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ]),
      ),
      floatingActionButton: _GlowFab(
        onTap: () => _openSheet(context, ref),
        label: 'New Milestone · 新建里程碑',
      ),
    );
  }
}

// ── Milestone card ───────────────────────────────────────────────────────────
class _MilestoneCard extends StatelessWidget {
  final Map<String, dynamic> milestone;
  final VoidCallback onEdit, onDelete, onToggle;
  const _MilestoneCard({
    required this.milestone,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final m = milestone;
    final active = m['is_active'] as bool? ?? true;
    final emoji = m['emoji'] as String? ?? '🏅';
    final credits = _asNum(m['reward_credits']);
    final points = _asNum(m['reward_points']);
    final threshold = _asNum(m['threshold'], 1);
    final metric = m['metric'] as String? ?? 'sessions_completed';
    final appliesTo = m['applies_to'] as String? ?? 'all';

    return Opacity(
      opacity: active ? 1.0 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _C.paper,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _C.line, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: _C.sunshineDeep.withValues(alpha: 0.10),
              blurRadius: 0.1,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
              child: Row(children: [
                // emoji badge
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_C.sunshineGlow, _C.coralSoft]),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                          color: _C.sunshine.withValues(alpha: 0.4),
                          blurRadius: 0.1,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(m['title'] ?? '—',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _C.navy)),
                      if ((m['title_cn'] ?? '').toString().isNotEmpty)
                        Text(m['title_cn'],
                            style: const TextStyle(
                                fontSize: 11,
                                color: _C.coral,
                                fontWeight: FontWeight.w700)),
                      if ((m['description'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(m['description'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: _C.inkSoft)),
                      ],
                    ])),
                // active toggle
                GestureDetector(
                  onTap: onToggle,
                  child: Icon(
                    active ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                    color: active ? _C.green : _C.inkSoft,
                    size: 32,
                  ),
                ),
              ]),
            ),
            // ── Rewards row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                if (credits > 0) ...[
                  _RewardBadge(
                      label: '+${credits.toInt()} credits',
                      icon: Icons.diamond_rounded,
                      color: _C.navy,
                      pale: _C.sunshineGlow),
                  const SizedBox(width: 6),
                ],
                if (points > 0)
                  _RewardBadge(
                      label: '+${points.toInt()} pts',
                      icon: Icons.emoji_events_rounded,
                      color: _C.coral,
                      pale: _C.coralSoft),
                const Spacer(),
                _MetaBadge(label: '${threshold.toInt()}× ${_metricLabel(metric)}'),
              ]),
            ),
            // ── Footer ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
              child: Row(children: [
                _Chip(
                  label: appliesTo == 'all'
                      ? 'All · 全部'
                      : appliesTo == 'student'
                          ? 'Students · 学生'
                          : 'Teachers · 老师',
                  color: _C.inkSoft,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _C.sunshineGlow.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        size: 15, color: _C.navy),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _confirmDelete(context),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _C.coralSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 15, color: _C.coral),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  String _metricLabel(String metric) {
    return switch (metric) {
      'sessions_completed' => 'sessions done',
      'sessions_booked' => 'sessions booked',
      'referrals' => 'referrals',
      'streak_days' => 'day streak',
      'credits_spent' => 'credits spent',
      _ => metric.replaceAll('_', ' '),
    };
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Milestone?',
            style: TextStyle(fontWeight: FontWeight.w800, color: _C.navy)),
        content: Text('Remove "${milestone['title']}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: _C.inkSoft))),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: _C.coral, borderRadius: BorderRadius.circular(12)),
              child: const Text('Delete',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color, pale;
  const _RewardBadge(
      {required this.label,
      required this.icon,
      required this.color,
      required this.pale});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: pale,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _MetaBadge extends StatelessWidget {
  final String label;
  const _MetaBadge({required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: _C.purplePale,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10, color: _C.purple, fontWeight: FontWeight.w800)),
      );
}

// ── Create / edit sheet ──────────────────────────────────────────────────────
class _MilestoneSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _MilestoneSheet({this.existing, required this.onSaved});
  @override
  ConsumerState<_MilestoneSheet> createState() => _MilestoneSheetState();
}

class _MilestoneSheetState extends ConsumerState<_MilestoneSheet> {
  final _titleCtrl = TextEditingController();
  final _titleCnCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _creditsCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController();
  final _threshCtrl = TextEditingController();
  String _metric = 'sessions_completed';
  String _appliesTo = 'all';
  String _emoji = '🏅';
  bool _saving = false;

  static const _metrics = [
    'sessions_completed',
    'sessions_booked',
    'referrals',
    'streak_days',
    'credits_spent',
  ];

  static const _emojiOptions = [
    '🏅',
    '🎉',
    '🌟',
    '🔥',
    '💪',
    '🎓',
    '🏆',
    '✨',
    '🚀',
    '💎',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e['title'] ?? '';
      _titleCnCtrl.text = e['title_cn'] ?? '';
      _descCtrl.text = e['description'] ?? '';
      _creditsCtrl.text = '${_asNum(e['reward_credits']).toInt()}';
      _pointsCtrl.text = '${_asNum(e['reward_points']).toInt()}';
      _threshCtrl.text = '${_asNum(e['threshold'], 1).toInt()}';
      _metric = e['metric'] ?? 'sessions_completed';
      _appliesTo = e['applies_to'] ?? 'all';
      _emoji = e['emoji'] ?? '🏅';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _titleCnCtrl.dispose();
    _descCtrl.dispose();
    _creditsCtrl.dispose();
    _pointsCtrl.dispose();
    _threshCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _threshCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Title and threshold are required'),
        backgroundColor: _C.coral,
      ));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(_repoProvider);
    final headers = await _headers(repo);
    final body = jsonEncode({
      'title': _titleCtrl.text.trim(),
      'title_cn': _titleCnCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'emoji': _emoji,
      'threshold': int.tryParse(_threshCtrl.text) ?? 1,
      'metric': _metric,
      'reward_credits': int.tryParse(_creditsCtrl.text) ?? 0,
      'reward_points': int.tryParse(_pointsCtrl.text) ?? 0,
      'applies_to': _appliesTo,
      'is_active': true,
    });

    try {
      final http.Response res;
      if (widget.existing != null) {
        res = await http.patch(
          Uri.parse(
              '${AuthRepository.baseUrl}/admin/milestones/${widget.existing!['id']}'),
          headers: headers,
          body: body,
        );
      } else {
        res = await http.post(
          Uri.parse('${AuthRepository.baseUrl}/admin/milestones'),
          headers: headers,
          body: body,
        );
      }
      if (mounted) {
        String message = res.statusCode < 300
            ? (widget.existing != null
                ? 'Milestone updated ✓'
                : 'Milestone created ✓')
            : 'Failed (${res.statusCode})';
        if (res.statusCode >= 400) {
          try {
            message = jsonDecode(res.body)['error'] ?? message;
          } catch (_) {}
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: res.statusCode < 300 ? _C.green : _C.coral,
        ));
        if (res.statusCode < 300) {
          widget.onSaved();
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: _C.coral));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        decoration: const BoxDecoration(
          color: _C.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                          color: _C.line,
                          borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Text(_emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                      widget.existing != null
                          ? 'Edit Milestone · 编辑里程碑'
                          : 'New Milestone · 新建里程碑',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _C.navy)),
                ]),
                const SizedBox(height: 16),

                // emoji picker
                const _SectionLabel('Icon · 图标'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _emojiOptions
                        .map((e) => GestureDetector(
                              onTap: () => setState(() => _emoji = e),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                width: 44,
                                height: 44,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color:
                                      _emoji == e ? _C.sunshineGlow : _C.paper,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color:
                                          _emoji == e ? _C.sunshine : _C.line,
                                      width: 1.6),
                                ),
                                child: Center(
                                    child: Text(e,
                                        style: const TextStyle(fontSize: 22))),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 14),

                _GlowField(
                    controller: _titleCtrl,
                    label: 'Title (EN)',
                    icon: Icons.emoji_events_rounded),
                const SizedBox(height: 10),
                _GlowField(
                    controller: _titleCnCtrl,
                    label: '标题 (中文)',
                    icon: Icons.translate_rounded),
                const SizedBox(height: 10),
                _GlowField(
                    controller: _descCtrl,
                    label: 'Description · 描述',
                    icon: Icons.notes_rounded),
                const SizedBox(height: 14),

                // threshold + metric
                const _SectionLabel('Threshold & Metric · 目标 & 指标'),
                const SizedBox(height: 8),
                Row(children: [
                  SizedBox(
                    width: 90,
                    child: _GlowField(
                        controller: _threshCtrl,
                        label: 'Threshold',
                        icon: Icons.flag_rounded,
                        numeric: true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DropdownField<String>(
                      value: _metric,
                      items: _metrics,
                      label: (t) => t.replaceAll('_', ' '),
                      onChanged: (v) => setState(() => _metric = v!),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),

                // rewards
                const _SectionLabel('Rewards · 奖励'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: _GlowField(
                          controller: _creditsCtrl,
                          label: '💎 Credits',
                          icon: Icons.diamond_rounded,
                          numeric: true)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _GlowField(
                          controller: _pointsCtrl,
                          label: '⭐ Points',
                          icon: Icons.star_rounded,
                          numeric: true)),
                ]),
                const SizedBox(height: 14),

                // applies to
                const _SectionLabel('Applies to · 适用对象'),
                const SizedBox(height: 8),
                Row(children: [
                  for (final opt in ['all', 'student', 'teacher'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _SheetToggle(
                        label: opt == 'all'
                            ? 'All · 全部'
                            : opt == 'student'
                                ? 'Students'
                                : 'Teachers',
                        active: _appliesTo == opt,
                        onTap: () => setState(() => _appliesTo = opt),
                      ),
                    ),
                ]),
                const SizedBox(height: 22),

                _SaveButton(
                    label: widget.existing != null
                        ? 'Update Milestone · 更新'
                        : 'Create Milestone · 创建',
                    saving: _saving,
                    onTap: _save),
              ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared widgets
// ══════════════════════════════════════════════════════════════════════════════

class _SummaryPill extends StatelessWidget {
  final String label, labelCn;
  final Color color, pale;
  const _SummaryPill(
      {required this.label,
      required this.labelCn,
      required this.color,
      required this.pale});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration:
            BoxDecoration(color: pale, borderRadius: BorderRadius.circular(12)),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                  text: label,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: color)),
              TextSpan(
                  text: ' · $labelCn',
                  style: const TextStyle(fontSize: 10, color: _C.inkSoft)),
            ],
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w700)),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800, color: _C.inkSoft));
}

class _SheetToggle extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SheetToggle(
      {required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(colors: [_C.sunshine, _C.coral])
                : null,
            color: active ? null : _C.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: active ? Colors.transparent : _C.line, width: 1.4),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: _C.coral.withValues(alpha: 0.3),
                        blurRadius: 0.1,
                        offset: const Offset(0, 3))
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

class _GlowField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool numeric;
  const _GlowField({
    required this.controller,
    required this.label,
    required this.icon,
    this.numeric = false,
  });
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _C.coral, size: 18),
          filled: true,
          fillColor: _C.paper,
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

class _DropdownField<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T?> onChanged;
  const _DropdownField({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _C.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.line, width: 1.4),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded,
                color: _C.inkSoft, size: 20),
            items: items
                .map((i) => DropdownMenuItem(
                    value: i,
                    child: Text(label(i),
                        style: const TextStyle(
                            fontSize: 13,
                            color: _C.navy,
                            fontWeight: FontWeight.w700))))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      );
}

class _SaveButton extends StatelessWidget {
  final String label;
  final bool saving;
  final VoidCallback onTap;
  const _SaveButton(
      {required this.label, required this.saving, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: saving ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_C.sunshine, _C.coral]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: _C.coral.withValues(alpha: 0.4),
                  blurRadius: 0.1,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
        ),
      );
}

class _GlowFab extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  const _GlowFab({required this.onTap, required this.label});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_C.sunshine, _C.coral]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: _C.coral.withValues(alpha: 0.5),
                  blurRadius: 0.1,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
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

class _HeaderTitle extends StatelessWidget {
  final String en, zh, emoji;
  const _HeaderTitle(this.en, this.zh, this.emoji);
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [_C.sunshine, _C.coral]),
            boxShadow: [
              BoxShadow(
                  color: _C.coral.withValues(alpha: 0.4),
                  blurRadius: 0.1,
                  offset: const Offset(0, 3)),
            ],
          ),
          child:
              Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(en,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: _C.navy)),
          Text('· $zh',
              style: const TextStyle(
                  fontSize: 11, color: _C.coral, fontWeight: FontWeight.w700)),
        ]),
      ]);
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
                    fontSize: 15, fontWeight: FontWeight.w800, color: _C.navy)),
            Text('· $titleCn',
                style: const TextStyle(fontSize: 12, color: _C.coral)),
          ]),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _C.paper,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.coralSoft, width: 1.4),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('⚠️', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 10),
              Text(error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: _C.inkSoft)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [_C.sunshine, _C.coral]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('Retry',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ),
        ),
      );
}

class _BackgroundBlobs extends StatelessWidget {
  const _BackgroundBlobs();
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(children: [
          Positioned(
              top: -60,
              right: -70,
              child: _blob(180, _C.sunshineGlow.withValues(alpha: 0.55))),
          Positioned(
              top: 140,
              left: -80,
              child: _blob(150, _C.blushSoft.withValues(alpha: 0.6))),
          Positioned(
              bottom: 80,
              right: -60,
              child: _blob(140, _C.coralSoft.withValues(alpha: 0.5))),
        ]),
      );

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      );
}