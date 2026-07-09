// lib/features/settings/screens/student/privacy_policy_screen.dart
//
// Placeholder content — replace section bodies later.

import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy · 隐私政策')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: const [
            _Section(
              title: 'Introduction',
              titleCn: '简介',
              body: 'Placeholder introduction text describing the purpose of this policy.',
            ),
            _Section(
              title: 'Data Collection',
              titleCn: '数据收集',
              body: 'Placeholder text describing what data is collected.',
            ),
            _Section(
              title: 'Data Usage',
              titleCn: '数据使用',
              body: 'Placeholder text describing how data is used.',
            ),
            _Section(
              title: 'User Responsibilities',
              titleCn: '用户责任',
              body: 'Placeholder text describing user responsibilities.',
            ),
            _Section(
              title: 'Contact Information',
              titleCn: '联系方式',
              body: 'Placeholder contact details for privacy-related inquiries.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title, titleCn, body;
  const _Section({required this.title, required this.titleCn, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Text('· $titleCn', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
          ]),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}