// lib/features/dashboard/admin/credit_rules_screen.dart
//
// Admin screen — Credit & Point Rules (积分规则)
// Fetches existing rules from the API, lets the admin create / edit / delete
// earn rules (how students or teachers earn credits/points) and spend rules
// (how credits are deducted when a session is booked).
//
// API assumed endpoints
//   GET    /admin/credit-rules            → List<CreditRule>
//   POST   /admin/credit-rules            → CreditRule   (body: CreditRulePayload)
//   PATCH  /admin/credit-rules/:id        → CreditRule   (body: CreditRulePayload)
//   DELETE /admin/credit-rules/:id        → { deleted: true }
//
// CreditRule JSON shape
// {
//   "id": "uuid",
//   "name": "Book a session",
//   "name_cn": "预约课程",
//   "type": "earn" | "spend",
//   "currency": "credits" | "points",
//   "amount": 5,
//   "trigger": "booking_completed" | "referral" | "streak_7d" | ...,
//   "applies_to": "student" | "teacher" | "all",
//   "is_active": true,
//   "created_at": "ISO8601"
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../auth/repositories/auth_repository.dart';

// ── Palette (same family as admin_dashboard_screen.dart) ────────────────────
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

// ── Providers ────────────────────────────────────────────────────────────────
final _repoProvider = Provider((_) => AuthRepository());

Future<Map<String, String>> _headers(AuthRepository repo) async {
  final token = await repo.getAccessToken();
  return {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

final _rulesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(_repoProvider);
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/admin/credit-rules'),
    headers: await _headers(repo),
  );
  if (res.statusCode != 200) {
    throw Exception('Failed to load rules (${res.statusCode})');
  }
  return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
});

// ════════════════════════════════════════════════════════════════════════════
class CreditRulesScreen extends ConsumerStatefulWidget {
  const CreditRulesScreen({super.key});
  @override
  ConsumerState<CreditRulesScreen> createState() => _CreditRulesScreenState();
}

class _CreditRulesScreenState extends ConsumerState<CreditRulesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _deleteRule(String id) async {
    final repo = ref.read(_repoProvider);
    final res = await http.delete(
      Uri.parse('${AuthRepository.baseUrl}/admin/credit-rules/$id'),
      headers: await _headers(repo),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(res.statusCode == 200 ? 'Rule deleted' : 'Failed to delete'),
        backgroundColor: res.statusCode == 200 ? _C.green : _C.coral,
      ));
      if (res.statusCode == 200) ref.invalidate(_rulesProvider);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> rule) async {
    final repo = ref.read(_repoProvider);
    final updated = Map<String, dynamic>.from(rule)
      ..['is_active'] = !(rule['is_active'] as bool? ?? true);
    final res = await http.patch(
      Uri.parse('${AuthRepository.baseUrl}/admin/credit-rules/${rule['id']}'),
      headers: await _headers(repo),
      body: jsonEncode(updated),
    );
    if (mounted) {
      if (res.statusCode == 200) ref.invalidate(_rulesProvider);
    }
  }

  void _openSheet({Map<String, dynamic>? rule}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RuleSheet(
        existing: rule,
        onSaved: () => ref.invalidate(_rulesProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(_rulesProvider);

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
                const _HeaderTitle('Credit & Point Rules', '积分规则', '💎'),
              ]),
            ),
            // ── Tab bar ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: _C.paper,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.line, width: 1.4),
                ),
                child: TabBar(
                  controller: _tabs,
                  indicator: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [_C.sunshine, _C.coral]),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: _C.inkSoft,
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800),
                  tabs: const [
                    Tab(text: 'Earn Rules · 获得'),
                    Tab(text: 'Spend Rules · 消耗'),
                  ],
                ),
              ),
            ),
            // ── List ────────────────────────────────────────────────────────
            Expanded(
              child: rulesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: _C.coral)),
                error: (e, _) => _ErrorView(
                    error: '$e', onRetry: () => ref.invalidate(_rulesProvider)),
                data: (rules) {
                  final tabType = _tabs.index == 0 ? 'earn' : 'spend';
                  final filtered =
                      rules.where((r) => r['type'] == tabType).toList();

                  if (filtered.isEmpty) {
                    return _NiceEmpty(
                      emoji: _tabs.index == 0 ? '✨' : '💸',
                      title: _tabs.index == 0
                          ? 'No earn rules yet'
                          : 'No spend rules yet',
                      titleCn: _tabs.index == 0 ? '暂无获得规则' : '暂无消耗规则',
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _RuleCard(
                      rule: filtered[i],
                      onEdit: () => _openSheet(rule: filtered[i]),
                      onDelete: () => _deleteRule(filtered[i]['id']),
                      onToggle: () => _toggleActive(filtered[i]),
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
        label: 'New Rule · 新建规则',
      ),
    );
  }
}

// ── Rule card ────────────────────────────────────────────────────────────────
class _RuleCard extends StatelessWidget {
  final Map<String, dynamic> rule;
  final VoidCallback onEdit, onDelete, onToggle;
  const _RuleCard({
    required this.rule,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isEarn = rule['type'] == 'earn';
    final currency = rule['currency'] as String? ?? 'credits';
    final amount = rule['amount'] as num? ?? 0;
    final active = rule['is_active'] as bool? ?? true;
    final appliesTo = rule['applies_to'] as String? ?? 'all';

    final accentColor = isEarn ? _C.green : _C.coral;
    final paleBg = isEarn ? _C.greenPale : _C.coralSoft;
    final icon =
        isEarn ? Icons.add_circle_rounded : Icons.remove_circle_rounded;

    return Opacity(
      opacity: active ? 1.0 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _C.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.line, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: _C.sunshineDeep.withValues(alpha: 0.10),
              blurRadius: 0.1,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(children: [
          // ── Top row ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: paleBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rule['name'] ?? '—',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _C.navy)),
                  if ((rule['name_cn'] ?? '').isNotEmpty)
                    Text(rule['name_cn'],
                        style: const TextStyle(
                            fontSize: 11,
                            color: _C.coral,
                            fontWeight: FontWeight.w700)),
                ],
              )),
              // amount badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: paleBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${isEarn ? '+' : '-'}$amount ${currency == 'credits' ? '💎' : '⭐'}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: accentColor),
                ),
              ),
            ]),
          ),
          // ── Meta row ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(children: [
              _Chip(label: rule['trigger'] ?? '—', color: _C.navySoft),
              const SizedBox(width: 6),
              _Chip(
                label: appliesTo == 'all'
                    ? 'All · 全部'
                    : appliesTo == 'student'
                        ? 'Students · 学生'
                        : 'Teachers · 老师',
                color: _C.inkSoft,
              ),
              const Spacer(),
              // active toggle
              GestureDetector(
                onTap: onToggle,
                child: Icon(
                  active ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                  color: active ? _C.green : _C.inkSoft,
                  size: 30,
                ),
              ),
              const SizedBox(width: 6),
              // edit
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _C.sunshineGlow.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.edit_rounded, size: 15, color: _C.navy),
                ),
              ),
              const SizedBox(width: 6),
              // delete
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Rule?',
            style: TextStyle(fontWeight: FontWeight.w800, color: _C.navy)),
        content: Text('Remove "${rule['name']}"? This cannot be undone.'),
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

// ── Create / edit rule sheet ─────────────────────────────────────────────────
class _RuleSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _RuleSheet({this.existing, required this.onSaved});
  @override
  ConsumerState<_RuleSheet> createState() => _RuleSheetState();
}

class _RuleSheetState extends ConsumerState<_RuleSheet> {
  final _nameCtrl = TextEditingController();
  final _nameCnCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _type = 'earn';
  String _currency = 'credits';
  String _appliesTo = 'all';
  String _trigger = 'booking_completed';
  bool _saving = false;

  static const _triggers = [
    'booking_completed',
    'booking_cancelled',
    'referral',
    'streak_7d',
    'streak_30d',
    'manual',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e['name'] ?? '';
      _nameCnCtrl.text = e['name_cn'] ?? '';
      _amountCtrl.text = '${e['amount'] ?? ''}';
      _type = e['type'] ?? 'earn';
      _currency = e['currency'] ?? 'credits';
      _appliesTo = e['applies_to'] ?? 'all';
      _trigger = e['trigger'] ?? 'booking_completed';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameCnCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Name and amount are required'),
        backgroundColor: _C.coral,
      ));
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(_repoProvider);
    final headers = await _headers(repo);
    final body = jsonEncode({
      'name': _nameCtrl.text.trim(),
      'name_cn': _nameCnCtrl.text.trim(),
      'type': _type,
      'currency': _currency,
      'amount': int.tryParse(_amountCtrl.text) ?? 0,
      'trigger': _trigger,
      'applies_to': _appliesTo,
      'is_active': true,
    });

    try {
      final http.Response res;
      if (widget.existing != null) {
        res = await http.patch(
          Uri.parse(
              '${AuthRepository.baseUrl}/admin/credit-rules/${widget.existing!['id']}'),
          headers: headers,
          body: body,
        );
      } else {
        res = await http.post(
          Uri.parse('${AuthRepository.baseUrl}/admin/credit-rules'),
          headers: headers,
          body: body,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.statusCode < 300
              ? (widget.existing != null ? 'Rule updated ✓' : 'Rule created ✓')
              : 'Failed (${res.statusCode})'),
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
                  const Text('💎', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                      widget.existing != null
                          ? 'Edit Rule · 编辑规则'
                          : 'New Rule · 新建规则',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _C.navy)),
                ]),
                const SizedBox(height: 18),

                // type
                const _SectionLabel('Rule Type · 规则类型'),
                const SizedBox(height: 8),
                Row(children: [
                  _SheetToggle(
                      label: 'Earn · 获得',
                      active: _type == 'earn',
                      onTap: () => setState(() => _type = 'earn')),
                  const SizedBox(width: 8),
                  _SheetToggle(
                      label: 'Spend · 消耗',
                      active: _type == 'spend',
                      onTap: () => setState(() => _type = 'spend')),
                ]),
                const SizedBox(height: 14),

                // currency
                const _SectionLabel('Currency · 货币类型'),
                const SizedBox(height: 8),
                Row(children: [
                  _SheetToggle(
                      label: '💎 Credits',
                      active: _currency == 'credits',
                      onTap: () => setState(() => _currency = 'credits')),
                  const SizedBox(width: 8),
                  _SheetToggle(
                      label: '⭐ Points',
                      active: _currency == 'points',
                      onTap: () => setState(() => _currency = 'points')),
                ]),
                const SizedBox(height: 14),

                // name fields
                _GlowField(
                    controller: _nameCtrl,
                    label: 'Rule name (EN)',
                    icon: Icons.label_rounded),
                const SizedBox(height: 10),
                _GlowField(
                    controller: _nameCnCtrl,
                    label: '规则名称 (中文)',
                    icon: Icons.translate_rounded),
                const SizedBox(height: 10),
                _GlowField(
                    controller: _amountCtrl,
                    label: 'Amount · 数量',
                    icon: Icons.numbers_rounded,
                    numeric: true),
                const SizedBox(height: 14),

                // trigger
                const _SectionLabel('Trigger · 触发条件'),
                const SizedBox(height: 8),
                _DropdownField<String>(
                  value: _trigger,
                  items: _triggers,
                  label: (t) => t.replaceAll('_', ' '),
                  onChanged: (v) => setState(() => _trigger = v!),
                ),
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
                        ? 'Update Rule · 更新规则'
                        : 'Create Rule · 创建规则',
                    saving: _saving,
                    onTap: _save),
              ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared mini widgets
// ══════════════════════════════════════════════════════════════════════════════

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
