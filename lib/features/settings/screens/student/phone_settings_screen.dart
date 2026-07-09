// lib/features/settings/screens/student/phone_settings_screen.dart
//
// Loads the user's current primary/backup phone via GET /settings/phone,
// then lets them update either one through a send-OTP → confirm flow
// (mirrors ChangePasswordScreen's OTP pattern).

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/api/api_service.dart';
import '../../repositories/settings_repository.dart';

const int _resendCooldownSeconds = 30;

class PhoneSettingsScreen extends StatefulWidget {
  const PhoneSettingsScreen({super.key});

  @override
  State<PhoneSettingsScreen> createState() => _PhoneSettingsScreenState();
}

class _PhoneSettingsScreenState extends State<PhoneSettingsScreen> {
  final _repo = SettingsRepository();
  bool _loading = true;
  String? _primaryPhone;
  String? _backupPhone;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = await _repo.getPhones();
      setState(() {
        _primaryPhone = data['primaryPhone'] as String?;
        _backupPhone = data['backupPhone'] as String?;
      });
    } on ApiException catch (e) {
      _loadError = e.message;
    } catch (_) {
      _loadError = 'Failed to load phone numbers.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Number · 手机号码')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Center(child: Text(_loadError!))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    children: [
                      _PhoneField(
                        label: 'Primary Phone',
                        labelCn: '主手机号码',
                        currentValue: _primaryPhone,
                        onSend: (phone) => _repo.sendPhoneOtp(phone),
                        onConfirm: (phone, otp) =>
                            _repo.updatePrimaryPhone(phone: phone, otp: otp),
                        onUpdated: (value) =>
                            setState(() => _primaryPhone = value),
                      ),
                      const SizedBox(height: 20),
                      _PhoneField(
                        label: 'Backup Phone',
                        labelCn: '备用手机号码',
                        currentValue: _backupPhone,
                        onSend: (phone) => _repo.sendPhoneOtp(phone),
                        onConfirm: (phone, otp) =>
                            _repo.updateBackupPhone(phone: phone, otp: otp),
                        onUpdated: (value) =>
                            setState(() => _backupPhone = value),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _PhoneField extends StatefulWidget {
  final String label, labelCn;
  final String? currentValue;
  final Future<void> Function(String phone) onSend;
  final Future<void> Function(String phone, String otp) onConfirm;
  final ValueChanged<String> onUpdated;

  const _PhoneField({
    required this.label,
    required this.labelCn,
    required this.currentValue,
    required this.onSend,
    required this.onConfirm,
    required this.onUpdated,
  });

  @override
  State<_PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<_PhoneField> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _editing = false;
  bool _otpSent = false;
  bool _sending = false;
  bool _confirming = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = _resendCooldownSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  Future<void> _sendOtp() async {
    if (_phoneCtrl.text.trim().isEmpty) {
      _showSnack('Enter a phone number first.', isError: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.onSend(_phoneCtrl.text.trim());
      setState(() => _otpSent = true);
      _startCooldown();
      _showSnack('Verification code sent.', isError: false);
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack('Failed to send code.', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirm() async {
    if (_otpCtrl.text.trim().isEmpty) {
      _showSnack('Enter the verification code.', isError: true);
      return;
    }
    setState(() => _confirming = true);
    try {
      final phone = _phoneCtrl.text.trim();
      await widget.onConfirm(phone, _otpCtrl.text.trim());
      widget.onUpdated(phone);
      setState(() {
        _editing = false;
        _otpSent = false;
        _otpCtrl.clear();
      });
      _showSnack('Phone number updated.', isError: false);
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack('Failed to update phone number.', isError: true);
    } finally {
      if (mounted) setState(() => _confirming = false);
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${widget.label} · ${widget.labelCn}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (!_editing)
                TextButton(
                  onPressed: () => setState(() {
                    _editing = true;
                    _phoneCtrl.text = widget.currentValue ?? '';
                  }),
                  child: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (!_editing)
            Text(
              widget.currentValue?.isNotEmpty == true
                  ? widget.currentValue!
                  : 'Not set',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          if (_editing) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              enabled: !_otpSent,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
            if (_otpSent) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Verification Code',
                  counterText: '',
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (!_otpSent)
                  ElevatedButton(
                    onPressed: _sending ? null : _sendOtp,
                    child: Text(_sending ? 'Sending...' : 'Send Code'),
                  )
                else
                  ElevatedButton(
                    onPressed: _confirming ? null : _confirm,
                    child: Text(_confirming ? 'Saving...' : 'Confirm'),
                  ),
                const SizedBox(width: 8),
                if (_otpSent)
                  TextButton(
                    onPressed: _cooldown > 0 || _sending ? null : _sendOtp,
                    child: Text(_cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _editing = false;
                    _otpSent = false;
                    _otpCtrl.clear();
                  }),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}