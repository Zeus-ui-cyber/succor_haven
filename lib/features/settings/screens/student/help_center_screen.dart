// lib/features/settings/screens/student/help_center_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/api_service.dart';
import '../../repositories/settings_repository.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help Center · 帮助中心')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('Contact Administrator'),
              subtitle: const Text('联系管理员'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => _launch('mailto:support@succorhaven.com'),
            ),
            ListTile(
              leading: const Icon(Icons.facebook_outlined),
              title: const Text('Official Facebook Page'),
              subtitle: const Text('官方脸书专页'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => _launch('https://facebook.com/succorhaven'), // replace with real page
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.report_problem_outlined),
              title: const Text('Submit a Concern'),
              subtitle: const Text('提交问题反馈'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _SubmitConcernScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitConcernScreen extends StatefulWidget {
  const _SubmitConcernScreen();

  @override
  State<_SubmitConcernScreen> createState() => _SubmitConcernScreenState();
}

class _SubmitConcernScreenState extends State<_SubmitConcernScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = SettingsRepository();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await _repo.submitConcern(
        subject: _subjectCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Your message has been submitted. We'll be in touch soon.")),
        );
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Failed to submit. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFB00020)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit a Concern · 提交问题反馈')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            children: [
              TextFormField(
                controller: _subjectCtrl,
                decoration: const InputDecoration(labelText: 'Subject'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Subject is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Message is required' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit · 提交'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}