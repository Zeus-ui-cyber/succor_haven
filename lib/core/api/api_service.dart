// This is the single place where ALL network calls go through.
// It attaches your JWT token to every request automatically.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  // Change this to your Node.js server address when you have one.
  // For local testing on Android emulator, use 10.0.2.2 instead of localhost.
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // This "interceptor" runs before every request.
    // It reads the saved token and adds it to the header.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          // 401 means the token expired — you'd navigate to login here
          if (error.response?.statusCode == 401) {
            _storage.delete(key: 'jwt_token');
          }
          return handler.next(error);
        },
      ),
    );
  }

  // Reusable GET request
  Future<Response> get(String path, {Map<String, dynamic>? params}) {
    return _dio.get(path, queryParameters: params);
  }

  // Reusable POST request
  Future<Response> post(String path, {Map<String, dynamic>? data}) {
    return _dio.post(path, data: data);
  }

  // Reusable PUT request (for updates)
  Future<Response> put(String path, {Map<String, dynamic>? data}) {
    return _dio.put(path, data: data);
  }

  // Reusable DELETE request
  Future<Response> delete(String path) {
    return _dio.delete(path);
  }
}
