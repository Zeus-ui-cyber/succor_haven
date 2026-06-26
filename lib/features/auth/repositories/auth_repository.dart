// lib/features/auth/repositories/auth_repository.dart
// Wired to the real Node/Express API.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../models/user.dart';
import '../../../models/user_role.dart';

class AuthRepository {
  // ── Base URL — auto-switches per platform ─────────────────────────────────
  static String get baseUrl {
    // Flutter Web (browser) — backend must be on localhost
    if (identical(0, 0.0)) {
      // This branch never runs; use the kIsWeb import below
    }
    return _resolvedBaseUrl;
  }

  // Resolved once at startup by _resolveBaseUrl() in main.dart
  // Defaults to localhost:3000 so web always works out of the box.
  static String _resolvedBaseUrl = 'http://localhost:3000/api/v1';

  /// Call this once in main() before runApp().
  static void configure({required String url}) {
    _resolvedBaseUrl = url;
  }

  // flutter_secure_storage works on mobile/desktop.
  // On web it falls back to localStorage automatically (built-in to the package).
  final _storage = const FlutterSecureStorage(
    webOptions: WebOptions(dbName: 'succor_haven', publicKey: 'sh_tokens'),
  );

  // ── Token helpers ─────────────────────────────────────────────────────────
  Future<void> _saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<String?> getAccessToken() => _storage.read(key: 'access_token');
  Future<String?> getRefreshToken() => _storage.read(key: 'refresh_token');

  Future<Map<String, String>> _authHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  void _throwIfError(http.Response res) {
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw Exception(body['error'] ?? 'Unknown error');
    }
  }

  UserModel _parseUser(Map<String, dynamic> data) {
    return UserModel(
      id: data['user']['id'],
      email: data['user']['email'] ?? '',
      firstName: data['user']['first_name'],
      lastName: data['user']['last_name'],
      role: data['user']['role'],
      phone: data['user']['phone'],
      credits: data['user']['credits'] ?? 0,
      points: data['user']['points'] ?? 0,
      createdAt: DateTime.parse(data['user']['created_at']),
    );
  }

  // ── Email + Password Login ────────────────────────────────────────────────
  Future<UserModel> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    _throwIfError(res);
    final data = jsonDecode(res.body);
    await _saveTokens(data['accessToken'], data['refreshToken']);
    return _parseUser(data);
  }

  // ── Send OTP ──────────────────────────────────────────────────────────────
  Future<bool> sendEmailOtp(String email) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/otp/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'target': email, 'type': 'email'}),
    );
    _throwIfError(res);
    return true;
  }

  Future<bool> sendPhoneOtp(String phone) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/otp/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'target': phone, 'type': 'sms'}),
    );
    _throwIfError(res);
    return true;
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────
  Future<UserModel> verifyEmailOtp(String email, String otp) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'target': email, 'code': otp, 'type': 'email'}),
    );
    _throwIfError(res);
    final data = jsonDecode(res.body);
    await _saveTokens(data['accessToken'], data['refreshToken']);
    return _parseUser(data);
  }

  Future<UserModel> verifyPhoneOtp(String phone, String otp) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'target': phone, 'code': otp, 'type': 'sms'}),
    );
    _throwIfError(res);
    final data = jsonDecode(res.body);
    await _saveTokens(data['accessToken'], data['refreshToken']);
    return _parseUser(data);
  }

  Future<bool> resendOtp({String? email, String? phone}) async {
    if (email != null) return sendEmailOtp(email);
    if (phone != null) return sendPhoneOtp(phone);
    return false;
  }

  // ── Register ──────────────────────────────────────────────────────────────
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
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'role': role.name,
        'phone': phone,
        'bio': bio,
        'subjects': subjects,
        'creditsPerSession': creditsPerSession,
        'availability': availability,
        'nativeLanguage': nativeLanguage,
        'learningGoals': learningGoals,
        'level': level,
      }),
    );
    _throwIfError(res);
    final data = jsonDecode(res.body);
    await _saveTokens(data['accessToken'], data['refreshToken']);
    return _parseUser(data);
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    final refresh = await getRefreshToken();
    await http.post(
      Uri.parse('$baseUrl/auth/logout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refresh}),
    );
    await _storage.deleteAll();
  }

  // ── Get current user ──────────────────────────────────────────────────────
  Future<UserModel> getMe() async {
    final res = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: await _authHeaders(),
    );
    _throwIfError(res);
    final u = jsonDecode(res.body);
    return UserModel(
      id: u['id'],
      email: u['email'] ?? '',
      firstName: u['first_name'],
      lastName: u['last_name'],
      role: u['role'],
      phone: u['phone'],
      credits: u['credits'] ?? 0,
      points: u['points'] ?? 0,
      createdAt: DateTime.parse(u['created_at']),
    );
  }
}
