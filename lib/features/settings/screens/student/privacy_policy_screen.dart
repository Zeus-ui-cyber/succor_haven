// lib/features/settings/screens/student/privacy_policy_screen.dart
//
// Redesigned to match a card-based privacy screen layout (shield header,
// summary cards, expandable detail sections) instead of a plain scroll of
// text blocks. Content is still placeholder — replace section bodies later.

import 'package:flutter/material.dart';

class _C {
  static const burgundy = Color(0xFF7D002B);
  static const magenta = Color(0xFFD64577);
  static const blushPink = Color(0xFFF2C6D6);
  static const softPink = Color(0xFFF9E1EA);
  static const cream = Color(0xFFFFF5F7);
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
  static const line = Color(0xFFF0DCE5);
  static const paper = Color(0xFFFFFFFF);
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.cream,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: const [
                  SizedBox(height: 8),
                  _SummaryCard(
                    icon: Icons.local_fire_department_rounded,
                    title: 'No surprises!',
                    titleCn: '没有意外',
                    body:
                        'We\'ll only ever collect, use, and share your information in ways described in this policy.',
                  ),
                  SizedBox(height: 12),
                  _SummaryCard(
                    icon: Icons.shield_outlined,
                    title: 'Keeping your information safe',
                    titleCn: '保护您的信息',
                    body:
                        'We\'re committed to the confidentiality and security of the personal data you give us.',
                  ),
                  SizedBox(height: 12),
                  _SummaryCard(
                    icon: Icons.tune_rounded,
                    title: 'You\'re always in control',
                    titleCn: '您始终掌控',
                    body:
                        'Update your profile and communication preferences at any time.',
                  ),
                  SizedBox(height: 20),
                  _AboutThisPolicy(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header: shield icon, title, back button ──────────────────────────────────
class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _C.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.line),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: _C.ink),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_C.burgundy, _C.magenta],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _C.burgundy.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 12),
          const Text('Privacy Policy',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _C.ink)),
          const SizedBox(height: 2),
          const Text('隐私政策',
              style: TextStyle(
                  fontSize: 12, color: _C.burgundy, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Summary card (icon + title + short body) ──────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title, titleCn, body;
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.titleCn,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _C.blushPink,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: _C.burgundy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: _C.ink)),
                  ),
                ]),
                Text(titleCn,
                    style: const TextStyle(
                        fontSize: 11,
                        color: _C.inkSoft,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(body,
                    style: const TextStyle(
                        fontSize: 12.5, color: _C.inkSoft, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── "About this policy" expandable detail section ─────────────────────────────
class _AboutThisPolicy extends StatefulWidget {
  const _AboutThisPolicy();

  @override
  State<_AboutThisPolicy> createState() => _AboutThisPolicyState();
}

class _AboutThisPolicyState extends State<_AboutThisPolicy> {
  bool _expanded = false;

  static const _sections = [
    (
      title: 'Introduction',
      titleCn: '简介',
      body: 'Placeholder introduction text describing the purpose of this policy.',
    ),
    (
      title: 'Data Collection',
      titleCn: '数据收集',
      body: 'Placeholder text describing what data is collected.',
    ),
    (
      title: 'Data Usage',
      titleCn: '数据使用',
      body: 'Placeholder text describing how data is used.',
    ),
    (
      title: 'User Responsibilities',
      titleCn: '用户责任',
      body: 'Placeholder text describing user responsibilities.',
    ),
    (
      title: 'Contact Information',
      titleCn: '联系方式',
      body: 'Placeholder contact details for privacy-related inquiries.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('About this policy',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: _C.ink)),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _C.inkSoft),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState:
                _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: _C.line, height: 20),
                  for (final s in _sections) ...[
                    _DetailSection(
                        title: s.title, titleCn: s.titleCn, body: s.body),
                    if (s != _sections.last) const SizedBox(height: 18),
                  ],
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title, titleCn, body;
  const _DetailSection(
      {required this.title, required this.titleCn, required this.body});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _C.ink)),
          const SizedBox(width: 6),
          Text('· $titleCn',
              style: const TextStyle(fontSize: 11, color: _C.burgundy)),
        ]),
        const SizedBox(height: 6),
        Text(body,
            style: const TextStyle(fontSize: 12.5, color: _C.inkSoft, height: 1.5)),
      ],
    );
  }
}