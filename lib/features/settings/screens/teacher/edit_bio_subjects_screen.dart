// lib/features/settings/screens/teacher/edit_bio_subjects_screen.dart
//
// FIXED: this screen used to treat each subject as a {'id': ..., 'subject':
// ...} object. The real backend (teachers.controller.js's getMyProfile)
// returns `subjects` as a plain list of strings, e.g. ["Math", "English"]
// — teacher_profiles.subjects is a TEXT[] column with no separate ID per
// entry (confirmed by that controller's own comment: "items are
// identified by their exact text"). The old _load() tried to do
// `Map<String,dynamic>.from(s)` on each entry, which throws immediately
// since a String isn't a Map — this crashed every time the screen loaded
// for any teacher who had at least one subject. Now `_subjects` is a
// plain `List<String>`, and add/edit/remove all operate on the subject's
// text directly instead of a nonexistent numeric ID.

import 'package:flutter/material.dart';
import '../../../../core/api/api_service.dart';
import '../../repositories/settings_repository.dart';

class EditBioSubjectsScreen extends StatefulWidget {
  const EditBioSubjectsScreen({super.key});

  @override
  State<EditBioSubjectsScreen> createState() => _EditBioSubjectsScreenState();
}

class _EditBioSubjectsScreenState extends State<EditBioSubjectsScreen> {
  final _repo = SettingsRepository();
  final _bioCtrl = TextEditingController();
  final _newSubjectCtrl = TextEditingController();

  bool _loading = true;
  bool _savingBio = false;
  bool _addingSubject = false;
  String? _error;

  List<String> _subjects = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _newSubjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _repo.getTeacherProfile();
      _bioCtrl.text = profile['bio'] as String? ?? '';
      _subjects = List<String>.from(profile['subjects'] as List? ?? []);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load your profile.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveBio() async {
    setState(() => _savingBio = true);
    try {
      await _repo.updateBio(_bioCtrl.text.trim());
      if (mounted) _showSnack('Bio updated · 简介已更新', isError: false);
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
    } catch (_) {
      if (mounted) _showSnack('Failed to update bio.', isError: true);
    } finally {
      if (mounted) setState(() => _savingBio = false);
    }
  }

  Future<void> _addSubject() async {
    final subject = _newSubjectCtrl.text.trim();
    if (subject.isEmpty) return;

    if (_subjects.any((s) => s.toLowerCase() == subject.toLowerCase())) {
      _showSnack('This subject has already been added.', isError: true);
      return;
    }

    setState(() => _addingSubject = true);
    try {
      await _repo.addSubject(subject);
      _newSubjectCtrl.clear();
      await _load(); // refresh from server so the list stays in sync
      if (mounted) _showSnack('Subject added · 已添加科目', isError: false);
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
    } catch (_) {
      if (mounted) _showSnack('Failed to add subject.', isError: true);
    } finally {
      if (mounted) setState(() => _addingSubject = false);
    }
  }

  Future<void> _removeSubject(String subjectText) async {
    setState(() => _subjects
        .removeWhere((s) => s.toLowerCase() == subjectText.toLowerCase()));
    try {
      await _repo.removeSubject(subjectText);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _subjects.add(subjectText));
        _showSnack(e.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _subjects.add(subjectText));
        _showSnack('Failed to remove subject.', isError: true);
      }
    }
  }

  Future<void> _editSubject(String subjectText) async {
    final ctrl = TextEditingController(text: subjectText);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Subject · 编辑科目'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (updated == null || updated.isEmpty || updated == subjectText) return;

    try {
      await _repo.updateSubject(subjectId: subjectText, subject: updated);
      if (mounted) {
        setState(() {
          final i = _subjects.indexOf(subjectText);
          if (i != -1) _subjects[i] = updated;
        });
        _showSnack('Subject updated · 已更新', isError: false);
      }
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
    } catch (_) {
      if (mounted) _showSnack('Failed to update subject.', isError: true);
    }
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFB00020) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Bio & Subjects · 编辑简介')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    children: [
                      Text('Biography · 个人简介',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _bioCtrl,
                        maxLines: 5,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          hintText:
                              'Tell students a bit about your teaching experience...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _savingBio ? null : _saveBio,
                          child: _savingBio
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save Bio · 保存简介'),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text('Teaching Subjects · 教学科目',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _newSubjectCtrl,
                              decoration: const InputDecoration(
                                hintText: 'e.g. Mathematics',
                                border: OutlineInputBorder(),
                              ),
                              onFieldSubmitted: (_) => _addSubject(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _addingSubject ? null : _addSubject,
                            icon: _addingSubject
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_subjects.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text('No subjects added yet · 暂无科目',
                              style: TextStyle(color: cs.onSurfaceVariant)),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _subjects.map((s) {
                            return InputChip(
                              label: Text(s),
                              onDeleted: () => _removeSubject(s),
                              onPressed: () => _editSubject(s),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
      ),
    );
  }
}
