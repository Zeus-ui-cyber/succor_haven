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
  // Note: this `user` payload is the raw users-table row (see auth.controller's
  // userPublic()) — it does NOT include credits/points/teacher_approved, since
  // those only come from the joined /auth/me query. Defaults are fine here;
  // call getMe() right after login if you need the full profile immediately.
  //
  // ⚠️ FIXED: UserModel's real constructor takes `fullName` (required), not
  // firstName/lastName/phone/isActive — the users table has one full_name
  // column. firstName/lastName are derived getters on UserModel now, computed
  // from fullName.
  UserModel _parseAuthUser(Map<String, dynamic> data) {
    final u = data['user'] as Map<String, dynamic>;
    return UserModel(
      id: u['id'].toString(),
      email: u['email'] ?? '',
      fullName: u['full_name'] ?? '',
      role: u['role'] ?? 'student',
      createdAt: DateTime.parse(u['created_at']),
      // languagePref / credits / points / teacherApproved are left at their
      // UserModel defaults here — call getMe() right after login/register/
      // otp-verify if you need those populated immediately.
    );
  }

  // ── Email + Password Login ────────────────────────────────────────────────
  Future<UserModel> login(String email, String password) async {
    final data = await _api.post(
      '/auth/login',
      data: {'email': email, 'password': password},
      authenticated: false,
    );
    await _api.saveTokens(access: data['accessToken'], refresh: data['refreshToken']);
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
    await _api.saveTokens(access: data['accessToken'], refresh: data['refreshToken']);
    return _parseAuthUser(data);
  }

  Future<UserModel> verifyPhoneOtp(String phone, String otp) async {
    final data = await _api.post(
      '/auth/otp/verify',
      data: {'target': phone, 'code': otp, 'type': 'sms'},
      authenticated: false,
    );
    await _api.saveTokens(access: data['accessToken'], refresh: data['refreshToken']);
    return _parseAuthUser(data);
  }

  Future<bool> resendOtp({String? email, String? phone}) async {
    if (email != null) return sendEmailOtp(email);
    if (phone != null) return sendPhoneOtp(phone);
    return false;
  }

  // ── Register ──────────────────────────────────────────────────────────────
  // ⚠️ FIXED: backend (auth.controller.js) expects a single `fullName` field
  // (users table has one full_name column, no first_name/last_name split).
  // We still collect firstName/lastName separately in the UI for nicer UX,
  // but combine them here before sending, so the request actually matches
  // what the server reads — previously it sent firstName/lastName only,
  // which the backend never looked at, always failing with
  // "Full name required" regardless of input.
  //
  // `phone` is now sent too — the users table has a phone column and the
  // backend persists it, needed for Phone OTP login/registration.
  //
  // Dropped 'creditsPerSession' — session cost now comes from the pricing
  // table, not a per-teacher column. Sending it is harmless (backend just
  // ignores unknown fields) but removed for clarity.
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
        'fullName': '$firstName $lastName'.trim(),
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
    await _api.saveTokens(access: data['accessToken'], refresh: data['refreshToken']);
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