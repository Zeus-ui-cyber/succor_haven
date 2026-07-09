// lib/features/settings/screens/student/language_settings_screen.dart
//
// Pass the user's current language ('en' | 'zh') in via constructor —
// there's no GET /settings/language endpoint, so the initial value should
// come from UserModel.languagePref (populated by GET /auth/me).

import 'package:flutter/material.dart';
import '../../../../core/api/api_service.dart';
import '../../repositories/settings_repository.dart';

class LanguageSettingsScreen extends StatefulWidget {
  final String currentLanguage; // 'en' or 'zh'
  const LanguageSettingsScreen({super.key, this.currentLanguage = 'en'});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  final _repo = SettingsRepository();
  late String _selected;
  bool _saving = false;

  static const _options = [
    ('en', 'English', 'English'),
    ('zh', 'Chinese (Mandarin)', '中文（普通话）'),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.currentLanguage;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repo.updateLanguage(_selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Language preference updated.')),
        );
        Navigator.pop(context, _selected);
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Failed to update language.');
    } finally {
      if (mounted) setState(() => _saving = false);
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
    appBar: AppBar(title: const Text('Language · 语言')),
    body: SafeArea(
      child: RadioGroup<String>(
        groupValue: _selected,
        onChanged: (v) => setState(() => _selected = v!),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            ..._options.map((opt) {
              final (code, en, zh) = opt;
              return RadioListTile<String>(
                value: code,
                title: Text(en),
                subtitle: Text(zh),
              );
            }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save · 保存'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
} 