// lib/features/sessions/services/socket_room_service.dart
//
// Thin wrapper around socket_io_client, matching the event contract of
// src/realtime/socket.server.js + the four handler modules. One
// instance per active session-room screen; dispose() tears the socket
// down completely (no reconnection kept alive in the background).
//
// Auth: same bearer-token convention as ApiService — read fresh from
// secure storage at connect time rather than cached, since a token
// refresh could have happened between screens.

import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/api/api_service.dart';
import '../models/session_room_models.dart';

enum RoomConnectionStatus {
  connecting,
  joined,
  reconnecting,
  disconnected,
  error
}

class SocketRoomService {
  io.Socket? _socket;
  final _api = ApiService.instance;

  final _connectionStatusCtrl =
      StreamController<RoomConnectionStatus>.broadcast();
  final _peerJoinedCtrl = StreamController<String>.broadcast(); // userId
  final _peerLeftCtrl = StreamController<String>.broadcast(); // userId
  final _chatCtrl = StreamController<ChatMessageModel>.broadcast();
  final _webrtcOfferCtrl =
      StreamController<Map<String, dynamic>>.broadcast(); // {fromUserId, sdp}
  final _webrtcAnswerCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _webrtcIceCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _webrtcHangupCtrl = StreamController<String>.broadcast(); // fromUserId
  final _whiteboardDrawCtrl = StreamController<WhiteboardStroke>.broadcast();
  final _whiteboardUndoCtrl = StreamController<void>.broadcast();
  final _whiteboardRedoCtrl = StreamController<void>.broadcast();
  final _whiteboardClearCtrl = StreamController<void>.broadcast();
  final _whiteboardPermissionCtrl = StreamController<bool>.broadcast();
  final _handRaisedCtrl =
      StreamController<Map<String, dynamic>>.broadcast(); // {userId, raised}
  final _reactionCtrl =
      StreamController<Map<String, dynamic>>.broadcast(); // {userId, emoji}
  final _sessionEndedCtrl = StreamController<void>.broadcast();

  Stream<RoomConnectionStatus> get connectionStatus =>
      _connectionStatusCtrl.stream;
  Stream<String> get onPeerJoined => _peerJoinedCtrl.stream;
  Stream<String> get onPeerLeft => _peerLeftCtrl.stream;
  Stream<ChatMessageModel> get onChatMessage => _chatCtrl.stream;
  Stream<Map<String, dynamic>> get onWebrtcOffer => _webrtcOfferCtrl.stream;
  Stream<Map<String, dynamic>> get onWebrtcAnswer => _webrtcAnswerCtrl.stream;
  Stream<Map<String, dynamic>> get onWebrtcIceCandidate =>
      _webrtcIceCtrl.stream;
  Stream<String> get onWebrtcHangup => _webrtcHangupCtrl.stream;
  Stream<WhiteboardStroke> get onWhiteboardDraw => _whiteboardDrawCtrl.stream;
  Stream<void> get onWhiteboardUndo => _whiteboardUndoCtrl.stream;
  Stream<void> get onWhiteboardRedo => _whiteboardRedoCtrl.stream;
  Stream<void> get onWhiteboardClear => _whiteboardClearCtrl.stream;
  Stream<bool> get onWhiteboardPermission => _whiteboardPermissionCtrl.stream;
  Stream<Map<String, dynamic>> get onHandRaised => _handRaisedCtrl.stream;
  Stream<Map<String, dynamic>> get onReaction => _reactionCtrl.stream;
  Stream<void> get onSessionEnded => _sessionEndedCtrl.stream;

  Future<void> connectAndJoin(String sessionId) async {
    final token = await _api.getAccessToken();
    _connectionStatusCtrl.add(RoomConnectionStatus.connecting);

    // Strip trailing path segments like /api if present — Socket.IO
    // connects to the bare origin and uses its own `path` option.
    final origin = Uri.parse(ApiService.baseUrl).replace(path: '').toString();

    _socket = io.io(
      origin,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/socket.io')
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!
      ..onConnect((_) => _joinSession(sessionId))
      ..onReconnect((_) => _joinSession(sessionId))
      ..onReconnectAttempt(
          (_) => _connectionStatusCtrl.add(RoomConnectionStatus.reconnecting))
      ..onDisconnect(
          (_) => _connectionStatusCtrl.add(RoomConnectionStatus.disconnected))
      ..onConnectError(
          (_) => _connectionStatusCtrl.add(RoomConnectionStatus.error))
      ..onError((_) => _connectionStatusCtrl.add(RoomConnectionStatus.error))
      ..on('session:peer-joined',
          (data) => _peerJoinedCtrl.add(data?['userId']?.toString() ?? ''))
      ..on('session:peer-left',
          (data) => _peerLeftCtrl.add(data?['userId']?.toString() ?? ''))
      ..on('chat:message', (data) {
        if (data is Map) {
          _chatCtrl
              .add(ChatMessageModel.fromJson(Map<String, dynamic>.from(data)));
        }
      })
      ..on('webrtc:offer',
          (data) => _webrtcOfferCtrl.add(Map<String, dynamic>.from(data)))
      ..on('webrtc:answer',
          (data) => _webrtcAnswerCtrl.add(Map<String, dynamic>.from(data)))
      ..on('webrtc:ice-candidate',
          (data) => _webrtcIceCtrl.add(Map<String, dynamic>.from(data)))
      ..on(
          'webrtc:hangup',
          (data) =>
              _webrtcHangupCtrl.add(data?['fromUserId']?.toString() ?? ''))
      ..on('whiteboard:draw', (data) {
        if (data is Map) {
          _whiteboardDrawCtrl
              .add(WhiteboardStroke.fromJson(Map<String, dynamic>.from(data)));
        }
      })
      ..on('whiteboard:undo', (_) => _whiteboardUndoCtrl.add(null))
      ..on('whiteboard:redo', (_) => _whiteboardRedoCtrl.add(null))
      ..on('whiteboard:clear', (_) => _whiteboardClearCtrl.add(null))
      ..on('whiteboard:student-permission',
          (data) => _whiteboardPermissionCtrl.add(data?['canDraw'] == true))
      ..on('presence:hand-raised',
          (data) => _handRaisedCtrl.add(Map<String, dynamic>.from(data)))
      ..on('presence:reaction',
          (data) => _reactionCtrl.add(Map<String, dynamic>.from(data)))
      ..on('session:ended', (_) => _sessionEndedCtrl.add(null));

    _socket!.connect();
  }

  void _joinSession(String sessionId) {
    _socket?.emitWithAck('session:join', sessionId, ack: (response) {
      if (response is Map && response['ok'] == true) {
        _connectionStatusCtrl.add(RoomConnectionStatus.joined);
      } else {
        _connectionStatusCtrl.add(RoomConnectionStatus.error);
      }
    });
  }

  // ── Emit helpers ────────────────────────────────────────────────────
  void sendChat(String body, {void Function(bool ok, String? error)? onAck}) {
    _socket?.emitWithAck('chat:send', {'body': body}, ack: (res) {
      if (res is Map) {
        onAck?.call(res['ok'] == true, res['error'] as String?);
      }
    });
  }

  void sendOffer(Map<String, dynamic> sdp) =>
      _socket?.emit('webrtc:offer', {'sdp': sdp});
  void sendAnswer(Map<String, dynamic> sdp) =>
      _socket?.emit('webrtc:answer', {'sdp': sdp});
  void sendIceCandidate(Map<String, dynamic> candidate) =>
      _socket?.emit('webrtc:ice-candidate', {'candidate': candidate});
  void sendHangup() => _socket?.emit('webrtc:hangup');

  void sendWhiteboardDraw(WhiteboardStroke stroke) =>
      _socket?.emit('whiteboard:draw', stroke.toJson());
  void sendWhiteboardUndo() => _socket?.emit('whiteboard:undo');
  void sendWhiteboardRedo() => _socket?.emit('whiteboard:redo');
  void sendWhiteboardClear() => _socket?.emit('whiteboard:clear');
  void setStudentDrawPermission(bool canDraw) =>
      _socket?.emit('whiteboard:set-student-permission', {'canDraw': canDraw});

  void raiseHand(bool raised) =>
      _socket?.emit('presence:raise-hand', {'raised': raised});
  void sendReaction(String emoji) =>
      _socket?.emit('presence:reaction', {'emoji': emoji});

  void dispose() {
    _socket?.dispose();
    _socket = null;
    for (final c in [
      _connectionStatusCtrl,
      _peerJoinedCtrl,
      _peerLeftCtrl,
      _chatCtrl,
      _webrtcOfferCtrl,
      _webrtcAnswerCtrl,
      _webrtcIceCtrl,
      _webrtcHangupCtrl,
      _whiteboardDrawCtrl,
      _whiteboardUndoCtrl,
      _whiteboardRedoCtrl,
      _whiteboardClearCtrl,
      _whiteboardPermissionCtrl,
      _handRaisedCtrl,
      _reactionCtrl,
      _sessionEndedCtrl,
    ]) {
      c.close();
    }
  }
}
