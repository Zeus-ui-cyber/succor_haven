// lib/core/api/api_service.dart
//
// THE single place where all HTTP calls to the backend go through.
// - Reads base URL from AppConstants (never hardcode it elsewhere).
// - Attaches the JWT access token to every request automatically.
// - On a 401, tries one silent refresh + retry before giving up.
//
// Repositories (auth, admin, bookings, teachers, ...) should depend on
// this class rather than calling `http` directly.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiService {
  ApiService._internal();
  static final ApiService instance = ApiService._internal();
  factory ApiService() => instance;

  // ── Configurable base URL (set once at startup via configure()) ────────
  static String? _overrideBaseUrl;

  /// Override the base URL at runtime (called from main.dart via
  /// AuthRepository.configure or directly).
  static void configure({required String url}) {
    _overrideBaseUrl = url;
  }

  /// The currently active base URL.
  static String get baseUrl => _overrideBaseUrl ?? AppConstants.baseUrl;

  final _storage = const FlutterSecureStorage(
    webOptions: WebOptions(dbName: 'succor_haven', publicKey: 'sh_tokens'),
  );

  // ── Token helpers ──────────────────────────────────────────────────────
  Future<void> saveTokens(
      {required String access, required String refresh}) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: access);
    await _storage.write(key: AppConstants.refreshTokenKey, value: refresh);
  }

  Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.accessTokenKey);
  Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.refreshTokenKey);

  Future<void> clearTokens() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
  }

  Future<Map<String, String>> _headers({bool authenticated = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (authenticated) {
      final token = await getAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse('${ApiService.baseUrl}$cleanPath');
    if (query == null || query.isEmpty) return base;
    return base.replace(
      queryParameters: query.map((k, v) => MapEntry(k, '$v')),
    );
  }

  // ── One-shot refresh, used internally on 401 ──────────────────────────
  Future<bool> _tryRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final res = await http.post(
        _uri('/auth/refresh'),
        headers: await _headers(authenticated: false),
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (res.statusCode >= 400) return false;
      final data = jsonDecode(res.body);
      await saveTokens(
          access: data['accessToken'], refresh: data['refreshToken']);
      return true;
    } catch (_) {
      return false;
    }
  }

  dynamic _decode(http.Response res) {
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  Future<dynamic> _handle(
    Future<http.Response> Function() send, {
    bool authenticated = true,
    bool isRetry = false,
  }) async {
    final res = await send();

    if (res.statusCode == 401 && authenticated && !isRetry) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _handle(send, authenticated: authenticated, isRetry: true);
      }
      await clearTokens();
      throw ApiException(401, 'Session expired. Please log in again.');
    }

    if (res.statusCode >= 400) {
      String message = 'Request failed (${res.statusCode})';
      try {
        final body = _decode(res);
        if (body is Map && body['error'] != null) message = body['error'];
      } catch (_) {}
      throw ApiException(res.statusCode, message);
    }

    return _decode(res);
  }

  // ── Public verbs ─────────────────────────────────────────────────────
  Future<dynamic> get(String path,
      {Map<String, dynamic>? query, bool authenticated = true}) {
    return _handle(
      () async => http.get(_uri(path, query),
          headers: await _headers(authenticated: authenticated)),
      authenticated: authenticated,
    );
  }

  Future<dynamic> post(String path,
      {Map<String, dynamic>? data, bool authenticated = true}) {
    return _handle(
      () async => http.post(
        _uri(path),
        headers: await _headers(authenticated: authenticated),
        body: jsonEncode(data ?? {}),
      ),
      authenticated: authenticated,
    );
  }

  Future<dynamic> patch(String path,
      {Map<String, dynamic>? data, bool authenticated = true}) {
    return _handle(
      () async => http.patch(
        _uri(path),
        headers: await _headers(authenticated: authenticated),
        body: jsonEncode(data ?? {}),
      ),
      authenticated: authenticated,
    );
  }

  Future<dynamic> put(String path,
      {Map<String, dynamic>? data, bool authenticated = true}) {
    return _handle(
      () async => http.put(
        _uri(path),
        headers: await _headers(authenticated: authenticated),
        body: jsonEncode(data ?? {}),
      ),
      authenticated: authenticated,
    );
  }

  // FIXED: delete() had no way to send a request body. Some DELETE
  // endpoints in this backend need one — e.g. teachers.controller.js's
  // removeSubject reads `subject` from req.body (subjects have no numeric
  // ID, only their exact text), and deleteAvailabilitySlot reads `day`
  // from req.body too (even though the route also has a :id path segment
  // it doesn't actually use). Without this, settings_repository.dart's
  // calls to delete(..., data: {...}) failed to even compile
  // ("undefined_named_parameter"). `data` is optional and omitted for
  // DELETE calls that don't need a body, so nothing else that already
  // calls delete(path) is affected.
  Future<dynamic> delete(String path,
      {Map<String, dynamic>? data, bool authenticated = true}) {
    return _handle(
      () async => http.delete(
        _uri(path),
        headers: await _headers(authenticated: authenticated),
        body: data != null ? jsonEncode(data) : null,
      ),
      authenticated: authenticated,
    );
  }
}
