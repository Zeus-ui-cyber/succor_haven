// lib/features/settings/screens/student/change_password_screen.dart
//
// Flow: screen auto-sends an OTP to the user's registered phone on open,
// then collects { otp, currentPassword, newPassword, confirmPassword } and
// submits in one call to POST /settings/password/change (see
// settings.controller.js → changePassword, which itself calls
// otp.service.js → verifyOtp against the existing otp_codes table).

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/api/api_service.dart';
import '../../repositories/settings_repository.dart';

const int _resendCooldownSeconds = 30;
const int _minPasswordLength = 8;

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = SettingsRepository();

  final _otpCtrl = TextEditingController();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _sendingOtp = false;
  bool _submitting = false;
  int _resendSecondsLeft = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    // Fire the first OTP automatically — matches Edit Profile's "just works
    // on open" feel, and avoids an extra "Send code" tap for the common case.
    _sendOtp();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() => _sendingOtp = true);
    try {
      await _repo.sendPasswordChangeOtp();
      if (mounted) {
        _showSnack('A verification code was sent to your registered phone number.',
            isError: false);
        _startResendCooldown();
      }
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
    } catch (_) {
      if (mounted) _showSnack('Failed to send verification code.', isError: true);
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  void _startResendCooldown() {
    setState(() => _resendSecondsLeft = _resendCooldownSeconds);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft -= 1);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await _repo.changePassword(
        otp: _otpCtrl.text.trim(),
        currentPassword: _currentPasswordCtrl.text,
        newPassword: _newPasswordCtrl.text,
        confirmPassword: _confirmPasswordCtrl.text,
      );
      if (mounted) {
        _showSnack('Password changed successfully', isError: false);
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
    } catch (_) {
      if (mounted) {
        _showSnack('Something went wrong. Please try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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
      appBar: AppBar(title: const Text('Change Password · 修改密码')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: cs.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'For your security, we sent a one-time code to your '
                        'registered phone number. It expires in 5 minutes.',
                        style: TextStyle(fontSize: 12.5, color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── OTP field + resend ──────────────────────────────────────
              TextFormField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Verification Code',
                  counterText: '',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter the code sent to you';
                  if (v.trim().length != 6) return 'Code must be 6 digits';
                  return null;
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: (_resendSecondsLeft > 0 || _sendingOtp) ? null : _sendOtp,
                  child: Text(
                    _sendingOtp
                        ? 'Sending...'
                        : _resendSecondsLeft > 0
                            ? 'Resend in ${_resendSecondsLeft}s'
                            : 'Resend Code',
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Password fields ──────────────────────────────────────────
              TextFormField(
                controller: _currentPasswordCtrl,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your current password' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordCtrl,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a new password';
                  if (v.length < _minPasswordLength) {
                    return 'Must be at least $_minPasswordLength characters';
                  }
                  if (v == _currentPasswordCtrl.text) {
                    return 'New password must differ from current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordCtrl,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirm your new password';
                  if (v != _newPasswordCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Change Password · 修改密码'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}