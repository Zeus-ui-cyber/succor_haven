// lib/features/auth/screens/login_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Login screen with:
//   • Email + Password  /  Email OTP  /  Phone OTP  (tab switcher)
//   • Role selector (Student / Teacher / Admin)
//   • EN ↔ 中文 translation toggle
//   • Social media links bar (Facebook, Instagram, YouTube, TikTok, X)
//   • Contact info footer (phone + email)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/auth_controller.dart';
import '../../../models/user_role.dart';
import 'otp_screen.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _C {
  static const magenta = Color(0xFFD64577);
  static const burgundy = Color(0xFF7D002B);
  static const blushPink = Color(0xFFF2C6D6);
  static const softPink = Color(0xFFF9E1EA);
  static const lightPink = Color(0xFFF7D6E2);
  static const slateBlue = Color(0xFF3E678A);
  static const mauve = Color(0xFFE08AB2);
  static const cream = Color(0xFFFFF5F7);
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
  static const line = Color(0xFFF0DCE5);
  static const paper = Color(0xFFFFFFFF);
}

// ─── i18n strings ─────────────────────────────────────────────────────────────
class _L {
  final bool zh;
  const _L(this.zh);

  String get welcomeBack => zh ? '欢迎回来' : 'Welcome back';
  String get signingInAs => zh ? '登录身份：' : 'Signing in as';
  String get email => zh ? '电子邮件' : 'Email address';
  String get phone => zh ? '手机号码' : 'Phone number';
  String get password => zh ? '密码' : 'Password';
  String get forgotPassword => zh ? '忘记密码？' : 'Forgot password?';
  String get signIn => zh ? '登录' : 'Sign in';
  String get sendOtp => zh ? '发送验证码' : 'Send OTP';
  String get orLabel => zh ? '或' : 'or';
  String get newAccount => zh ? '新用户？创建账户' : 'New? Create account';
  String get footer => zh ? 'Succor Haven · 学习平台' : 'Succor Haven · 学习平台';
  String get tabPassword => zh ? '密码' : 'Password';
  String get tabEmailOtp => zh ? '邮件验证码' : 'Email OTP';
  String get tabPhoneOtp => zh ? '短信验证码' : 'Phone OTP';
  String get enterEmail => zh ? '请输入邮件地址' : 'Enter your email';
  String get validEmail => zh ? '请输入有效邮件' : 'Enter a valid email';
  String get enterPhone => zh ? '请输入手机号码' : 'Enter your phone number';
  String get validPhone => zh ? '请输入有效手机号' : 'Enter a valid phone number';
  String get enterPassword => zh ? '请输入密码' : 'Enter your password';
  String get minPassword => zh ? '至少6个字符' : 'At least 6 characters';
  String get contactUs => zh ? '联系我们' : 'Contact us';
  String roleLabel(UserRole r) => zh ? r.labelCn : r.label;
}

// ─── Login method tabs ────────────────────────────────────────────────────────
enum _Tab { password, emailOtp, phoneOtp }

// ═══════════════════════════════════════════════════════════════════════════════
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _zhMode = false; // translation toggle
  UserRole _selectedRole = UserRole.student;
  _Tab _tab = _Tab.password;

  late AnimationController _roleAnim;
  late Animation<double> _roleScale;

  @override
  void initState() {
    super.initState();
    _roleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _roleScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _roleAnim, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _roleAnim.dispose();
    super.dispose();
  }

  _L get _l => _L(_zhMode);
  Color get _accent => _selectedRole.accent;
  Color get _accentPale => _selectedRole.accentPale;

  void _selectRole(UserRole role) {
    if (role == _selectedRole) return;
    _roleAnim.forward().then((_) {
      setState(() {
        _selectedRole = role;
        // Admin only uses built-in email+password — force tab back to password
        if (role == UserRole.admin) _tab = _Tab.password;
      });
      _roleAnim.reverse();
    });
  }

  // ── Handle submit ──────────────────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final ctrl = ref.read(authControllerProvider.notifier);

    switch (_tab) {
      case _Tab.password:
        await ctrl.login(_emailCtrl.text.trim(), _passwordCtrl.text);
        _checkAndNavigate();
        break;

      case _Tab.emailOtp:
        await ctrl.sendEmailOtp(_emailCtrl.text.trim());
        _goToOtp();
        break;

      case _Tab.phoneOtp:
        // Prepend +63 if no country code given
        String phone = _phoneCtrl.text.trim();
        if (!phone.startsWith('+'))
          phone = '+63${phone.replaceFirst(RegExp(r'^0'), '')}';
        await ctrl.sendPhoneOtp(phone);
        _goToOtp();
        break;
    }
  }

  void _checkAndNavigate() {
    final authState = ref.read(authControllerProvider);
    if (!mounted) return;
    if (authState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authState.error!),
          backgroundColor: _C.burgundy,
        ),
      );
    } else if (authState.user != null) {
      Navigator.pushReplacementNamed(context, _selectedRole.routeOnLogin);
    }
  }

  void _goToOtp() {
    final authState = ref.read(authControllerProvider);
    if (!mounted) return;
    if (authState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authState.error!),
          backgroundColor: _C.burgundy,
        ),
      );
      return;
    }
    if (authState.otpSent) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            role: _selectedRole,
            zhMode: _zhMode,
            onSuccess: () {
              Navigator.pushReplacementNamed(
                  context, _selectedRole.routeOnLogin);
            },
          ),
        ),
      );
    }
  }

  // ── Social media launcher ──────────────────────────────────────────────────
  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: _C.cream,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: translation toggle ──────────────────────────────
            _buildTopBar(),

            // ── Scrollable body ──────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Form(
                  key: _formKey,
                  child: AnimatedBuilder(
                    animation: _roleAnim,
                    builder: (_, child) =>
                        Transform.scale(scale: _roleScale.value, child: child),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),

                        // Logo circle
                        _buildLogo(),
                        const SizedBox(height: 18),

                        // Title
                        Text(
                          _l.welcomeBack,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: _C.ink,
                            letterSpacing: -0.6,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${_l.signingInAs} ${_l.roleLabel(_selectedRole)} · ${_selectedRole.labelCn}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: _accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Role selector
                        _RoleSelector(
                          selected: _selectedRole,
                          onSelect: _selectRole,
                        ),
                        const SizedBox(height: 20),

                        // Admin notice (shown only for admin role)
                        if (_selectedRole == UserRole.admin) ...[
                          _buildAdminNotice(),
                          const SizedBox(height: 16),
                        ],

                        // Fields (animated switch)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _buildFields(key: ValueKey(_tab)),
                        ),
                        const SizedBox(height: 18),

                        // Submit button
                        _buildSubmitButton(authState),

                        // Method tabs — below submit, hidden for Admin
                        if (_selectedRole != UserRole.admin) ...[
                          const SizedBox(height: 16),
                          _buildMethodTabsLabel(),
                          const SizedBox(height: 8),
                          _buildMethodTabs(),
                        ],

                        // Register link
                        if (_selectedRole != UserRole.admin) ...[
                          const SizedBox(height: 20),
                          _buildDivider(),
                          const SizedBox(height: 20),
                          _buildRegisterButton(),
                        ],

                        const SizedBox(height: 28),

                        // Social media icons
                        _buildSocialBar(),
                        const SizedBox(height: 12),

                        // Contact footer
                        _buildContactFooter(),
                        const SizedBox(height: 20),

                        // Brand footer
                        Text(
                          _l.footer,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _C.inkSoft,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _TranslationToggle(
            zhMode: _zhMode,
            onToggle: () => setState(() => _zhMode = !_zhMode),
            accent: _accent,
          ),
        ],
      ),
    );
  }

  // ─── Logo ──────────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.28),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_accent, _C.mauve],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  _selectedRole.emoji,
                  style: const TextStyle(fontSize: 38),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Admin notice (replaces method tabs) ──────────────────────────────────
  Widget _buildAdminNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _accentPale,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.admin_panel_settings_outlined, size: 16, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _zhMode
                  ? '管理员账户仅支持内置账号密码登录'
                  : 'Admin accounts use built-in credentials only',
              style: TextStyle(
                fontSize: 12,
                color: _accent,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Method tabs label ────────────────────────────────────────────────────
  Widget _buildMethodTabsLabel() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        _zhMode ? '或使用其他方式登录' : 'Or sign in with',
        style: const TextStyle(
          fontSize: 12,
          color: _C.inkSoft,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ─── Method tabs — compact inline pills ───────────────────────────────────
  Widget _buildMethodTabs() {
    final tabs = [
      (_Tab.password, _l.tabPassword, Icons.lock_outline),
      (_Tab.emailOtp, _l.tabEmailOtp, Icons.email_outlined),
      (_Tab.phoneOtp, _l.tabPhoneOtp, Icons.phone_outlined),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: tabs.map((t) {
        final isActive = _tab == t.$1;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _tab = t.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? _C.paper : _C.lightPink,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isActive ? _accent.withOpacity(0.35) : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: _accent.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.$3, size: 13, color: isActive ? _accent : _C.inkSoft),
                  const SizedBox(width: 5),
                  Text(
                    t.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive ? _accent : _C.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Field sets per tab ────────────────────────────────────────────────────
  Widget _buildFields({required Key key}) {
    switch (_tab) {
      case _Tab.password:
        return Column(
          key: key,
          children: [
            _inputField(
              controller: _emailCtrl,
              label: _l.email,
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return _l.enterEmail;
                if (!v.contains('@')) return _l.validEmail;
                return null;
              },
            ),
            const SizedBox(height: 14),
            _inputField(
              controller: _passwordCtrl,
              label: _l.password,
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _C.inkSoft,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return _l.enterPassword;
                if (v.length < 6) return _l.minPassword;
                return null;
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: _accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                ),
                child: Text(
                  _l.forgotPassword,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        );

      case _Tab.emailOtp:
        return Column(
          key: key,
          children: [
            _inputField(
              controller: _emailCtrl,
              label: _l.email,
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return _l.enterEmail;
                if (!v.contains('@')) return _l.validEmail;
                return null;
              },
            ),
            const SizedBox(height: 8),
            _otpHint(_zhMode
                ? '验证码将发送到您的邮箱'
                : 'A one-time code will be sent to your email'),
          ],
        );

      case _Tab.phoneOtp:
        return Column(
          key: key,
          children: [
            _inputField(
              controller: _phoneCtrl,
              label: _l.phone,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return _l.enterPhone;
                if (v.replaceAll(RegExp(r'[^0-9]'), '').length < 10)
                  return _l.validPhone;
                return null;
              },
            ),
            const SizedBox(height: 8),
            _otpHint(_zhMode
                ? '验证码将以短信发送到您的手机'
                : 'A one-time code will be sent via SMS'),
          ],
        );
    }
  }

  Widget _otpHint(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _accentPale,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 15, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12, color: _accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ─── Submit button ─────────────────────────────────────────────────────────
  Widget _buildSubmitButton(AuthState authState) {
    final label = _tab == _Tab.password
        ? '${_l.signIn} ${_l.roleLabel(_selectedRole)}'
        : _l.sendOtp;

    return SizedBox(
      height: 52,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
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
          onPressed: authState.isLoading ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: authState.isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2)),
        ),
      ),
    );
  }

  // ─── Divider ───────────────────────────────────────────────────────────────
  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: _C.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(_l.orLabel,
              style: const TextStyle(
                  color: _C.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
        const Expanded(child: Divider(color: _C.line)),
      ],
    );
  }

  // ─── Register button ───────────────────────────────────────────────────────
  Widget _buildRegisterButton() {
    return OutlinedButton(
      onPressed: () {
        Navigator.pushNamed(context, '/register', arguments: _selectedRole);
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: _accent,
        side: BorderSide(color: _accentPale, width: 1.5),
        backgroundColor: _C.paper,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        _l.newAccount,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ─── Social media bar ──────────────────────────────────────────────────────
  Widget _buildSocialBar() {
    final socials = [
      (
        icon: 'assets/icons/facebook.png',
        fallbackIcon: Icons.facebook,
        label: 'Facebook',
        url: 'https://www.facebook.com/profile.php?id=61570116839724',
        color: const Color(0xFF1877F2),
      ),
      (
        icon: 'assets/icons/instagram.png',
        fallbackIcon: Icons.camera_alt_outlined,
        label: 'Instagram',
        url: 'https://www.instagram.com/succor_haven/',
        color: const Color(0xFFE1306C),
      ),
      (
        icon: 'assets/icons/youtube.png',
        fallbackIcon: Icons.play_circle_outline,
        label: 'YouTube',
        url: 'https://www.youtube.com/@succorhaven',
        color: const Color(0xFFFF0000),
      ),
      (
        icon: 'assets/icons/tiktok.png',
        fallbackIcon: Icons.music_note_outlined,
        label: 'TikTok',
        url: 'https://www.tiktok.com/@succorhaven',
        color: const Color(0xFF010101),
      ),
      (
        icon: 'assets/icons/x.png',
        fallbackIcon: Icons.alternate_email,
        label: 'X',
        url: 'https://x.com/succorhaven',
        color: const Color(0xFF000000),
      ),
    ];

    return Column(
      children: [
        Text(
          _zhMode ? '关注我们' : 'Follow us',
          style: const TextStyle(
              fontSize: 11.5,
              color: _C.inkSoft,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: socials.map((s) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () => _launch(s.url),
                child: Tooltip(
                  message: s.label,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _C.paper,
                      shape: BoxShape.circle,
                      border: Border.all(color: _C.line, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(s.fallbackIcon, color: s.color, size: 20),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Contact footer ────────────────────────────────────────────────────────
  Widget _buildContactFooter() {
    return Column(
      children: [
        const Divider(color: _C.line, thickness: 1),
        const SizedBox(height: 10),
        Text(
          _l.contactUs,
          style: const TextStyle(
              fontSize: 11,
              color: _C.inkSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _contactChip(
              icon: Icons.phone_outlined,
              label: '0992 283 7173',
              onTap: () => _launch('tel:09922837173'),
            ),
            const SizedBox(width: 10),
            _contactChip(
              icon: Icons.email_outlined,
              label: 'succorhaven@gmail.com',
              onTap: () => _launch('mailto:succorhaven@gmail.com'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _contactChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _C.softPink,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: _accent),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    color: _accent,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ─── Reusable input ────────────────────────────────────────────────────────
  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      style: const TextStyle(
          color: _C.ink, fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: _C.inkSoft, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, color: _C.inkSoft, size: 20),
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
            borderSide: BorderSide(color: _accent, width: 1.8)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFB00020), width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFB00020), width: 1.8)),
        errorStyle: const TextStyle(color: Color(0xFFB00020), fontSize: 11.5),
      ),
      validator: validator,
    );
  }
}

// ─── Role selector ─────────────────────────────────────────────────────────────
// Compact inline pills — naturally sized, not stretched
class _RoleSelector extends StatelessWidget {
  final UserRole selected;
  final void Function(UserRole) onSelect;
  const _RoleSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: UserRole.values.map((role) {
        final isActive = role == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onSelect(role),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : const Color(0xFFF7D6E2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? role.accent.withOpacity(0.35)
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: role.accent.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(role.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive ? role.accent : const Color(0xFF8A6070),
                    ),
                    child: Text(role.label),
                  ),
                  const SizedBox(width: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? role.accent.withOpacity(0.55)
                          : const Color(0xFF8A6070).withOpacity(0.45),
                    ),
                    child: Text('· ${role.labelCn}'),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Translation toggle ────────────────────────────────────────────────────────
class _TranslationToggle extends StatelessWidget {
  final bool zhMode;
  final VoidCallback onToggle;
  final Color accent;
  const _TranslationToggle(
      {required this.zhMode, required this.onToggle, required this.accent});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: zhMode ? accent : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: zhMode ? accent : const Color(0xFFF0DCE5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              zhMode ? '中文' : 'EN',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: zhMode ? Colors.white : accent,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.translate_rounded,
              size: 14,
              color: zhMode ? Colors.white : accent,
            ),
            const SizedBox(width: 3),
            Text(
              zhMode ? 'EN' : '中文',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: zhMode
                    ? Colors.white.withOpacity(0.7)
                    : const Color(0xFF8A6070),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
