// lib/features/sessions/controllers/session_room_controller.dart
//
// Owns the socket connection + WebRTC peer connection for one active
// session room screen. One instance per (sessionId), created via
// StateNotifierProvider.family and disposed when the screen is popped.
//
// Call/offer polarity: the teacher always initiates the offer once both
// sides have joined (arbitrary but deterministic tie-break — otherwise
// both sides could simultaneously send offers and glare). The student
// only ever answers. Since join order is unpredictable, "both sides
// have joined" is detected two ways: (a) receiving a live
// "session:peer-joined" broadcast (covers being first to join), or (b)
// the join ack itself reporting peerAlreadyPresent (covers being
// second to join) — see socket.server.js / socket_room_service.dart
// fix notes.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show RTCIceCandidate;
import '../../../models/session.dart';
import '../models/session_room_models.dart';
import '../repositories/session_room_repository.dart';
import '../services/socket_room_service.dart';
import '../services/webrtc_room_service.dart';

enum ActiveTool { whiteboard, notes, files, chat }

class SessionRoomState {
  final RoomConnectionStatus connectionStatus;
  final bool peerPresent;
  final bool remoteStreamReady;
  final bool micOn;
  final bool camOn;
  final bool localHandRaised;
  final bool remoteHandRaised;
  final String? lastReactionEmoji; // fleeting, for a toast/animation
  final List<ChatMessageModel> messages;
  final String notesContent;
  final DateTime? notesSavedAt;
  final bool notesSaving;
  final List<SessionFileModel> files;
  final List<WhiteboardStroke> strokes;
  final bool canDrawWhiteboard; // true for teacher always; student if granted
  final ActiveTool activeTool;
  final bool sessionEnded;
  final String? error;

  const SessionRoomState({
    this.connectionStatus = RoomConnectionStatus.connecting,
    this.peerPresent = false,
    this.remoteStreamReady = false,
    this.micOn = true,
    this.camOn = true,
    this.localHandRaised = false,
    this.remoteHandRaised = false,
    this.lastReactionEmoji,
    this.messages = const [],
    this.notesContent = '',
    this.notesSavedAt,
    this.notesSaving = false,
    this.files = const [],
    this.strokes = const [],
    this.canDrawWhiteboard = true,
    this.activeTool = ActiveTool.chat,
    this.sessionEnded = false,
    this.error,
  });

  SessionRoomState copyWith({
    RoomConnectionStatus? connectionStatus,
    bool? peerPresent,
    bool? remoteStreamReady,
    bool? micOn,
    bool? camOn,
    bool? localHandRaised,
    bool? remoteHandRaised,
    String? lastReactionEmoji,
    List<ChatMessageModel>? messages,
    String? notesContent,
    DateTime? notesSavedAt,
    bool? notesSaving,
    List<SessionFileModel>? files,
    List<WhiteboardStroke>? strokes,
    bool? canDrawWhiteboard,
    ActiveTool? activeTool,
    bool? sessionEnded,
    String? error,
  }) {
    return SessionRoomState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      peerPresent: peerPresent ?? this.peerPresent,
      remoteStreamReady: remoteStreamReady ?? this.remoteStreamReady,
      micOn: micOn ?? this.micOn,
      camOn: camOn ?? this.camOn,
      localHandRaised: localHandRaised ?? this.localHandRaised,
      remoteHandRaised: remoteHandRaised ?? this.remoteHandRaised,
      lastReactionEmoji: lastReactionEmoji,
      messages: messages ?? this.messages,
      notesContent: notesContent ?? this.notesContent,
      notesSavedAt: notesSavedAt ?? this.notesSavedAt,
      notesSaving: notesSaving ?? this.notesSaving,
      files: files ?? this.files,
      strokes: strokes ?? this.strokes,
      canDrawWhiteboard: canDrawWhiteboard ?? this.canDrawWhiteboard,
      activeTool: activeTool ?? this.activeTool,
      sessionEnded: sessionEnded ?? this.sessionEnded,
      error: error,
    );
  }
}

class SessionRoomController extends StateNotifier<SessionRoomState> {
  final SessionModel session;
  final String currentUserId;
  final bool isTeacher;
  final SessionRoomRepository _repo;
  final SocketRoomService _socket = SocketRoomService();
  final WebrtcRoomService webrtc = WebrtcRoomService();

  final List<StreamSubscription> _subs = [];
  Timer? _notesDebounce;
  bool _callStarted = false; // guards against double-offering

  SessionRoomController({
    required this.session,
    required this.currentUserId,
    required this.isTeacher,
    SessionRoomRepository? repo,
  })  : _repo = repo ?? SessionRoomRepository(),
        super(SessionRoomState(
          canDrawWhiteboard: isTeacher, // student starts without permission
          activeTool: ActiveTool.chat,
        ));

  Future<void> initialize() async {
    try {
      await webrtc.init();
      final granted = await webrtc.requestPermissions();
      if (!granted) {
        state = state.copyWith(
            error: 'Camera/microphone permission is required to join.');
      } else {
        await webrtc.openLocalMedia();
      }

      // Load history/notes/files in parallel with connecting the socket.
      final results = await Future.wait([
        _repo.getChatHistory(session.id),
        _repo.getNotes(session.id),
        _repo.getFiles(session.id),
      ]);
      state = state.copyWith(
        messages: results[0] as List<ChatMessageModel>,
        notesContent: (results[1] as SessionNoteModel).content,
        files: results[2] as List<SessionFileModel>,
      );

      _wireSocketListeners();
      await _socket.connectAndJoin(session.id);
    } catch (e) {
      state = state.copyWith(error: 'Failed to join the session: $e');
    }
  }

  void _wireSocketListeners() {
    _subs.addAll([
      _socket.connectionStatus.listen((s) {
        state = state.copyWith(connectionStatus: s);
      }),
      // FIXED: covers being the SECOND person to join — the join ack
      // itself reports whether a peer was already in the room, since
      // that peer's own "session:peer-joined" broadcast (fired when
      // THEY joined) happened before we were around to receive it.
      _socket.onJoined.listen((peerAlreadyPresent) {
        if (peerAlreadyPresent) {
          state = state.copyWith(peerPresent: true);
          if (isTeacher) _startCall();
        }
      }),
      // Covers being the FIRST person to join — we receive this live
      // broadcast when the second person joins after us.
      _socket.onPeerJoined.listen((_) {
        state = state.copyWith(peerPresent: true);
        if (isTeacher) _startCall();
      }),
      _socket.onPeerLeft.listen((_) {
        state = state.copyWith(peerPresent: false, remoteStreamReady: false);
        // Allow a fresh offer if the peer reconnects later in the same
        // session — otherwise _callStarted would permanently block any
        // renegotiation after the first peer ever left once.
        _callStarted = false;
      }),
      _socket.onChatMessage.listen((msg) {
        state = state.copyWith(messages: [...state.messages, msg]);
      }),
      _socket.onWebrtcOffer.listen((payload) async {
        // Receiving an offer is itself proof the other side is present,
        // regardless of which join-detection path fired (or didn't).
        state = state.copyWith(peerPresent: true);
        final creds = await _repo.getTurnCredentials(session.id);
        final answer = await webrtc.createAnswerForOffer(
          creds: creds,
          remoteSdp: Map<String, dynamic>.from(payload['sdp']),
          onIceCandidate: (c) => _socket.sendIceCandidate({
            'candidate': c.candidate,
            'sdpMid': c.sdpMid,
            'sdpMLineIndex': c.sdpMLineIndex,
          }),
          onRemoteStreamReady: () => state =
              state.copyWith(remoteStreamReady: true, peerPresent: true),
        );
        _socket.sendAnswer(answer);
      }),
      _socket.onWebrtcAnswer.listen((payload) async {
        state = state.copyWith(peerPresent: true);
        await webrtc
            .applyRemoteAnswer(Map<String, dynamic>.from(payload['sdp']));
      }),
      _socket.onWebrtcIceCandidate.listen((payload) async {
        await webrtc.addRemoteIceCandidate(
            Map<String, dynamic>.from(payload['candidate']));
      }),
      _socket.onWebrtcHangup.listen((_) async {
        await webrtc.hangup();
        state = state.copyWith(remoteStreamReady: false);
        _callStarted = false;
      }),
      _socket.onWhiteboardDraw.listen((stroke) {
        state = state.copyWith(strokes: [...state.strokes, stroke]);
      }),
      _socket.onWhiteboardClear.listen((_) {
        state = state.copyWith(strokes: []);
      }),
      _socket.onWhiteboardUndo.listen((_) {
        // Broadcast undo has no stroke id in the wire protocol (kept
        // simple per signaling.handlers.js) — pop the last stroke by
        // whichever author sent this event. Since undo only ever
        // affects the sender's own last stroke, and we don't know who
        // sent it apart from the fact it's not us (we already popped
        // ours locally on tap — see undoLastStroke()), this is a no-op
        // safeguard for double-application; real removal happens
        // client-side per-author in undoLastStroke()/redoLastStroke().
      }),
      _socket.onWhiteboardPermission.listen((canDraw) {
        if (!isTeacher) state = state.copyWith(canDrawWhiteboard: canDraw);
      }),
      _socket.onHandRaised.listen((payload) {
        if (payload['userId'] != currentUserId) {
          state = state.copyWith(remoteHandRaised: payload['raised'] == true);
        }
      }),
      _socket.onReaction.listen((payload) {
        state = state.copyWith(lastReactionEmoji: payload['emoji'] as String?);
      }),
      _socket.onSessionEnded.listen((_) async {
        await webrtc.hangup();
        state = state.copyWith(sessionEnded: true);
      }),
    ]);
  }

  Future<void> _startCall() async {
    if (_callStarted) return; // guard against double-offering
    _callStarted = true;
    final creds = await _repo.getTurnCredentials(session.id);
    final offer = await webrtc.createOffer(
      creds: creds,
      onIceCandidate: (c) => _socket.sendIceCandidate({
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      }),
      onRemoteStreamReady: () =>
          state = state.copyWith(remoteStreamReady: true, peerPresent: true),
    );
    _socket.sendOffer(offer);
  }

  // ── Chat ────────────────────────────────────────────────────────────
  void sendChat(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    _socket.sendChat(trimmed, onAck: (ok, error) async {
      if (!ok) {
        // Socket send failed — fall back to REST per the controller's
        // documented dual-path design, then locally append so the
        // sender sees it even if the room broadcast round-trip fails.
        try {
          final msg = await _repo.postChatFallback(session.id, trimmed);
          state = state.copyWith(messages: [...state.messages, msg]);
        } catch (_) {
          state = state.copyWith(error: error ?? 'Failed to send message.');
        }
      }
    });
  }

  // ── Notes (debounced autosave) ────────────────────────────────────────
  void updateNotes(String content) {
    state = state.copyWith(notesContent: content);
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 800), () async {
      state = state.copyWith(notesSaving: true);
      try {
        final saved = await _repo.patchNotes(session.id, content);
        state = state.copyWith(
            notesSaving: false,
            notesSavedAt: saved.updatedAt ?? DateTime.now());
      } catch (_) {
        state = state.copyWith(notesSaving: false);
      }
    });
  }

  // ── Files ─────────────────────────────────────────────────────────────
  Future<void> uploadFile(List<int> bytes, String fileName) async {
    try {
      final file = await _repo.uploadFile(
          sessionId: session.id, bytes: bytes, fileName: fileName);
      state = state.copyWith(files: [file, ...state.files]);
    } catch (e) {
      state = state.copyWith(error: 'Failed to upload file: $e');
    }
  }

  // ── Whiteboard ────────────────────────────────────────────────────────
  final List<WhiteboardStroke> _localStrokeHistory = [];
  final List<WhiteboardStroke> _redoBuffer = [];

  void addStroke(WhiteboardStroke stroke) {
    if (!(isTeacher || state.canDrawWhiteboard)) return;
    state = state.copyWith(strokes: [...state.strokes, stroke]);
    _localStrokeHistory.add(stroke);
    _redoBuffer.clear();
    _socket.sendWhiteboardDraw(stroke);
  }

  void undoLastStroke() {
    if (_localStrokeHistory.isEmpty) return;
    final last = _localStrokeHistory.removeLast();
    _redoBuffer.add(last);
    state = state.copyWith(
        strokes: state.strokes.where((s) => s.id != last.id).toList());
    _socket.sendWhiteboardUndo();
  }

  void redoLastStroke() {
    if (_redoBuffer.isEmpty) return;
    final stroke = _redoBuffer.removeLast();
    _localStrokeHistory.add(stroke);
    state = state.copyWith(strokes: [...state.strokes, stroke]);
    _socket.sendWhiteboardDraw(stroke);
    _socket.sendWhiteboardRedo();
  }

  void clearWhiteboard() {
    _localStrokeHistory.clear();
    _redoBuffer.clear();
    state = state.copyWith(strokes: []);
    _socket.sendWhiteboardClear();
  }

  void setStudentDrawPermission(bool canDraw) {
    if (!isTeacher) return;
    _socket.setStudentDrawPermission(canDraw);
  }

  // ── Presence ──────────────────────────────────────────────────────────
  void toggleRaiseHand() {
    final next = !state.localHandRaised;
    state = state.copyWith(localHandRaised: next);
    _socket.raiseHand(next);
  }

  void sendReaction(String emoji) {
    _socket.sendReaction(emoji);
  }

  // ── Media controls ────────────────────────────────────────────────────
  void toggleMic() => state = state.copyWith(micOn: webrtc.toggleMic());
  void toggleCam() => state = state.copyWith(camOn: webrtc.toggleCam());

  void setActiveTool(ActiveTool tool) =>
      state = state.copyWith(activeTool: tool);

  // ── End / leave ───────────────────────────────────────────────────────
  Future<void> endSessionAsTeacher() async {
    if (!isTeacher) return;
    await _repo.endSession(session.id);
    // Server emits session:ended + kicks both sockets from the room;
    // local teardown happens via the onSessionEnded listener.
  }

  Future<void> leaveRoom() async {
    _socket.sendHangup();
    await webrtc.hangup();
  }

  @override
  Future<void> dispose() async {
    _notesDebounce?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    _socket.dispose();
    await webrtc.dispose();
    super.dispose();
  }
}

final sessionRoomControllerProvider = StateNotifierProvider.autoDispose
    .family<SessionRoomController, SessionRoomState, SessionRoomArgs>(
  (ref, args) {
    final controller = SessionRoomController(
      session: args.session,
      currentUserId: args.currentUserId,
      isTeacher: args.isTeacher,
    );
    controller.initialize();
    ref.onDispose(() => controller.dispose());
    return controller;
  },
);

class SessionRoomArgs {
  final SessionModel session;
  final String currentUserId;
  final bool isTeacher;
  const SessionRoomArgs({
    required this.session,
    required this.currentUserId,
    required this.isTeacher,
  });

  @override
  bool operator ==(Object other) =>
      other is SessionRoomArgs && other.session.id == session.id;
  @override
  int get hashCode => session.id.hashCode;
}
