// lib/features/auth/screens/welcome_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Welcome / onboarding screen — Succor Haven
//   • Pink hero panel with logo, floating animation and sparkle particles
//   • Headline + subtext card that slides up on entry
//   • "Log in" button -> pushes LoginScreen (email/OTP form)
//   • "Skip" shortcut in the top-right also routes to LoginScreen
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import 'package:flutter/material.dart';
import 'login_screen.dart';

// ─── Palette (matches login_screen.dart) ───────────────────────────────────────
class _C {
  static const magenta = Color(0xFFD64577);
  static const burgundy = Color(0xFF7D002B);
  static const blushPink = Color(0xFFF2C6D6);
  static const mauve = Color(0xFFE08AB2);
  static const cream = Color(0xFFFFF5F7);
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _sparkleController;
  late final AnimationController _entryController;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _contentFade;

  int _dotIndex = 0;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _contentFade = CurvedAnimation(parent: _entryController, curve: Curves.easeIn);

    _entryController.forward();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _sparkleController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, anim, __) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.cream,
      body: Column(
        children: [
          // ── Hero panel ────────────────────────────────────────────────
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_C.magenta, _C.burgundy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
                child: Stack(
                  children: [
                    // Sparkle particles
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _sparkleController,
                        builder: (_, __) => CustomPaint(
                          painter: _SparklePainter(_sparkleController.value),
                        ),
                      ),
                    ),

                    // Decorative glow blobs
                    Positioned(
                      top: -40,
                      left: -30,
                      child: _glowBlob(140, _C.mauve.withOpacity(0.35)),
                    ),
                    Positioned(
                      bottom: -20,
                      right: -40,
                      child: _glowBlob(180, _C.blushPink.withOpacity(0.28)),
                    ),

                    // Skip shortcut
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16, top: 6),
                          child: TextButton(
                            onPressed: _goToLogin,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Floating logo
                    Center(
                      child: AnimatedBuilder(
                        animation: _floatController,
                        builder: (_, child) {
                          final dy = sin(_floatController.value * pi) * 10;
                          return Transform.translate(
                            offset: Offset(0, -dy),
                            child: child,
                          );
                        },
                        child: Container(
                          width: 132,
                          height: 132,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.20),
                                blurRadius: 26,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(18),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.favorite_rounded,
                                size: 48,
                                color: _C.magenta,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Content panel ─────────────────────────────────────────────
          Expanded(
            flex: 5,
            child: FadeTransition(
              opacity: _contentFade,
              child: SlideTransition(
                position: _cardSlide,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 26, 28, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Let's learn something\nnew every day.",
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: _C.ink,
                          height: 1.2,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Turn every lesson, quiz and streak into real, '
                        'trackable progress on Succor Haven.',
                        style: TextStyle(
                          fontSize: 14,
                          color: _C.inkSoft,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                      const Spacer(),
                      _buildDots(),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [_C.magenta, _C.burgundy],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _C.magenta.withOpacity(0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _goToLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Log in',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildDots() {
    return Row(
      children: List.generate(3, (i) {
        final active = i == _dotIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(right: 6),
          width: active ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? _C.magenta : _C.blushPink,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ─── Sparkle particle painter ─────────────────────────────────────────────────
class _SparklePainter extends CustomPainter {
  final double progress;
  _SparklePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(4);
    final paint = Paint();
    for (int i = 0; i < 18; i++) {
      final dx = rnd.nextDouble() * size.width;
      final baseY = rnd.nextDouble() * size.height;
      final dy = (baseY - progress * size.height * 0.5) % size.height;
      final r = 1.0 + rnd.nextDouble() * 1.6;
      final twinkle = (sin((progress * 2 * pi) + i * 1.1) + 1) / 2;
      paint.color = Colors.white.withOpacity(0.10 + twinkle * 0.3);
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) => true;
}