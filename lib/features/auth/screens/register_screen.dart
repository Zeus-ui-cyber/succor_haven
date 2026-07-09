import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/auth_controller.dart';
import '../../../models/user_role.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _C {
  static const burgundy = Color(0xFF7D002B);
  static const softPink = Color(0xFFF9E1EA);
  static const cream = Color(0xFFFFF5F7);
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
  static const line = Color(0xFFF0DCE5);
  static const paper = Color(0xFFFFFFFF);
  static const green = Color(0xFF00C48C);
  static const greenPale = Color(0xFFDCF7EE);
}

class RegisterScreen extends ConsumerStatefulWidget {
  final UserRole initialRole;
  const RegisterScreen({super.key, this.initialRole = UserRole.student});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _subjectsCtrl = TextEditingController();
  final _creditsCtrl = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final Map<String, Set<String>> _chipSelections = {};

  late UserRole _role;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreed = false;
  bool _isLoading = false;
  int _step = 1;

  late AnimationController _stepAnim;
  late Animation<Offset> _slideIn;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
    _stepAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _slideIn = Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _stepAnim, curve: Curves.easeOutCubic));
    _fadeIn = CurvedAnimation(parent: _stepAnim, curve: Curves.easeOut);
    _stepAnim.forward();
  }

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl,
      _lastNameCtrl,
      _emailCtrl,
      _phoneCtrl,
      _passwordCtrl,
      _confirmCtrl,
      _bioCtrl,
      _subjectsCtrl,
      _creditsCtrl
    ]) {
      c.dispose();
    }
    _stepAnim.dispose();
    super.dispose();
  }

  Color get _accent => _role.accent;
  Color get _accentPale => _role.accentPale;

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    _stepAnim.reset();
    setState(() => _step++);
    _stepAnim.forward();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please accept the terms to continue.'),
        backgroundColor: _C.burgundy,
      ));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider.notifier).register(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            firstName: _firstNameCtrl.text.trim(),
            lastName: _lastNameCtrl.text.trim(),
            role: _role,
            phone:
                _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
            bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
            subjects: _chipSelections['subjects']?.toList(),
            creditsPerSession: int.tryParse(_creditsCtrl.text),
            availability: _chipSelections['availability']?.toList(),
            nativeLanguage: _chipSelections['native_lang']?.firstOrNull,
            learningGoals: _chipSelections['goal']?.toList(),
            level: _chipSelections['level']?.firstOrNull,
          );

      final authState = ref.read(authControllerProvider);
      if (!mounted) return;

      if (authState.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(authState.error!),
          backgroundColor: _C.burgundy,
        ));
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _isLoading = false;
          _step = 3;
        });
        _stepAnim
          ..reset()
          ..forward();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: _C.burgundy,
      ));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.cream,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: SlideTransition(
                    position: _slideIn,
                    child: Form(key: _formKey, child: _buildCurrentStep()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_step > 1 && _step < 3) {
                _stepAnim.reset();
                setState(() => _step--);
                _stepAnim.forward();
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: _C.paper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.line)),
              child: const Center(
                  child:
                      Text('←', style: TextStyle(fontSize: 18, color: _C.ink))),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _step == 3
                        ? 'You\'re all set!'
                        : 'Create ${_role.label} Account',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _C.ink,
                        letterSpacing: -0.4)),
                Text(
                    _step == 3
                        ? '账户创建成功 🎉'
                        : 'Step $_step of 2 · ${_role.emoji} ${_role.label}',
                    style: TextStyle(
                        fontSize: 12,
                        color: _accent,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (_step < 3)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _accentPale,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accent.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                Text(_role.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 5),
                Text(_role.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _accent)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    if (_step == 3) return const SizedBox(height: 12);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Row(
        children: List.generate(2, (i) {
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < 1 ? 6 : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i < _step ? _accent : _C.line,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 1:
        return _buildStep1();
      case 2:
        return _role == UserRole.student
            ? _buildStep2Student()
            : _buildStep2Teacher();
      case 3:
        return _buildSuccessStep();
      default:
        return _buildStep1();
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('Personal Information', '个人信息'),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: _field(
                  controller: _firstNameCtrl,
                  label: 'First name',
                  icon: Icons.person_outline,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null)),
          const SizedBox(width: 12),
          Expanded(
              child: _field(
                  controller: _lastNameCtrl,
                  label: 'Last name',
                  icon: Icons.person_outline,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null)),
        ]),
        const SizedBox(height: 14),
        _field(
            controller: _emailCtrl,
            label: 'Email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter your email';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            }),
        const SizedBox(height: 14),
        _field(
            controller: _phoneCtrl,
            label: 'Phone number (optional)',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        const SizedBox(height: 14),
        _field(
            controller: _passwordCtrl,
            label: 'Password',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _C.inkSoft,
                  size: 20),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a password';
              if (v.length < 6) return 'At least 6 characters';
              return null;
            }),
        const SizedBox(height: 14),
        _field(
            controller: _confirmCtrl,
            label: 'Confirm password',
            icon: Icons.lock_outline,
            obscureText: _obscureConfirm,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _C.inkSoft,
                  size: 20),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (v) =>
                v != _passwordCtrl.text ? 'Passwords don\'t match' : null),
        const SizedBox(height: 10),
        _PasswordStrengthBar(password: _passwordCtrl.text),
        const SizedBox(height: 28),
        _primaryButton(label: 'Continue', onTap: _nextStep),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: RichText(
                text: TextSpan(
              text: 'Already have an account? ',
              style: const TextStyle(
                  color: _C.inkSoft, fontSize: 13, fontWeight: FontWeight.w500),
              children: [
                TextSpan(
                    text: 'Sign in',
                    style:
                        TextStyle(color: _accent, fontWeight: FontWeight.w700))
              ],
            )),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Student() {
    final languages = ['English', 'Mandarin', 'Korean', 'Japanese', 'Other'];
    final goals = [
      'IELTS / TOEFL prep',
      'Conversational fluency',
      'Business English',
      'Academic writing',
      'Exam prep',
      'Just exploring'
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('Learning Profile', '学习档案'),
        const SizedBox(height: 6),
        const Text('Help us match you with the right teacher.',
            style: TextStyle(
                fontSize: 12.5,
                color: _C.inkSoft,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 20),
        _chipSelector(
            label: 'Native language',
            icon: '🌐',
            options: languages,
            storageKey: 'native_lang'),
        const SizedBox(height: 18),
        _chipSelector(
            label: 'Primary goal',
            icon: '🎯',
            options: goals,
            storageKey: 'goal',
            multiSelect: true),
        const SizedBox(height: 18),
        _chipSelector(
            label: 'Current level',
            icon: '📊',
            options: [
              'Beginner',
              'Elementary',
              'Intermediate',
              'Upper-Intermediate',
              'Advanced'
            ],
            storageKey: 'level'),
        const SizedBox(height: 24),
        _termsRow(),
        const SizedBox(height: 24),
        _primaryButton(
            label: _isLoading ? '' : 'Create Student Account',
            onTap: _submit,
            isLoading: _isLoading),
      ],
    );
  }

  Widget _buildStep2Teacher() {
    final subjects = [
      'English',
      'Mandarin',
      'Korean',
      'Math',
      'Physics',
      'Business',
      'Creative Writing',
      'IELTS',
      'HSK'
    ];
    final availability = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('Teaching Profile', '教学档案'),
        const SizedBox(height: 6),
        const Text('Your profile will be reviewed before going live.',
            style: TextStyle(
                fontSize: 12.5,
                color: _C.inkSoft,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 20),
        _multilineField(
            controller: _bioCtrl,
            label: 'Short bio (shown to students)',
            hint: 'e.g. Native English speaker with 5 years ESL experience...',
            maxLines: 3,
            validator: (v) => (v == null || v.trim().length < 20)
                ? 'Please write at least 20 characters'
                : null),
        const SizedBox(height: 14),
        _chipSelector(
            label: 'Subjects you teach',
            icon: '📚',
            options: subjects,
            storageKey: 'subjects',
            multiSelect: true),
        const SizedBox(height: 18),
        _chipSelector(
            label: 'Weekly availability',
            icon: '📅',
            options: availability,
            storageKey: 'availability',
            multiSelect: true),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
              child: _field(
                  controller: _creditsCtrl,
                  label: 'Credits per session',
                  icon: Icons.diamond_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = int.tryParse(v);
                    if (n == null || n < 1 || n > 50) return '1–50 credits';
                    return null;
                  })),
          const SizedBox(width: 12),
          Expanded(
              child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _C.softPink,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.line)),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡 Tip',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _C.inkSoft)),
                  SizedBox(height: 2),
                  Text('Most teachers charge 6–12 credits per 30-min session.',
                      style: TextStyle(
                          fontSize: 11, color: _C.inkSoft, height: 1.4)),
                ]),
          )),
        ]),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: _accentPale,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent.withValues(alpha: 0.2))),
          child: const Row(children: [
            Text('📋', style: TextStyle(fontSize: 20)),
            SizedBox(width: 12),
            Expanded(
                child: Text(
              'You can upload certifications & ID after account approval. Admin will review your profile within 1–2 business days.',
              style: TextStyle(
                  fontSize: 12,
                  color: _C.ink,
                  height: 1.5,
                  fontWeight: FontWeight.w500),
            )),
          ]),
        ),
        const SizedBox(height: 20),
        _termsRow(),
        const SizedBox(height: 24),
        _primaryButton(
            label: _isLoading ? '' : 'Submit for Review',
            onTap: _submit,
            isLoading: _isLoading),
      ],
    );
  }

  Widget _buildSuccessStep() {
    final isTeacher = _role == UserRole.teacher;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Center(
            child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.greenPale,
              border:
                  Border.all(color: _C.green.withValues(alpha: 0.3), width: 2)),
          child:
              const Center(child: Text('🎉', style: TextStyle(fontSize: 46))),
        )),
        const SizedBox(height: 24),
        Text(isTeacher ? 'Application submitted!' : 'Account created!',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _C.ink,
                letterSpacing: -0.5)),
        const SizedBox(height: 10),
        Text(
          isTeacher
              ? 'Thank you, ${_firstNameCtrl.text}! Your profile is under review.\nWe\'ll email you within 1–2 business days.'
              : 'Welcome, ${_firstNameCtrl.text}! Your account is ready.\nStart browsing teachers and book your first session.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13.5,
              color: _C.inkSoft,
              height: 1.6,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 32),
        if (!isTeacher) ...[
          _nextCard('🔎', 'Browse Teachers',
              'Find your perfect match and book a session.'),
          const SizedBox(height: 10),
          _nextCard(
              '💎', 'Buy Credits', 'Top up credits to start booking sessions.'),
          const SizedBox(height: 10),
          _nextCard(
              '🏆', 'Earn Points', 'Complete sessions to earn loyalty points.'),
        ] else ...[
          _nextCard('📧', 'Check your email',
              'We\'ll notify you when your profile is approved.'),
          const SizedBox(height: 10),
          _nextCard('📅', 'Set availability',
              'You can update your schedule anytime after approval.'),
        ],
        const SizedBox(height: 32),
        _primaryButton(
          label: isTeacher ? 'Back to Sign In' : 'Go to Dashboard',
          onTap: () => Navigator.pushReplacementNamed(
              context, isTeacher ? '/login' : '/dashboard'),
        ),
      ],
    );
  }

  Widget _nextCard(String emoji, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _C.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.line)),
      child: Row(children: [
        Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: _accentPale, borderRadius: BorderRadius.circular(12)),
            child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 20)))),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700, color: _C.ink)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12,
                  color: _C.inkSoft,
                  fontWeight: FontWeight.w500)),
        ])),
        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _accent),
      ]),
    );
  }

  Widget _sectionLabel(String en, String zh) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(en,
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _C.ink,
              letterSpacing: -0.3)),
      Text(zh,
          style: TextStyle(
              fontSize: 11, color: _accent, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
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

  Widget _multilineField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 3,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
          color: _C.ink, fontWeight: FontWeight.w500, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(
            color: _C.inkSoft, fontSize: 12.5, fontWeight: FontWeight.w400),
        labelStyle:
            const TextStyle(color: _C.inkSoft, fontWeight: FontWeight.w600),
        alignLabelWithHint: true,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }

  Widget _chipSelector({
    required String label,
    required String icon,
    required List<String> options,
    required String storageKey,
    bool multiSelect = false,
  }) {
    _chipSelections.putIfAbsent(storageKey, () => {});
    return StatefulBuilder(builder: (_, setChipState) {
      final selected = _chipSelections[storageKey]!;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700, color: _C.ink)),
        ]),
        const SizedBox(height: 10),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final isSelected = selected.contains(opt);
              return GestureDetector(
                onTap: () => setChipState(() {
                  if (multiSelect) {
                    isSelected ? selected.remove(opt) : selected.add(opt);
                  } else {
                    selected
                      ..clear()
                      ..add(opt);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? _accent : _C.paper,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isSelected ? _accent : _C.line,
                        width: isSelected ? 1.5 : 1),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: _accent.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ]
                        : null,
                  ),
                  child: Text(opt,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : _C.inkSoft)),
                ),
              );
            }).toList()),
      ]);
    });
  }

  Widget _termsRow() {
    return GestureDetector(
      onTap: () => setState(() => _agreed = !_agreed),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: _agreed ? _accent : _C.paper,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _agreed ? _accent : _C.line, width: 1.5),
          ),
          child: _agreed
              ? const Center(
                  child:
                      Icon(Icons.check_rounded, size: 14, color: Colors.white))
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
            child: RichText(
                text: TextSpan(
          style: const TextStyle(
              fontSize: 12.5,
              color: _C.inkSoft,
              fontWeight: FontWeight.w500,
              height: 1.5),
          children: [
            const TextSpan(text: 'I agree to the '),
            TextSpan(
                text: 'Terms of Service',
                style: TextStyle(color: _accent, fontWeight: FontWeight.w700)),
            const TextSpan(text: ' and '),
            TextSpan(
                text: 'Privacy Policy',
                style: TextStyle(color: _accent, fontWeight: FontWeight.w700)),
            const TextSpan(text: ' of Succor Haven.'),
          ],
        ))),
      ]),
    );
  }

  Widget _primaryButton(
      {required String label,
      required VoidCallback onTap,
      bool isLoading = false}) {
    return SizedBox(
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
              colors: [_accent, _accent.withValues(alpha: 0.75)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          boxShadow: [
            BoxShadow(
                color: _accent.withValues(alpha: 0.32),
                blurRadius: 14,
                offset: const Offset(0, 6))
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2)),
        ),
      ),
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  final String password;
  const _PasswordStrengthBar({required this.password});

  int get _strength {
    if (password.isEmpty) return 0;
    int s = 0;
    if (password.length >= 8) s++;
    if (password.contains(RegExp(r'[A-Z]'))) s++;
    if (password.contains(RegExp(r'[0-9]'))) s++;
    if (password.contains(RegExp(r'[!@#\$&*~]'))) s++;
    return s;
  }

  String get _label {
    switch (_strength) {
      case 0:
        return '';
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      default:
        return 'Strong';
    }
  }

  Color get _color {
    switch (_strength) {
      case 1:
        return const Color(0xFFE57373);
      case 2:
        return const Color(0xFFFFB74D);
      case 3:
        return const Color(0xFF81C784);
      default:
        return _C.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
          children: List.generate(
              4,
              (i) => Expanded(
                      child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: i < _strength ? _color : _C.line),
                  )))),
      if (_label.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text('Password strength: $_label',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: _color)),
      ],
    ]);
  }
}