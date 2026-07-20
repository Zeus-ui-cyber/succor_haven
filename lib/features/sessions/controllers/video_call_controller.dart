// lib/features/sessions/controllers/video_call_controller.dart
//
// WebRTC core for the 1-on-1 video call. Negotiation pattern: whichever
// side is already in the room when the other joins creates the offer
// (triggered by signaling_repository's onPeerJoined) — see
// signaling.handlers.js for why that's collision-free for a strictly
// 2-participant room.
//
// Audio: neither renderer muted anything by default, which meant the
// local preview played your own mic straight back through your speakers
// (echo/feedback loop), AND — on Flutter Web specifically — remote audio
// can get silently blocked by the browser's autoplay policy unless the
// renderer is explicitly told it's allowed to play unmuted. Fixed below
// by setting localRenderer.muted = true / remoteRenderer.muted = false
// right after initialize(), and re-asserting the remote unmute the
// moment the actual remote stream arrives in onTrack.
//
// ⚠️ Written to match documented flutter_webrtc / socket_io_client APIs
// as closely as possible, but this environment has no Flutter SDK and no
// two real devices to actually exercise a live connection — treat this
// as needing real-device verification, not as pre-tested.

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../repositories/signaling_repository.dart';
import '../repositories/sessions_repository.dart';
import 'session_list_controller.dart' show sessionsRepositoryProvider;

enum CallConnectionState {
  idle,
  requestingPermissions,
  connectingSignaling,
  waitingForPeer,
  negotiating,
  connected,
  failed,
}

class VideoCallState {
  final CallConnectionState connectionState;
  final bool cameraOn;
  final bool micOn;
  final bool speakerOn;
  final bool remoteConnected;
  final String? errorMessage;

  const VideoCallState({
    required this.connectionState,
    required this.cameraOn,
    required this.micOn,
    required this.speakerOn,
    required this.remoteConnected,
    this.errorMessage,
  });

  factory VideoCallState.initial() => const VideoCallState(
        connectionState: CallConnectionState.idle,
        cameraOn: true,
        micOn: true,
        speakerOn: true,
        remoteConnected: false,
      );

  VideoCallState copyWith({
    CallConnectionState? connectionState,
    bool? cameraOn,
    bool? micOn,
    bool? speakerOn,
    bool? remoteConnected,
    String? errorMessage,
  }) =>
      VideoCallState(
        connectionState: connectionState ?? this.connectionState,
        cameraOn: cameraOn ?? this.cameraOn,
        micOn: micOn ?? this.micOn,
        speakerOn: speakerOn ?? this.speakerOn,
        remoteConnected: remoteConnected ?? this.remoteConnected,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class VideoCallController extends StateNotifier<VideoCallState> {
  final SignalingRepository signaling;
  final SessionsRepository sessionsRepo;
  final String sessionId;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  MediaStream? _localStream;
  RTCPeerConnection? _pc;
  final List<StreamSubscription> _subs = [];

  VideoCallController({
    required this.signaling,
    required this.sessionsRepo,
    required this.sessionId,
  }) : super(VideoCallState.initial());

  Future<void> start() async {
    try {
      state = state.copyWith(
          connectionState: CallConnectionState.requestingPermissions);
      await _ensurePermissions();

      await localRenderer.initialize();
      await remoteRenderer.initialize();

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });
      localRenderer.srcObject = _localStream;

      // FIXED: mute the local preview so you never hear your own mic
      // looped back through your speakers (echo/feedback), and
      // explicitly unmute the remote renderer so the peer's audio isn't
      // silently blocked by the browser's autoplay policy on web.
      localRenderer.muted = true;
      remoteRenderer.muted = false;

      state = state.copyWith(
          connectionState: CallConnectionState.connectingSignaling);
      _listen();
      await signaling.connectAndJoin(sessionId);
      state =
          state.copyWith(connectionState: CallConnectionState.waitingForPeer);
    } catch (e) {
      state = state.copyWith(
        connectionState: CallConnectionState.failed,
        errorMessage: '$e',
      );
    }
  }

  Future<void> _ensurePermissions() async {
    if (kIsWeb) return; // browser's own getUserMedia prompt handles this
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!camera.isGranted || !mic.isGranted) {
      throw Exception(
          'Camera and microphone permissions are required to join.');
    }
  }

  void _listen() {
    _subs.add(signaling.onPeerJoined.listen((_) => _createOffer()));
    _subs.add(signaling.onOffer.listen(_handleOffer));
    _subs.add(signaling.onAnswer.listen(_handleAnswer));
    _subs.add(signaling.onIceCandidate.listen(_handleRemoteIceCandidate));
    _subs.add(signaling.onPeerLeft.listen((_) {
      remoteRenderer.srcObject = null;
      state = state.copyWith(
        remoteConnected: false,
        connectionState: CallConnectionState.waitingForPeer,
      );
    }));
  }

  Future<RTCPeerConnection> _ensurePeerConnection() async {
    final existing = _pc;
    if (existing != null) return existing;

    final iceServers = await sessionsRepo.getTurnCredentials(sessionId);
    final pc = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });

    final stream = _localStream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await pc.addTrack(track, stream);
      }
    }

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      signaling.sendIceCandidate({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
        // Re-assert unmuted right when the real remote stream lands —
        // some browsers reset renderer audio state when srcObject changes.
        remoteRenderer.muted = false;
        state = state.copyWith(
          remoteConnected: true,
          connectionState: CallConnectionState.connected,
        );
      }
    };

    pc.onConnectionState = (rtcState) {
      if (rtcState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          rtcState ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        state = state.copyWith(connectionState: CallConnectionState.failed);
      }
    };

    _pc = pc;
    return pc;
  }

  Future<void> _createOffer() async {
    try {
      state = state.copyWith(connectionState: CallConnectionState.negotiating);
      final pc = await _ensurePeerConnection();
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      signaling.sendOffer({'sdp': offer.sdp, 'type': offer.type});
    } catch (e) {
      state = state.copyWith(
        connectionState: CallConnectionState.failed,
        errorMessage: '$e',
      );
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> data) async {
    try {
      state = state.copyWith(connectionState: CallConnectionState.negotiating);
      final pc = await _ensurePeerConnection();
      final sdpData = data['sdp'] as Map;
      await pc.setRemoteDescription(
        RTCSessionDescription(
            sdpData['sdp'] as String, sdpData['type'] as String),
      );
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      signaling.sendAnswer({'sdp': answer.sdp, 'type': answer.type});
    } catch (e) {
      state = state.copyWith(
        connectionState: CallConnectionState.failed,
        errorMessage: '$e',
      );
    }
  }

  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    try {
      final pc = await _ensurePeerConnection();
      final sdpData = data['sdp'] as Map;
      await pc.setRemoteDescription(
        RTCSessionDescription(
            sdpData['sdp'] as String, sdpData['type'] as String),
      );
    } catch (e) {
      state = state.copyWith(
        connectionState: CallConnectionState.failed,
        errorMessage: '$e',
      );
    }
  }

  Future<void> _handleRemoteIceCandidate(Map<String, dynamic> data) async {
    try {
      final pc = await _ensurePeerConnection();
      final c = data['candidate'] as Map;
      await pc.addCandidate(RTCIceCandidate(
        c['candidate'] as String?,
        c['sdpMid'] as String?,
        c['sdpMLineIndex'] as int?,
      ));
    } catch (_) {
      // Benign — a candidate can arrive just before the remote description
      // is set in rare orderings; flutter_webrtc queues most of these
      // internally, and a stray failure here isn't fatal to the call.
    }
  }

  void toggleCamera() {
    final tracks = _localStream?.getVideoTracks() ?? [];
    if (tracks.isEmpty) return;
    final newValue = !state.cameraOn;
    for (final t in tracks) {
      t.enabled = newValue;
    }
    state = state.copyWith(cameraOn: newValue);
  }

  void toggleMic() {
    final tracks = _localStream?.getAudioTracks() ?? [];
    if (tracks.isEmpty) return;
    final newValue = !state.micOn;
    for (final t in tracks) {
      t.enabled = newValue;
    }
    state = state.copyWith(micOn: newValue);
  }

  Future<void> toggleSpeaker() async {
    final newValue = !state.speakerOn;
    try {
      await Helper.setSpeakerphoneOn(newValue);
    } catch (_) {
      // No speaker-routing control on this platform (e.g. web) — the
      // toggle still flips in the UI, it just won't change output device.
    }
    state = state.copyWith(speakerOn: newValue);
  }

  Future<void> leave() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _pc?.close();
    _pc = null;
    final stream = _localStream;
    if (stream != null) {
      for (final t in stream.getTracks()) {
        await t.stop();
      }
      await stream.dispose();
    }
    _localStream = null;
    // Note: does NOT dispose `signaling` — it's a shared instance owned by
    // signalingRepositoryProvider (chat/whiteboard/presence controllers
    // may still be using it); that provider disposes it once nothing in
    // the room screen is watching it anymore.
  }

  @override
  void dispose() {
    leave();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}

// One shared socket connection per session room — chat/whiteboard/
// presence controllers all read this same instance instead of each
// opening their own, so there's exactly one 'session:join' per device.
// This controller (video) owns starting it, since it needs local camera
// access set up first anyway.
final signalingRepositoryProvider =
    Provider.autoDispose.family<SignalingRepository, String>((ref, sessionId) {
  final repo = SignalingRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final videoCallControllerProvider = StateNotifierProvider.autoDispose
    .family<VideoCallController, VideoCallState, String>((ref, sessionId) {
  final controller = VideoCallController(
    signaling: ref.watch(signalingRepositoryProvider(sessionId)),
    sessionsRepo: ref.read(sessionsRepositoryProvider),
    sessionId: sessionId,
  );
  controller.start();
  ref.onDispose(controller.dispose);
  return controller;
});
