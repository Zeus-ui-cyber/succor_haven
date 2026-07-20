// lib/core/providers/realtime_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../api/api_service.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/appointments/controllers/appointment_controller.dart';
import '../../features/sessions/controllers/session_list_controller.dart';

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService(ref);
  ref.onDispose(() {
    service.disconnect();
  });
  return service;
});

class RealtimeService {
  final Ref _ref;
  io.Socket? _socket;

  RealtimeService(this._ref) {
    // Catch deep-links or hot restarts on web where the user is already logged in
    // but the authControllerProvider hasn't been explicitly populated via the login screen.
    _connect();

    // Watch auth state changes. When user logs in, we connect the socket.
    // When they log out, we disconnect.
    _ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) {
        if (next.user != null) {
          _connect();
        } else {
          disconnect();
        }
      },
      fireImmediately: true,
    );
  }

  String get _socketBaseUrl {
    final url = ApiService.baseUrl.replaceAll(RegExp(r'/api(/v\d+)?/?$'), '');
    return url.isEmpty ? '/' : url;
  }

  Future<void> _connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await ApiService.instance.getAccessToken();
    if (token == null) return;

    debugPrint('[RealtimeService] Connecting to $_socketBaseUrl...');

    final socket = io.io(
      _socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setPath('/socket.io')
          .setAuth({'token': token})
          .enableForceNew()
          .build(),
    );

    _socket = socket;

    socket.onConnect((_) {
      debugPrint('[RealtimeService] Connected successfully');
    });

    socket.on('appointment:changed', (data) {
      debugPrint('[RealtimeService] appointment:changed received: $data');
      _ref.invalidate(myAppointmentsProvider);
      _ref.invalidate(teacherAppointmentsProvider);
      _ref.invalidate(mySessionsProvider); // Session feed can include appointments
    });

    socket.on('session:changed', (data) {
      debugPrint('[RealtimeService] session:changed received: $data');
      _ref.invalidate(mySessionsProvider);
    });

    socket.onDisconnect((_) {
      debugPrint('[RealtimeService] Disconnected from server');
    });

    socket.onConnectError((err) {
      debugPrint('[RealtimeService] Connection error: $err');
    });
  }

  void disconnect() {
    if (_socket != null) {
      debugPrint('[RealtimeService] Disposing socket connection');
      _socket?.dispose();
      _socket = null;
    }
  }
}
