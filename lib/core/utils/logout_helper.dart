// lib/core/utils/logout_helper.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/repositories/auth_repository.dart';

Future<void> performLogoutWithLoading(BuildContext context, {WidgetRef? ref}) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7D002B)),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Logging out...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Please wait a moment · 正在退出',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    if (ref != null) {
      await Future.wait([
        ref.read(authControllerProvider.notifier).logout(),
        Future.delayed(const Duration(milliseconds: 650)),
      ]);
    } else {
      await Future.wait([
        AuthRepository().logout(),
        Future.delayed(const Duration(milliseconds: 650)),
      ]);
    }
  } catch (_) {
    // Ignore logout errors
  }

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }
}
