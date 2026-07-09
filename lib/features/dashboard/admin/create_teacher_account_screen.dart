// lib/features/dashboard/admin/create_teacher_account_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin-only screen for creating a Teacher account directly.
//
// Why this exists: Teachers do NOT self-register. An Admin creates the
// account here (name, subjects, credentials), then shares the generated
// temporary password with the teacher so they can log in immediately —
// no "Create your account" step, no pending self-signup.
//
// This intentionally does NOT go through authControllerProvider.register(),
// because that call replaces the *current* auth session with the newly
// created user — which would log the Admin out and log them in as the new
// teacher. Instead this posts directly to an admin-only endpoint, exactly
// like the other admin actions in admin_dashboard_screen.dart (approve,
// toggle, etc).
//
// BACKEND NOTE: this expects `POST {baseUrl}/admin/teachers` to exist on
// your Node/Express backend (admin.controller.js), accepting the JSON body
// built in `_submit()` below and returning the created user record. Add
// that route/controller if it doesn't exist yet — it should mirror how
// `register()` creates a teacher in AuthRepository, but skip creating a
// session/token for the admin's client.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../auth/repositories/auth_repository.dart';

// ─── Palette (matches admin_dashboard_screen.dart) ─────────────────────────────
class _C {
  static const burgundy = Color(0xFF7D002B);
  static const softPink = Color(0xFFF9E1EA);
  static const slateBlue = Color(0xFF3E678A);
  static const cream = Color(0xFFFFF5F7);
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
  static const line = Color(0xFFF0DCE5);
  static const paper = Color(0xFFFFFFFF);
  static const green = Color(0xFF00C48C);
}

final _adminRepoProvider = Provider((_) => AuthRepository());

Future<Map<String, String>> _adminHeaders(AuthRepository repo) async {
  final token = await repo.getAccessToken();
  return {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

class CreateTeacherAccountScreen extends ConsumerStatefulWidget {
  const CreateTeacherAccountScreen({super.key});

  @override
  ConsumerState<CreateTeacherAccountScreen> createState() =>
      _CreateTeacherAccountScreenState();
}

class _CreateTeacherAccountScreenState
    extends ConsumerState<CreateTeacherAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _creditsCtrl = TextEditingController(text: '6');
  final _passwordCtrl = TextEditingController();

  final List<String> _subjects = [];
  final _subjectInputCtrl = TextEditingController();

  final List<String> _availability = [];
  static const _allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _passwordCtrl.text = _generatePassword();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    _creditsCtrl.dispose();
    _passwordCtrl.dispose();
    _subjectInputCtrl.dispose();
    super.dispose();
  }

  String _generatePassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    final rnd = Random.secure();
    return List.generate(10, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  void _addSubject(String value) {
    final v = value.trim();
    if (v.isEmpty || _subjects.contains(v)) return;
    setState(() {
      _subjects.add(v);
      _subjectInputCtrl.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one subject'),
          backgroundColor: _C.burgundy,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(_adminRepoProvider);
      final res = await http.post(
        Uri.parse('${AuthRepository.baseUrl}/admin/teachers'),
        headers: await _adminHeaders(repo),
        body: jsonEncode({
          'firstName': _firstNameCtrl.text.trim(),
          'lastName': _lastNameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone':
              _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'password': _passwordCtrl.text,
          'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
          'subjects': _subjects,
          'creditsPerSession': int.tryParse(_creditsCtrl.text.trim()) ?? 6,
          'availability': _availability,
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        // Refresh the Teachers / Users tabs so the new account shows up.
        ref.invalidate(_allUsersProviderRef);
        ref.invalidate(_pendingTeachersProviderRef);

        await showDialog(
          context: context,
          builder: (_) => _SuccessDialog(
            name: '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}',
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          ),
        );

        if (mounted) Navigator.pop(context, true);
      } else {
        String message = 'Failed to create teacher account';
        try {
          final body = jsonDecode(res.body);
          if (body is Map) {
            final msg = body['error'] ?? body['message'];
            if (msg != null) message = msg.toString();
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: _C.burgundy),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: _C.burgundy,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.cream,
      appBar: AppBar(
        backgroundColor: _C.cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: _C.ink),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Teacher Account',
                style: TextStyle(
                    color: _C.ink, fontSize: 17, fontWeight: FontWeight.w800)),
            Text('创建教师账户', style: TextStyle(color: _C.inkSoft, fontSize: 11)),
          ],
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _sectionLabel('Basic Info · 基本信息'),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _firstNameCtrl,
                      label: 'First name',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      controller: _lastNameCtrl,
                      label: 'Last name',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(
                controller: _emailCtrl,
                label: 'Email address',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _field(
                controller: _phoneCtrl,
                label: 'Phone (optional)',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                ],
              ),
              const SizedBox(height: 20),
              _sectionLabel('Temporary Password · 临时密码'),
              _field(
                controller: _passwordCtrl,
                label: 'Password',
                obscureText: _obscurePassword,
                validator: (v) => (v == null || v.length < 6)
                    ? 'At least 6 characters'
                    : null,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: _C.inkSoft,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          size: 20, color: _C.slateBlue),
                      onPressed: () => setState(
                          () => _passwordCtrl.text = _generatePassword()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Share this with the teacher — they can change it after '
                'logging in.',
                style: TextStyle(fontSize: 11.5, color: _C.inkSoft),
              ),
              const SizedBox(height: 20),
              _sectionLabel('Teaching Profile · 教学资料'),
              _field(
                controller: _creditsCtrl,
                label: 'Credits per session',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              _field(
                controller: _bioCtrl,
                label: 'Bio (optional)',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              const Text('Subjects',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _C.ink)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _subjectInputCtrl,
                      label: 'e.g. IELTS, Speaking',
                      onSubmitted: _addSubject,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _addSubject(_subjectInputCtrl.text),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _C.slateBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
              if (_subjects.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _subjects
                      .map(
                        (s) => Chip(
                          label: Text(s,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                          backgroundColor: const Color(0xFFDCEBF5),
                          labelStyle: const TextStyle(color: _C.slateBlue),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() => _subjects.remove(s)),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 20),
              const Text('Availability (optional)',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _C.ink)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allDays.map((day) {
                  final selected = _availability.contains(day);
                  return GestureDetector(
                    onTap: () => setState(() {
                      selected
                          ? _availability.remove(day)
                          : _availability.add(day);
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected ? _C.slateBlue : _C.paper,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? _C.slateBlue : _C.line,
                        ),
                      ),
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : _C.inkSoft,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.burgundy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text(
                          'Create Teacher Account',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800, color: _C.burgundy),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    int maxLines = 1,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(
          color: _C.ink, fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: _C.inkSoft, fontWeight: FontWeight.w600),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _C.softPink,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.line, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.burgundy, width: 1.8)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFB00020), width: 1.5)),
        errorStyle: const TextStyle(color: Color(0xFFB00020), fontSize: 11.5),
      ),
      validator: validator,
    );
  }
}

// ─── Success dialog with credentials to share ─────────────────────────────────
class _SuccessDialog extends StatelessWidget {
  final String name;
  final String email;
  final String password;
  const _SuccessDialog({
    required this.name,
    required this.email,
    required this.password,
  });

  void _copyAll(BuildContext context) {
    Clipboard.setData(ClipboardData(
      text: 'Email: $email\nTemporary password: $password',
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Credentials copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _C.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: _C.green),
          SizedBox(width: 8),
          Text('Account created', style: TextStyle(color: _C.ink)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$name\'s teacher account is ready.',
              style: const TextStyle(color: _C.inkSoft)),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.softPink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: $email',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: _C.ink)),
                const SizedBox(height: 4),
                Text('Temporary password: $password',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: _C.ink)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Share these with the teacher so they can log in.',
            style: TextStyle(fontSize: 12, color: _C.inkSoft),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _copyAll(context),
          child: const Text('Copy', style: TextStyle(color: _C.slateBlue)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done', style: TextStyle(color: _C.burgundy)),
        ),
      ],
    );
  }
}

// These are re-declared here (rather than imported) because the providers
// in admin_dashboard_screen.dart are file-private (prefixed with `_`).
// If you'd rather share one instance, move these two providers into a
// shared file (e.g. admin_providers.dart) and import them in both places.
final _allUsersProviderRef = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(_adminRepoProvider);
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/admin/users'),
    headers: await _adminHeaders(repo),
  );
  if (res.statusCode != 200) return [];
  return jsonDecode(res.body) as List;
});

final _pendingTeachersProviderRef = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(_adminRepoProvider);
  final res = await http.get(
    Uri.parse('${AuthRepository.baseUrl}/admin/users?role=teacher'),
    headers: await _adminHeaders(repo),
  );
  if (res.statusCode != 200) return [];
  final all = jsonDecode(res.body) as List;
  return all.where((u) => u['teacher_approved'] == false).toList();
});