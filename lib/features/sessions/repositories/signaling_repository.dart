// lib/features/sessions/repositories/signaling_repository.dart
//
// Thin wrapper around socket_io_client — talks to this repo's own
// Socket.IO server (src/realtime/socket.server.js), not any third-party
// realtime SaaS. One instance per meeting room; created fresh each time
// SessionRoomScreen opens and disposed when it closes.
//
// ⚠️ Untestable in the environment this was written in (no Flutter SDK,
// no two real devices to actually connect two peers) — built to match
// documented socket_io_client/flutter_webrtc APIs as closely as
// possible, but treat the connection lifecycle as needing real-device
// verification before you trust it in production.

import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/api/api_service.dart';

class SignalingRepository {
  io.Socket? _socket;

  final _peerJoinedController = StreamController<String>.broadcast();
  final _peerLeftController = StreamController<String>.broadcast();
  final _offerController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _answerController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _iceCandidateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatController = StreamController<Map<String, dynamic>>.broadcast();
  final _whiteboardStrokeController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _whiteboardClearController = StreamController<void>.broadcast();
  final _whiteboardPermissionController =
      StreamController<bool>.broadcast();
  final _raiseHandController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _reactionController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<String> get onPeerJoined => _peerJoinedController.stream;
  Stream<String> get onPeerLeft => _peerLeftController.stream;
  Stream<Map<String, dynamic>> get onOffer => _offerController.stream;
  Stream<Map<String, dynamic>> get onAnswer => _answerController.stream;
  Stream<Map<String, dynamic>> get onIceCandidate =>
      _iceCandidateController.stream;
  Stream<Map<String, dynamic>> get onChatMessage => _chatController.stream;
  Stream<Map<String, dynamic>> get onWhiteboardStroke =>
      _whiteboardStrokeController.stream;
  Stream<void> get onWhiteboardClear => _whiteboardClearController.stream;
  Stream<bool> get onWhiteboardPermission =>
      _whiteboardPermissionController.stream;
  Stream<Map<String, dynamic>> get onRaiseHand => _raiseHandController.stream;
  Stream<Map<String, dynamic>> get onReaction => _reactionController.stream;

  String get _socketBaseUrl {
    final url = ApiService.baseUrl.replaceAll(RegExp(r'/api(/v\d+)?/?$'), '');
    return url.isEmpty ? '/' : url;
  }

  /// Connects and joins the given session's room. Completes once the
  /// server acks the join (or throws if unauthorized/not found).
  Future<void> connectAndJoin(String sessionId) async {
    final token = await ApiService.instance.getAccessToken();

    final completer = Completer<void>();
    final socket = io.io(
      _socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/socket.io')
          .setAuth({'token': token})
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );
    _socket = socket;

    socket.onConnectError((err) {
      if (!completer.isCompleted) completer.completeError(Exception('$err'));
    });
    socket.onError((err) {
      if (!completer.isCompleted) completer.completeError(Exception('$err'));
    });

    socket.on('session:peer-joined',
        (data) => _peerJoinedController.add((data as Map)['userId'] as String));
    socket.on('session:peer-left',
        (data) => _peerLeftController.add((data as Map)['userId'] as String));
    socket.on('webrtc:offer',
        (data) => _offerController.add(Map<String, dynamic>.from(data as Map)));
    socket.on('webrtc:answer',
        (data) => _answerController.add(Map<String, dynamic>.from(data as Map)));
    socket.on(
        'webrtc:ice-candidate',
        (data) => _iceCandidateController
            .add(Map<String, dynamic>.from(data as Map)));
    socket.on('chat:new',
        (data) => _chatController.add(Map<String, dynamic>.from(data as Map)));
    socket.on(
        'whiteboard:stroke',
        (data) => _whiteboardStrokeController
            .add(Map<String, dynamic>.from(data as Map)));
    socket.on('whiteboard:clear', (_) => _whiteboardClearController.add(null));
    socket.on(
        'whiteboard:permission',
        (data) => _whiteboardPermissionController
            .add((data as Map)['studentCanDraw'] as bool? ?? true));
    socket.on(
        'presence:raise-hand',
        (data) =>
            _raiseHandController.add(Map<String, dynamic>.from(data as Map)));
    socket.on(
        'presence:reaction',
        (data) =>
            _reactionController.add(Map<String, dynamic>.from(data as Map)));

    socket.onConnect((_) {
      socket.emitWithAck('session:join', sessionId, ack: (response) {
        final map = response is Map ? response : {};
        if (map['error'] != null) {
          if (!completer.isCompleted) {
            completer.completeError(Exception(map['error'] as String));
          }
        } else if (!completer.isCompleted) {
          completer.complete();
        }
      });
    });

    socket.connect();
    return completer.future;
  }

  void sendOffer(Map<String, dynamic> sdp) =>
      _socket?.emit('webrtc:offer', {'sdp': sdp});
  void sendAnswer(Map<String, dynamic> sdp) =>
      _socket?.emit('webrtc:answer', {'sdp': sdp});
  void sendIceCandidate(Map<String, dynamic> candidate) =>
      _socket?.emit('webrtc:ice-candidate', {'candidate': candidate});

  void sendChat(String body) => _socket?.emit('chat:send', {'body': body});

  void sendStroke(Map<String, dynamic> stroke) =>
      _socket?.emit('whiteboard:stroke', stroke);
  void sendWhiteboardClear() => _socket?.emit('whiteboard:clear');
  void setWhiteboardPermission(bool studentCanDraw) =>
      _socket?.emit('whiteboard:set-permission', {
        'studentCanDraw': studentCanDraw,
      });

  void raiseHand(bool raised) =>
      _socket?.emit('presence:raise-hand', {'raised': raised});
  void sendReaction(String emoji) =>
      _socket?.emit('presence:reaction', {'emoji': emoji});

  void dispose() {
    _socket?.dispose();
    _peerJoinedController.close();
    _peerLeftController.close();
    _offerController.close();
    _answerController.close();
    _iceCandidateController.close();
    _chatController.close();
    _whiteboardStrokeController.close();
    _whiteboardClearController.close();
    _whiteboardPermissionController.close();
    _raiseHandController.close();
    _reactionController.close();
  }
}
