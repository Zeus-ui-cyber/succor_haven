// lib/features/auth/controllers/auth_controller.dart
// ─────────────────────────────────────────────────────────────────────────────
// Riverpod StateNotifier that owns all auth state.
// Screens call methods here; they never touch AuthRepository directly.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user.dart';
import '../../../models/user_role.dart';
import '../repositories/auth_repository.dart';

// ─── Login method enum ────────────────────────────────────────────────────────
enum LoginMethod { emailPassword, emailOtp, phoneOtp }

// ─── State ────────────────────────────────────────────────────────────────────
class AuthState {
  final bool isLoading;
  final UserModel? user;
  final String? error;
  final bool otpSent; // true after OTP has been sent
  final String? otpTarget; // the email or phone the OTP was sent to
  final LoginMethod loginMethod;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.error,
    this.otpSent = false,
    this.otpTarget,
    this.loginMethod = LoginMethod.emailPassword,
  });

  AuthState copyWith({
    bool? isLoading,
    UserModel? user,
    String? error,
    bool? otpSent,
    String? otpTarget,
    LoginMethod? loginMethod,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error, // null clears the error intentionally
      otpSent: otpSent ?? this.otpSent,
      otpTarget: otpTarget ?? this.otpTarget,
      loginMethod: loginMethod ?? this.loginMethod,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthController(this._repo) : super(const AuthState());

  // ── Email + Password Login ─────────────────────────────────────────────────
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.login(email, password);
      state = AuthState(user: user);
    } catch (e) {
      state = AuthState(error: _clean(e));
    }
  }

  // ── Send Email OTP ─────────────────────────────────────────────────────────
  Future<void> sendEmailOtp(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.sendEmailOtp(email);
      state = state.copyWith(
        isLoading: false,
        otpSent: true,
        otpTarget: email,
        loginMethod: LoginMethod.emailOtp,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _clean(e));
    }
  }

  // ── Send Phone OTP ─────────────────────────────────────────────────────────
  Future<void> sendPhoneOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.sendPhoneOtp(phone);
      state = state.copyWith(
        isLoading: false,
        otpSent: true,
        otpTarget: phone,
        loginMethod: LoginMethod.phoneOtp,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _clean(e));
    }
  }

  // ── Verify OTP ─────────────────────────────────────────────────────────────
  Future<void> verifyOtp(String otp) async {
    final target = state.otpTarget;
    if (target == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      UserModel user;
      if (state.loginMethod == LoginMethod.emailOtp) {
        user = await _repo.verifyEmailOtp(target, otp);
      } else {
        user = await _repo.verifyPhoneOtp(target, otp);
      }
      state = AuthState(user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _clean(e));
    }
  }

  // ── Resend OTP ─────────────────────────────────────────────────────────────
  Future<void> resendOtp() async {
    final target = state.otpTarget;
    if (target == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (state.loginMethod == LoginMethod.emailOtp) {
        await _repo.sendEmailOtp(target);
      } else {
        await _repo.sendPhoneOtp(target);
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _clean(e));
    }
  }

  // ── Register ───────────────────────────────────────────────────────────────
  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required UserRole role,
    String? phone,
    String? bio,
    List<String>? subjects,
    int? creditsPerSession,
    List<String>? availability,
    String? nativeLanguage,
    List<String>? learningGoals,
    String? level,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
        phone: phone,
        bio: bio,
        subjects: subjects,
        creditsPerSession: creditsPerSession,
        availability: availability,
        nativeLanguage: nativeLanguage,
        learningGoals: learningGoals,
        level: level,
      );
      state = AuthState(user: user);
    } catch (e) {
      state = AuthState(error: _clean(e));
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.logout();
    } finally {
      state = const AuthState();
    }
  }

  // ── Back to login (cancel OTP flow) ────────────────────────────────────────
  void cancelOtp() {
    state = const AuthState();
  }

  // ── Clear error ────────────────────────────────────────────────────────────
  void clearError() => state = state.copyWith(error: null);

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');
}

// ─── Providers ────────────────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>(
  (_) => AuthRepository(),
);

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.read(authRepositoryProvider)),
);
