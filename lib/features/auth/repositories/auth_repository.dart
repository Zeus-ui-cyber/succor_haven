// lib/features/auth/repositories/auth_repository.dart
// Wired to the real Node/Express API via the shared ApiService.

import '../../../core/api/api_service.dart';
import '../../../models/user.dart';
import '../../../models/user_role.dart';

class AuthRepository {
  final ApiService _api = ApiService.instance;

  // ── Static helpers used across all dashboard screens & main.dart ──────────

  /// The active API base URL (e.g. "http://localhost:3000/api").
  /// Delegates to ApiService so there is a single source of truth.
  static String get baseUrl => ApiService.baseUrl;

  /// Call once at startup (in main.dart) to point the app at the right server.
  ///   AuthRepository.configure(url: 'http://localhost:3000/api');
  static void configure({required String url}) {
    ApiService.configure(url: url);
  }

  // ── Token passthrough (handy for splash/boot screens) ─────────────────────
  Future<String?> getAccessToken() => _api.getAccessToken();
  Future<String?> getRefreshToken() => _api.getRefreshToken();

  // login/register/otp-verify all return the same shape:
  // { accessToken, refreshToken, user: {...} }
  //
  // UserModel.fromJson() is already defensive — it accepts either
  // `first_name`/`last_name` (the real users-table columns) or a legacy
  // `full_name` shape, and reads `teacher_approved` when the backend joins
  // teacher_profiles (login/verifyOtp now do this — see auth.controller.js).
  //
  // Previously this method hand-built a UserModel and only ever read
  // `full_name`, so `teacher_approved` was silently dropped and always
  // defaulted to false — which is why an Admin-approved teacher still saw
  // the "Account Under Review" pending screen after logging in. Just
  // delegate to fromJson() instead of duplicating (and drifting from) its
  // parsing logic.
  UserModel _parseAuthUser(Map<String, dynamic> data) {
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  // ── Email + Password Login ────────────────────────────────────────────────
  Future<UserModel> login(String email, String password) async {
    final data = await _api.post(
      '/auth/login',
      data: {'email': email, 'password': password},
      authenticated: false,
    );
    await _api.saveTokens(
        access: data['accessToken'], refresh: data['refreshToken']);
    return _parseAuthUser(data);
  }

  // ── Send OTP ──────────────────────────────────────────────────────────────
  Future<bool> sendEmailOtp(String email) async {
    await _api.post(
      '/auth/otp/send',
      data: {'target': email, 'type': 'email'},
      authenticated: false,
    );
    return true;
  }

  Future<bool> sendPhoneOtp(String phone) async {
    await _api.post(
      '/auth/otp/send',
      data: {'target': phone, 'type': 'sms'},
      authenticated: false,
    );
    return true;
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────
  Future<UserModel> verifyEmailOtp(String email, String otp) async {
    final data = await _api.post(
      '/auth/otp/verify',
      data: {'target': email, 'code': otp, 'type': 'email'},
      authenticated: false,
    );
    await _api.saveTokens(
        access: data['accessToken'], refresh: data['refreshToken']);
    return _parseAuthUser(data);
  }

  Future<UserModel> verifyPhoneOtp(String phone, String otp) async {
    final data = await _api.post(
      '/auth/otp/verify',
      data: {'target': phone, 'code': otp, 'type': 'sms'},
      authenticated: false,
    );
    await _api.saveTokens(
        access: data['accessToken'], refresh: data['refreshToken']);
    return _parseAuthUser(data);
  }

  Future<bool> resendOtp({String? email, String? phone}) async {
    if (email != null) return sendEmailOtp(email);
    if (phone != null) return sendPhoneOtp(phone);
    return false;
  }

  // ── Register ──────────────────────────────────────────────────────────────
  // The users table has separate `first_name` / `last_name` columns (see
  // src/db/schema.sql), and auth.controller.js's register() now reads
  // `firstName`/`lastName` directly from the request body — so send them
  // as-is instead of combining into a single `fullName` string.
  //
  // `phone` is sent too — the users table has a phone column and the
  // backend persists it, needed for Phone OTP login/registration.
  //
  // `creditsPerSession` is intentionally not sent here — a self-registering
  // teacher doesn't get to set their own per-session credit cost;
  // teacher_profiles.credits_per_session defaults to 6 and can be adjusted
  // by an Admin later (or set explicitly when an Admin creates the account
  // via CreateTeacherAccountScreen).
  Future<UserModel> register({
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
    final data = await _api.post(
      '/auth/register',
      authenticated: false,
      data: {
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'role': role.apiValue,
        'phone': phone,
        'bio': bio,
        'subjects': subjects,
        'availability': availability,
        'nativeLanguage': nativeLanguage,
        'learningGoals': learningGoals,
        'level': level,
      },
    );
    await _api.saveTokens(
        access: data['accessToken'], refresh: data['refreshToken']);
    return _parseAuthUser(data);
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    final refresh = await _api.getRefreshToken();
    try {
      await _api.post(
        '/auth/logout',
        data: {'refreshToken': refresh},
        authenticated: false,
      );
    } catch (_) {
      // Even if the network call fails, always clear local tokens below.
    }
    await _api.clearTokens();
  }

  // ── Get current user (full profile incl. credits/points) ──────────────────
  Future<UserModel> getMe() async {
    final data = await _api.get('/auth/me');
    return UserModel.fromJson(data as Map<String, dynamic>);
  }
}
