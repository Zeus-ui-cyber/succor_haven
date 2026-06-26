// lib/features/auth/screens/otp_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// OTP verification screen.
// Navigated to after sendEmailOtp / sendPhoneOtp succeeds.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/auth_controller.dart';
import '../../../models/user_role.dart';

class _C {
  static const magenta = Color(0xFFD64577);
  static const burgundy = Color(0xFF7D002B);
  static const blushPink = Color(0xFFF2C6D6);
  static const softPink = Color(0xFFF9E1EA);
  static const lightPink = Color(0xFFF7D6E2);
  static const cream = Color(0xFFFFF5F7);
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
  static const line = Color(0xFFF0DCE5);
  static const paper = Color(0xFFFFFFFF);
  static const green = Color(0xFF00C48C);
}

class OtpScreen extends ConsumerStatefulWidget {
  final UserRole role;
  final bool zhMode;
  final VoidCallback onSuccess;

  const OtpScreen({
    super.key,
    required this.role,
    required this.zhMode,
    required this.onSuccess,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with TickerProviderStateMixin {
  // 6 separate controllers for the 6 OTP digits
  final List<TextEditingController> _digitCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  // Countdown resend timer (60 seconds)
  int _countdown = 60;
  Timer? _timer;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _startTimer();

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _digitCtrls) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown == 0) {
        t.cancel();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Color get _accent => widget.role.accent;
  bool get _zh => widget.zhMode;

  String get _otp => _digitCtrls.map((c) => c.text).join();

  // ── Verify ────────────────────────────────────────────────────────────────
  Future<void> _verify() async {
    if (_otp.length < 6) return;
    await ref.read(authControllerProvider.notifier).verifyOtp(_otp);
    final state = ref.read(authControllerProvider);
    if (!mounted) return;
    if (state.error != null) {
      // Shake the boxes
      _shakeCtrl.forward(from: 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error!), backgroundColor: _C.burgundy),
      );
    } else if (state.user != null) {
      widget.onSuccess();
    }
  }

  // ── Resend ────────────────────────────────────────────────────────────────
  Future<void> _resend() async {
    if (_countdown > 0) return;
    await ref.read(authControllerProvider.notifier).resendOtp();
    _startTimer();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_zh ? '验证码已重新发送' : 'OTP resent successfully'),
        backgroundColor: _C.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final target = authState.otpTarget ?? '';
    final isPhone = authState.loginMethod == LoginMethod.phoneOtp;

    return Scaffold(
      backgroundColor: _C.cream,
      appBar: AppBar(
        backgroundColor: _C.cream,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_rounded, color: _C.ink, size: 20),
          onPressed: () {
            ref.read(authControllerProvider.notifier).cancelOtp();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_accent, _C.blushPink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isPhone
                        ? Icons.sms_outlined
                        : Icons.mark_email_read_outlined,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                _zh ? '输入验证码' : 'Enter verification code',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _C.ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    color: _C.inkSoft,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                        text: _zh
                            ? (isPhone ? '验证码已发送至\n' : '验证码已发送至\n')
                            : (isPhone
                                ? 'We sent a 6-digit code to\n'
                                : 'We sent a 6-digit code to\n')),
                    TextSpan(
                      text: target,
                      style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // OTP boxes
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(
                    _shakeAnim.value *
                        (_shakeCtrl.status == AnimationStatus.forward ? 1 : -1),
                    0,
                  ),
                  child: child,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) => _otpBox(i)),
                ),
              ),
              const SizedBox(height: 36),

              // Verify button
              SizedBox(
                height: 52,
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [_accent, _accent.withOpacity(0.75)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: (authState.isLoading || _otp.length < 6)
                        ? null
                        : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(
                            _zh ? '验证' : 'Verify',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Resend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _zh ? '没收到验证码？' : "Didn't receive the code? ",
                    style: const TextStyle(
                        fontSize: 13,
                        color: _C.inkSoft,
                        fontWeight: FontWeight.w500),
                  ),
                  GestureDetector(
                    onTap: _countdown == 0 ? _resend : null,
                    child: Text(
                      _countdown > 0
                          ? (_zh
                              ? '重新发送 (${_countdown}s)'
                              : 'Resend (${_countdown}s)')
                          : (_zh ? '重新发送' : 'Resend'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _countdown == 0 ? _accent : _C.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    final isFocused = _focusNodes[index].hasFocus;
    final hasValue = _digitCtrls[index].text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 46,
      height: 56,
      decoration: BoxDecoration(
        color: hasValue ? _accent.withOpacity(0.08) : _C.softPink,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocused
              ? _accent
              : hasValue
                  ? _accent.withOpacity(0.4)
                  : _C.line,
          width: isFocused ? 2 : 1.5,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: _accent.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: _digitCtrls[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: _accent,
          letterSpacing: 0,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (val) {
          setState(() {});
          if (val.isNotEmpty && index < 5) {
            FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
          }
          if (val.isEmpty && index > 0) {
            FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
          }
          // Auto-verify when all 6 digits are entered
          if (_otp.length == 6) {
            _verify();
          }
        },
      ),
    );
  }
}
