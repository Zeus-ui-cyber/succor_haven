import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

void main() {
  group('Backend Connection Tests', () {
    const String baseUrl = 'http://127.0.0.1:3000';

    test('HTTP server is reachable', () async {
      try {
        final response = await http.get(Uri.parse('$baseUrl/health'));
        expect(response.statusCode, 200);
        expect(response.body, contains('ok'));
        print('✅ HTTP connection successful: ${response.body}');
      } catch (e) {
        fail('❌ Failed to connect to HTTP server at $baseUrl: $e');
      }
    });

    test('Socket.IO server is reachable', () async {
      bool connected = false;
      
      final socket = io.io(
        baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setPath('/socket.io')
            .disableAutoConnect()
            .build(),
      );

      socket.onConnect((_) {
        connected = true;
      });

      socket.onConnectError((error) {
        print('Socket.IO Connect Error: $error');
      });

      socket.onError((error) {
        print('Socket.IO App Error: $error');
        if (error.toString().contains('Missing auth token')) {
          print('✅ Socket.IO server is reachable (and correctly rejected unauthenticated connection)');
          connected = true; // Connection reached the server middleware!
        }
      });

      socket.connect();

      // Wait up to 5 seconds for connection
      for (int i = 0; i < 50; i++) {
        if (connected) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      socket.dispose();

      expect(connected, isTrue, reason: 'Socket.IO failed to connect within 5 seconds');
      print('✅ Socket.IO connection successful!');
    });
  });
}
