// lib/features/dashboard/admin/session_pricing_screen.dart
//
// Admin screen — Session Pricing (课程定价)
// Manages pricing tiers / packages. The admin can set a base credit cost per
// session type and create special "packages" (e.g. 10 sessions for 80 credits
// instead of 100 = 20 % discount). Teachers' own creditsPerSession values
// can be overridden here by pinning a fixed price to a session type.
//
// API assumed endpoints
//   GET    /admin/pricing             → List<PricingTier>
//   POST   /admin/pricing             → PricingTier   (body: PricingPayload)
//   PATCH  /admin/pricing/:id         → PricingTier
//   DELETE /admin/pricing/:id         → { deleted: true }
//
// PricingTier JSON shape
// {
//   "id": "uuid",
//   "name": "Standard Session",
//   "name_cn": "标准课程",
//   "session_type": "standard" | "trial" | "group" | "intensive",
//   "credits_per_session": 10,
//   "sessions_in_package": 1,          // > 1 → it's a bundle
//   "total_credits": 10,               // credits_per_session * sessions_in_package (may differ for discount)
//   "discount_pct": 0,                 // 0-100
//   "applies_to": "student" | "teacher" | "all",
//   "is_active": true,
//   "created_at": "ISO8601"
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../auth/repositories/auth_repository.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
class _C {
  static const sunshine     = Color(0xFFFFC93C);
  static const sunshineDeep = Color(0xFFFFB100);
  static const sunshineGlow = Color(0xFFFFE49A);
  static const navy         = Color(0xFF142850);
  static const navySoft     = Color(0xFF274472);
  static const coral        = Color(0xFFFF6F61);
  static const coralSoft    = Color(0xFFFFD9CC);
  static const blushSoft    = Color(0xFFFCE0E6);
  static const cream        = Color(0xFFFFF8E7);
  static const paper        = Color(0xFFFFFFFF);
  static const inkSoft      = Color(0xFF6E7593);
  static const line         = Color(0xFFFFE8B8);
  static const green        = Color(0xFF00C48C);
  static const greenPale    = Color(0xFFDFFBEF);
  static const teal         = Color(0xFF0097A7);
  static const tealPale     = Color(0xFFE0F7FA);
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

final _pricingProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(_repoProvider);
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/admin/pricing'),
    headers: await _headers(repo),
  );
  if (res.statusCode != 200) {
    throw Exception('Failed to load pricing (${res.statusCode})');
  }
  return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
});

// ════════════════════════════════════════════════════════════════════════════
class SessionPricingScreen extends ConsumerStatefulWidget {
  const SessionPricingScreen({super.key});
  @override
  ConsumerState<SessionPricingScreen> createState() =>
      _SessionPricingScreenState();
}

class _SessionPricingScreenState
    extends ConsumerState<SessionPricingScreen> {
  String _filter = 'all'; // 'all' | 'standard' | 'trial' | 'group' | 'intensive'

  static const _sessionTypes = [
    'all', 'standard', 'trial', 'group', 'intensive',
  ];

  Future<void> _delete(String id) async {
    final repo = ref.read(_repoProvider);
    final res = await http.delete(
      Uri.parse('${AuthRepository.baseUrl}/admin/pricing/$id'),
      headers: await _headers(repo),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            res.statusCode == 200 ? 'Tier deleted' : 'Failed'),
        backgroundColor:
            res.statusCode == 200 ? _C.green : _C.coral,
      ));
      if (res.statusCode == 200) ref.invalidate(_pricingProvider);
    }
  }

  Future<void> _toggle(Map<String, dynamic> tier) async {
    final repo = ref.read(_repoProvider);
    final updated = Map<String, dynamic>.from(tier)
      ..['is_active'] = !(tier['is_active'] as bool? ?? true);
    final res = await http.patch(
      Uri.parse(
          '${AuthRepository.baseUrl}/admin/pricing/${tier['id']}'),
      headers: await _headers(repo),
      body: jsonEncode(updated),
    );
    if (res.statusCode == 200) ref.invalidate(_pricingProvider);
  }

  void _openSheet({Map<String, dynamic>? tier}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PricingSheet(
        existing: tier,
        onSaved: () => ref.invalidate(_pricingProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_pricingProvider);

    return Scaffold(
      backgroundColor: _C.cream,
      body: SafeArea(
        child: Stack(children: [
          const _BackgroundBlobs(),
          Column(children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _C.paper,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _C.line, width: 1.4),
                    ),
                    child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: _C.navy),
                  ),
                ),
                const SizedBox(width: 12),
                const _HeaderTitle(
                    'Session Pricing', '课程定价', '💰'),
              ]),
            ),
            const SizedBox(height: 8),

            // ── summary strip ────────────────────────────────────────────
            async.maybeWhen(
              data: (tiers) {
                final totalActive =
                    tiers.where((t) => t['is_active'] == true).length;
                final bundles = tiers
                    .where((t) =>
                        (t['sessions_in_package'] as num? ?? 1) > 1)
                    .length;
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    _SummaryPill(
                        label: '${tiers.length} Tiers',
                        labelCn: '定价层',
                        color: _C.navy,
                        pale: _C.sunshineGlow),
                    const SizedBox(width: 8),
                    _SummaryPill(
                        label: '$totalActive Active',
                        labelCn: '启用',
                        color: _C.green,
                        pale: _C.greenPale),
                    const SizedBox(width: 8),
                    _SummaryPill(
                        label: '$bundles Bundles',
                        labelCn: '套餐',
                        color: _C.teal,
                        pale: _C.tealPale),
                  ]),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),

            // ── Session type filter chips ────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _sessionTypes.map((t) {
                  final active = _filter == t;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: active
                            ? const LinearGradient(
                                colors: [_C.sunshine, _C.coral])
                            : null,
                        color: active ? null : _C.paper,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: active
                                ? Colors.transparent
                                : _C.line,
                            width: 1.4),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                    color: _C.coral
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3))
                              ]
                            : null,
                      ),
                      child: Text(
                          t == 'all' ? 'All · 全部' : _typeLabelBilingual(t),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: active
                                  ? Colors.white
                                  : _C.inkSoft)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),

            // ── List ────────────────────────────────────────────────────
            Expanded(
              child: async.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: _C.coral)),
                error: (e, _) => _ErrorView(
                    error: '$e',
                    onRetry: () =>
                        ref.invalidate(_pricingProvider)),
                data: (tiers) {
                  final filtered = _filter == 'all'
                      ? tiers
                      : tiers
                          .where((t) =>
                              t['session_type'] == _filter)
                          .toList();

                  if (filtered.isEmpty) {
                    return const _NiceEmpty(
                      emoji: '💸',
                      title: 'No pricing tiers yet',
                      titleCn: '暂无定价',
                    );
                  }

                  return ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _PricingCard(
                      tier: filtered[i],
                      onEdit: () =>
                          _openSheet(tier: filtered[i]),
                      onDelete: () =>
                          _delete(filtered[i]['id']),
                      onToggle: () => _toggle(filtered[i]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ]),
      ),
      floatingActionButton: _GlowFab(
        onTap: () => _openSheet(),
        label: 'New Tier · 新建定价',
      ),
    );
  }

  String _typeLabelBilingual(String type) {
    return switch (type) {
      'standard'  => 'Standard · 标准',
      'trial'     => 'Trial · 试课',
      'group'     => 'Group · 小组',
      'intensive' => 'Intensive · 强化',
      _           => type,
    };
  }
}

// ── Pricing card ─────────────────────────────────────────────────────────────
class _PricingCard extends StatelessWidget {
  final Map<String, dynamic> tier;
  final VoidCallback onEdit, onDelete, onToggle;
  const _PricingCard({
    required this.tier,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t             = tier;
    final active        = t['is_active'] as bool? ?? true;
    final sessionType   = t['session_type'] as String? ?? 'standard';
    final creditsPerSes = t['credits_per_session'] as num? ?? 0;
    final sessionsInPkg = t['sessions_in_package'] as num? ?? 1;
    final totalCredits  = t['total_credits'] as num? ?? creditsPerSes;
    final discountPct   = t['discount_pct'] as num? ?? 0;
    final isBundle      = sessionsInPkg > 1;

    final typeColor = _typeColor(sessionType);
    final typePale  = _typePale(sessionType);

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
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(children: [
          // ── Top ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 0),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: typePale,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                    child: Text(_typeEmoji(sessionType),
                        style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text(t['name'] ?? '—',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _C.navy)),
                if ((t['name_cn'] ?? '').isNotEmpty)
                  Text(t['name_cn'],
                      style: const TextStyle(
                          fontSize: 11,
                          color: _C.coral,
                          fontWeight: FontWeight.w700)),
              ])),
              // active toggle
              GestureDetector(
                onTap: onToggle,
                child: Icon(
                  active
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  color: active ? _C.green : _C.inkSoft,
                  size: 32,
                ),
              ),
            ]),
          ),
          // ── Price info ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [typePale, typePale.withValues(alpha: 0.4)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                // Per session cost
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Per Session',
                        style: TextStyle(
                            fontSize: 10,
                            color: typeColor,
                            fontWeight: FontWeight.w700)),
                    Text('$creditsPerSes 💎',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: typeColor)),
                  ]),
                ),
                if (isBundle) ...[
                  Container(
                      width: 1, height: 36, color: _C.line),
                  const SizedBox(width: 12),
                  // bundle total
                  Expanded(
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      Text('$sessionsInPkg-session bundle',
                          style: const TextStyle(
                              fontSize: 10,
                              color: _C.inkSoft,
                              fontWeight: FontWeight.w700)),
                      Text('$totalCredits 💎 total',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _C.navy)),
                    ]),
                  ),
                  if (discountPct > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _C.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('-$discountPct%',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w900)),
                    ),
                ],
              ]),
            ),
          ),
          // ── Footer ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
            child: Row(children: [
              _Chip(
                  label: _typeLabelBilingual(sessionType),
                  color: typeColor),
              const SizedBox(width: 6),
              _Chip(
                label: (t['applies_to'] ?? 'all') == 'all'
                    ? 'All · 全部'
                    : (t['applies_to'] == 'student'
                        ? 'Students · 学生'
                        : 'Teachers · 老师'),
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
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Tier?',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: _C.navy)),
        content: Text(
            'Remove "${tier['name']}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: _C.inkSoft))),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: _C.coral,
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('Delete',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String t) => switch (t) {
        'trial'     => _C.green,
        'group'     => _C.teal,
        'intensive' => _C.coral,
        _           => _C.navy,
      };

  Color _typePale(String t) => switch (t) {
        'trial'     => _C.greenPale,
        'group'     => _C.tealPale,
        'intensive' => _C.coralSoft,
        _           => _C.sunshineGlow,
      };

  String _typeEmoji(String t) => switch (t) {
        'trial'     => '🎯',
        'group'     => '👥',
        'intensive' => '⚡',
        _           => '📚',
      };

  String _typeLabelBilingual(String t) => switch (t) {
        'trial'     => 'Trial · 试课',
        'group'     => 'Group · 小组',
        'intensive' => 'Intensive · 强化',
        _           => 'Standard · 标准',
      };
}

// ── Create / edit pricing sheet ──────────────────────────────────────────────
class _PricingSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _PricingSheet({this.existing, required this.onSaved});
  @override
  ConsumerState<_PricingSheet> createState() =>
      _PricingSheetState();
}

class _PricingSheetState extends ConsumerState<_PricingSheet> {
  final _nameCtrl        = TextEditingController();
  final _nameCnCtrl      = TextEditingController();
  final _creditsCtrl     = TextEditingController();
  final _sessionsCtrl    = TextEditingController(text: '1');
  final _totalCtrl       = TextEditingController();
  final _discountCtrl    = TextEditingController(text: '0');
  String _sessionType    = 'standard';
  String _appliesTo      = 'all';
  bool   _isBundle       = false;
  bool   _saving         = false;

  static const _types = [
    'standard', 'trial', 'group', 'intensive',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text     = e['name']                 ?? '';
      _nameCnCtrl.text   = e['name_cn']              ?? '';
      _creditsCtrl.text  = '${e['credits_per_session'] ?? ''}';
      _sessionsCtrl.text = '${e['sessions_in_package'] ?? 1}';
      _totalCtrl.text    = '${e['total_credits']       ?? ''}';
      _discountCtrl.text = '${e['discount_pct']        ?? 0}';
      _sessionType       = e['session_type']           ?? 'standard';
      _appliesTo         = e['applies_to']             ?? 'all';
      _isBundle =
          (e['sessions_in_package'] as num? ?? 1) > 1;
    }
    // Auto-compute total when credits or sessions change
    _creditsCtrl.addListener(_autoTotal);
    _sessionsCtrl.addListener(_autoTotal);
    _discountCtrl.addListener(_autoTotal);
  }

  void _autoTotal() {
    final c  = int.tryParse(_creditsCtrl.text) ?? 0;
    final s  = int.tryParse(_sessionsCtrl.text) ?? 1;
    final d  = double.tryParse(_discountCtrl.text) ?? 0;
    final raw = c * s;
    final discounted = (raw * (1 - d / 100)).round();
    if (_totalCtrl.text != '$discounted') {
      _totalCtrl.text = '$discounted';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameCnCtrl.dispose();
    _creditsCtrl.dispose();
    _sessionsCtrl.dispose();
    _totalCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _creditsCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Name and credits per session are required'),
        backgroundColor: _C.coral,
      ));
      return;
    }
    setState(() => _saving = true);
    final repo    = ref.read(_repoProvider);
    final headers = await _headers(repo);
    final body    = jsonEncode({
      'name':                _nameCtrl.text.trim(),
      'name_cn':             _nameCnCtrl.text.trim(),
      'session_type':        _sessionType,
      'credits_per_session': int.tryParse(_creditsCtrl.text)  ?? 0,
      'sessions_in_package': int.tryParse(_sessionsCtrl.text) ?? 1,
      'total_credits':       int.tryParse(_totalCtrl.text)    ?? 0,
      'discount_pct':        double.tryParse(_discountCtrl.text) ?? 0,
      'applies_to':          _appliesTo,
      'is_active':           true,
    });

    try {
      final http.Response res;
      if (widget.existing != null) {
        res = await http.patch(
          Uri.parse(
              '${AuthRepository.baseUrl}/admin/pricing/${widget.existing!['id']}'),
          headers: headers,
          body: body,
        );
      } else {
        res = await http.post(
          Uri.parse('${AuthRepository.baseUrl}/admin/pricing'),
          headers: headers,
          body: body,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.statusCode < 300
              ? (widget.existing != null
                  ? 'Tier updated ✓'
                  : 'Tier created ✓')
              : 'Failed (${res.statusCode})'),
          backgroundColor:
              res.statusCode < 300 ? _C.green : _C.coral,
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
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        decoration: const BoxDecoration(
          color: _C.cream,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(28)),
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
              const Text('💰', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                  widget.existing != null
                      ? 'Edit Pricing · 编辑定价'
                      : 'New Pricing Tier · 新建定价',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _C.navy)),
            ]),
            const SizedBox(height: 18),

            // session type
            _SectionLabel('Session Type · 课程类型'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _types
                .map((t) => _SheetToggle(
                      label: _typeLabel(t),
                      active: _sessionType == t,
                      onTap: () =>
                          setState(() => _sessionType = t),
                    ))
                .toList()),
            const SizedBox(height: 14),

            _GlowField(
                controller: _nameCtrl,
                label: 'Tier name (EN)',
                icon: Icons.label_rounded),
            const SizedBox(height: 10),
            _GlowField(
                controller: _nameCnCtrl,
                label: '套餐名称 (中文)',
                icon: Icons.translate_rounded),
            const SizedBox(height: 14),

            // credits per session
            _SectionLabel('Credits per session · 每节课积分'),
            const SizedBox(height: 8),
            _GlowField(
                controller: _creditsCtrl,
                label: 'Credits per session',
                icon: Icons.diamond_rounded,
                numeric: true),
            const SizedBox(height: 14),

            // bundle toggle
            Row(children: [
              const Expanded(
                  child: _SectionLabel(
                      'Bundle / Package · 套餐')),
              Switch(
                value: _isBundle,
                activeColor: _C.coral,
                onChanged: (v) {
                  setState(() {
                    _isBundle = v;
                    if (!v) {
                      _sessionsCtrl.text = '1';
                      _discountCtrl.text = '0';
                    }
                    _autoTotal();
                  });
                },
              ),
            ]),
            if (_isBundle) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _GlowField(
                      controller: _sessionsCtrl,
                      label: '# of sessions',
                      icon: Icons.repeat_rounded,
                      numeric: true),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GlowField(
                      controller: _discountCtrl,
                      label: 'Discount %',
                      icon: Icons.percent_rounded,
                      numeric: true),
                ),
              ]),
              const SizedBox(height: 10),
              // total preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _C.greenPale,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _C.green.withValues(alpha: 0.4),
                      width: 1.4),
                ),
                child: Row(children: [
                  const Icon(Icons.calculate_rounded,
                      color: _C.green, size: 18),
                  const SizedBox(width: 8),
                  const Text('Bundle total: ',
                      style: TextStyle(
                          fontSize: 12,
                          color: _C.inkSoft,
                          fontWeight: FontWeight.w700)),
                  Expanded(
                    child: TextField(
                      controller: _totalCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: _C.green),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        suffix: Text(' 💎',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 14),

            // applies to
            _SectionLabel('Applies to · 适用对象'),
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
                    onTap: () =>
                        setState(() => _appliesTo = opt),
                  ),
                ),
            ]),
            const SizedBox(height: 22),

            _SaveButton(
                label: widget.existing != null
                    ? 'Update Tier · 更新'
                    : 'Create Tier · 创建',
                saving: _saving,
                onTap: _save),
          ]),
        ),
      ),
    );
  }

  String _typeLabel(String t) => switch (t) {
        'trial'     => 'Trial · 试课',
        'group'     => 'Group · 小组',
        'intensive' => 'Intensive · 强化',
        _           => 'Standard · 标准',
      };
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
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: pale, borderRadius: BorderRadius.circular(12)),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                  text: label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color)),
              TextSpan(
                  text: ' · $labelCn',
                  style: const TextStyle(
                      fontSize: 10, color: _C.inkSoft)),
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
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w700)),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _C.inkSoft));
}

class _SheetToggle extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SheetToggle(
      {required this.label,
      required this.active,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [_C.sunshine, _C.coral])
                : null,
            color: active ? null : _C.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color:
                    active ? Colors.transparent : _C.line,
                width: 1.4),
            boxShadow: active
                ? [
                    BoxShadow(
                        color: _C.coral.withValues(alpha: 0.3),
                        blurRadius: 8,
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
        keyboardType:
            numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _C.coral, size: 18),
          filled: true,
          fillColor: _C.paper,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: _C.line, width: 1.4)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: _C.line, width: 1.4)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: _C.coral, width: 1.6)),
        ),
      );
}

class _SaveButton extends StatelessWidget {
  final String label;
  final bool saving;
  final VoidCallback onTap;
  const _SaveButton(
      {required this.label,
      required this.saving,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: saving ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_C.sunshine, _C.coral]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: _C.coral.withValues(alpha: 0.4),
                  blurRadius: 12,
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
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_C.sunshine, _C.coral]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: _C.coral.withValues(alpha: 0.5),
                  blurRadius: 18,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded,
                color: Colors.white, size: 20),
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
            gradient: const LinearGradient(
                colors: [_C.sunshine, _C.coral]),
            boxShadow: [
              BoxShadow(
                  color: _C.coral.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Center(
              child: Text(emoji,
                  style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(en,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _C.navy)),
          Text('· $zh',
              style: const TextStyle(
                  fontSize: 11,
                  color: _C.coral,
                  fontWeight: FontWeight.w700)),
        ]),
      ]);
}

class _NiceEmpty extends StatelessWidget {
  final String emoji, title, titleCn;
  const _NiceEmpty(
      {required this.emoji,
      required this.title,
      required this.titleCn});
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
              color: _C.sunshineGlow.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _C.line, width: 1.4)),
          child:
              Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _C.navy)),
            Text('· $titleCn',
                style: const TextStyle(
                    fontSize: 12, color: _C.coral)),
          ]),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView(
      {required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _C.paper,
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: _C.coralSoft, width: 1.4),
            ),
            child:
                Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('⚠️',
                  style: TextStyle(fontSize: 32)),
              const SizedBox(height: 10),
              Text(error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: _C.inkSoft)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onRetry,
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
                          fontWeight: FontWeight.w800)),
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
              child: _blob(180,
                  _C.sunshineGlow.withValues(alpha: 0.55))),
          Positioned(
              top: 140,
              left: -80,
              child: _blob(
                  150, _C.blushSoft.withValues(alpha: 0.6))),
          Positioned(
              bottom: 80,
              right: -60,
              child: _blob(
                  140, _C.coralSoft.withValues(alpha: 0.5))),
        ]),
      );

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)]),
        ),
      );
}