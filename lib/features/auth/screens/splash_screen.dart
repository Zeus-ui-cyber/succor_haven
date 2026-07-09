// lib/features/auth/screens/splash_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Splash screen — Succor Haven
//   • Pink gradient background
//   • Logo (with graceful fallback if asset is missing)
//   • Animated sparkle particles
//   • Auto-navigates to WelcomeScreen after a short delay
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import 'package:flutter/material.dart';
import 'welcome_screen.dart';

// ─── Palette (shared look with login_screen.dart) ─────────────────────────────
class _C {
  static const magenta = Color(0xFFD64577);
  static const burgundy = Color(0xFF7D002B);
  static const mauve = Color(0xFFE08AB2);
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _logoController.forward();

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 550),
          pageBuilder: (_, anim, __) =>
              FadeTransition(opacity: anim, child: const WelcomeScreen()),
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.burgundy,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_C.magenta, _C.burgundy],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Floating sparkle particles
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _sparkleController,
                builder: (_, __) => CustomPaint(
                  painter: _SparklePainter(_sparkleController.value),
                ),
              ),
            ),

            // Soft glow blobs behind the logo
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.mauve.withValues(alpha: 0.25),
                ),
              ),
            ),

            // Logo
            Center(
              child: FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Container(
                    width: 148,
                    height: 148,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.favorite_rounded,
                          size: 56,
                          color: _C.magenta,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Wordmark
            Positioned(
              left: 0,
              right: 0,
              bottom: 64,
              child: FadeTransition(
                opacity: _logoFade,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Succor Haven',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '学习平台',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sparkle particle painter ─────────────────────────────────────────────────
class _SparklePainter extends CustomPainter {
  final double progress;
  _SparklePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(11);
    final paint = Paint();
    for (int i = 0; i < 26; i++) {
      final dx = rnd.nextDouble() * size.width;
      final baseY = rnd.nextDouble() * size.height;
      final dy = (baseY - progress * size.height * 0.6) % size.height;
      final r = 1.0 + rnd.nextDouble() * 1.8;
      final twinkle = (sin((progress * 2 * pi) + i * 1.3) + 1) / 2;
      paint.color = Colors.white.withValues(alpha: 0.12 + twinkle * 0.35);
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) => true;
}
