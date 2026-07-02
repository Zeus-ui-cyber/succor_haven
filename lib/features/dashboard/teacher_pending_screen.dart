// lib/features/dashboard/teacher_pending_screen.dart
//
// Shown instead of TeacherDashboard when a teacher's account has not yet
// been approved by the admin (is_approved = false on teacher_profiles).
//
// The screen:
//   • Explains what's happening — no confusing blank dashboard
//   • Lets the teacher complete/update their profile while waiting
//   • Shows a logout button
//   • Auto-refreshes approval status every 30 seconds so the teacher
//     is redirected automatically once the admin approves them

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/repositories/auth_repository.dart';

class TeacherPendingScreen extends ConsumerStatefulWidget {
  const TeacherPendingScreen({super.key});

  @override
  ConsumerState<TeacherPendingScreen> createState() =>
      _TeacherPendingScreenState();
}

class _TeacherPendingScreenState
    extends ConsumerState<TeacherPendingScreen> {
  Timer? _timer;
  bool _checking = false;
  // Guards against the periodic timer and the manual "Check Approval
  // Status" button both firing pushReplacementNamed('/teacher-dashboard')
  // for overlapping in-flight requests. Without this, two approved
  // responses landing close together each try to navigate, and the
  // second pushReplacementNamed runs against a Navigator that's still
  // mid-transition from the first — that's what throws the
  // `_elements.contains(element)` assertion.
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Poll every 30 seconds — lightweight (single GET /auth/me)
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _checkApproval());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkApproval() async {
    if (_checking || _navigated || !mounted) return;
    setState(() => _checking = true);
    try {
      final repo = AuthRepository();
      final user = await repo.getMe();
      if (!mounted || _navigated) return;
      if (user.teacherApproved) {
        // Admin approved — go to the real dashboard.
        // Set the guard and stop the timer BEFORE navigating so no other
        // in-flight or future check can fire a second navigation.
        _navigated = true;
        _timer?.cancel();
        Navigator.of(context).pushReplacementNamed('/teacher-dashboard');
      }
    } catch (_) {
      // Network error — silently ignore, will retry on next poll
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _logout() async {
    await AuthRepository().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Top bar with logout ────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  const Text(
                    'Succor Haven',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3B0A1F),
                    ),
                  ),
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2C6D6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7D002B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // ── Main illustration area ─────────────────────────────────
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD64577), Color(0xFF7D002B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD64577).withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🕐', style: TextStyle(fontSize: 48)),
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'Account Under Review',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF3B0A1F),
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                '账号审核中',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD64577),
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFF0DCE5),
                    width: 1.4,
                  ),
                ),
                child: const Column(
                  children: [
                    _StatusRow(
                      icon: '✅',
                      title: 'Registration complete',
                      subtitle: 'Your account has been created successfully.',
                    ),
                    SizedBox(height: 16),
                    _StatusRow(
                      icon: '⏳',
                      title: 'Waiting for admin approval',
                      subtitle:
                          'Our team is reviewing your profile. This usually takes 1–2 business days.',
                    ),
                    SizedBox(height: 16),
                    _StatusRow(
                      icon: '🔔',
                      title: 'You\'ll be notified',
                      subtitle:
                          'Once approved, you\'ll be redirected to your dashboard automatically.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Refresh button ─────────────────────────────────────────
              GestureDetector(
                onTap: _checkApproval,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _checking ? const Color(0xFFF2C6D6) : const Color(0xFFD64577),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _checking
                        ? []
                        : [
                            BoxShadow(
                              color: const Color(0xFFD64577).withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                  ),
                  child: Center(
                    child: _checking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Color(0xFFD64577),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Check Approval Status',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Update profile CTA ─────────────────────────────────────
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/teacher-profile'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(
                      color: Color(0xFFD64577), width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD64577),
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String icon, title, subtitle;
  const _StatusRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3B0A1F),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A6070),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}