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
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
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
  final bool remoteCameraOn;
  final bool remoteMicOn;
  final bool sharingScreen;
  final bool remoteSharingScreen;
  final String? errorMessage;

  const VideoCallState({
    required this.connectionState,
    required this.cameraOn,
    required this.micOn,
    required this.speakerOn,
    required this.remoteConnected,
    this.remoteCameraOn = true,
    this.remoteMicOn = true,
    this.sharingScreen = false,
    this.remoteSharingScreen = false,
    this.errorMessage,
  });

  factory VideoCallState.initial() => const VideoCallState(
        connectionState: CallConnectionState.idle,
        cameraOn: true,
        micOn: true,
        speakerOn: true,
        remoteConnected: false,
        remoteCameraOn: true,
        remoteMicOn: true,
      );

  VideoCallState copyWith({
    CallConnectionState? connectionState,
    bool? cameraOn,
    bool? micOn,
    bool? speakerOn,
    bool? remoteConnected,
    bool? remoteCameraOn,
    bool? remoteMicOn,
    bool? sharingScreen,
    bool? remoteSharingScreen,
    String? errorMessage,
  }) =>
      VideoCallState(
        connectionState: connectionState ?? this.connectionState,
        cameraOn: cameraOn ?? this.cameraOn,
        micOn: micOn ?? this.micOn,
        speakerOn: speakerOn ?? this.speakerOn,
        remoteConnected: remoteConnected ?? this.remoteConnected,
        remoteCameraOn: remoteCameraOn ?? this.remoteCameraOn,
        remoteMicOn: remoteMicOn ?? this.remoteMicOn,
        sharingScreen: sharingScreen ?? this.sharingScreen,
        remoteSharingScreen: remoteSharingScreen ?? this.remoteSharingScreen,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class VideoCallController extends StateNotifier<VideoCallState> {
  final SignalingRepository signaling;
  final SessionsRepository sessionsRepo;
  final String sessionId;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  final RTCVideoRenderer screenShareRenderer = RTCVideoRenderer();

  MediaStream? _localStream;
  MediaStream? _screenStream;
  RTCPeerConnection? _pc;
  Future<RTCPeerConnection>? _pcFuture;
  bool _remoteDescriptionSet = false;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  final List<StreamSubscription> _subs = [];

  // The first remote MediaStream and video track we ever see (from onTrack) is the peer's
  // camera+mic — its id becomes the reference point for telling that apart
  // from a screen-share track added later via renegotiation, since both
  // arrive on the same peer connection with no other metadata to key off.
  String? _remoteCameraStreamId;
  String? _remoteCameraVideoTrackId;
  MediaStream? _remoteScreenStream;

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
      await screenShareRenderer.initialize();

      // FIXED: mute the local preview before setting srcObject so the browser's
      // autoplay policy doesn't block the video from playing due to unmuted audio.
      // This is wrapped in kIsWeb because on mobile, RTCVideoRenderer.muted
      // modifies the actual track enabled state (muting the mic for the peer!)
      // and throws if srcObject is null. Mobile handles playback automatically.
      if (kIsWeb) {
        localRenderer.muted = true;
        remoteRenderer.muted = false;
        screenShareRenderer.muted = true;
      }

      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': kIsWeb ? true : {'facingMode': 'user'},
      });
      localRenderer.srcObject = _localStream;

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
    // Standard desktop apps don't use runtime permission prompts like mobile
    if (defaultTargetPlatform != TargetPlatform.android && 
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!camera.isGranted || !mic.isGranted) {
      throw Exception(
          'Camera and microphone permissions are required to join.');
    }
  }

  void _listen() {
    _subs.add(signaling.onPeerJoined.listen((_) {
      _createOffer();
      signaling.sendMediaState(state.cameraOn, state.micOn);
    }));
    _subs.add(signaling.onOffer.listen((data) {
      _handleOffer(data);
      signaling.sendMediaState(state.cameraOn, state.micOn);
    }));
    _subs.add(signaling.onAnswer.listen(_handleAnswer));
    _subs.add(signaling.onIceCandidate.listen(_handleRemoteIceCandidate));
    _subs.add(signaling.onMediaState.listen((data) {
      state = state.copyWith(
        remoteCameraOn: data['cameraOn'] as bool?,
        remoteMicOn: data['micOn'] as bool?,
      );
    }));
    _subs.add(signaling.onPeerLeft.listen((_) async {
      remoteRenderer.srcObject = null;
      screenShareRenderer.srcObject = null;
      
      // Clean up the dead peer connection entirely. When they rejoin,
      // _ensurePeerConnection will create a fresh, clean one.
      await _pc?.close();
      _pc = null;
      _pcFuture = null;
      _remoteDescriptionSet = false;
      _remoteCameraStreamId = null;
      _pendingRemoteCandidates.clear();

      // If a previous error put us in failed state, or if closing the PC
      // caused an ongoing negotiation to throw, clear the error.
      state = state.copyWith(
        remoteConnected: false,
        remoteSharingScreen: false,
        remoteCameraOn: true, // reset for next peer
        remoteMicOn: true,
        connectionState: CallConnectionState.waitingForPeer,
        errorMessage: null, // Clear any residual errors
      );
    }));
    _subs.add(signaling.onScreenShareStarted.listen((_) {
      state = state.copyWith(remoteSharingScreen: true);
      if (_remoteScreenStream != null) {
        screenShareRenderer.srcObject = null;
        screenShareRenderer.srcObject = _remoteScreenStream;
      }
    }));
    _subs.add(signaling.onScreenShareStopped.listen((_) {
      _remoteScreenStream = null;
      screenShareRenderer.srcObject = null;
      state = state.copyWith(remoteSharingScreen: false);
    }));
  }

  // Memoized so concurrent callers (an incoming offer and an incoming ICE
  // candidate can both land while we're still awaiting TURN credentials)
  // await the SAME peer connection instead of each racing to create their
  // own — otherwise negotiation lands on one RTCPeerConnection while
  // remote candidates get added to a different, never-negotiated one, and
  // the call never connects even though signaling itself is fine.
  Future<RTCPeerConnection> _ensurePeerConnection() {
    final existing = _pc;
    if (existing != null) return Future.value(existing);
    return _pcFuture ??= _createPeerConnection();
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
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
      if (event.streams.isEmpty) return;
      final stream = event.streams[0];

      // The first stream and video track we see from this peer is their camera+mic.
      _remoteCameraStreamId ??= stream.id;
      if (event.track.kind == 'video' &&
          _remoteCameraVideoTrackId == null &&
          !state.remoteSharingScreen) {
        _remoteCameraVideoTrackId = event.track.id;
      }

      // Check if this track is the screen share track (renegotiated mid-call,
      // or arrived while remoteSharingScreen is active, or has a different track/stream ID).
      final isScreenShareTrack = (state.remoteSharingScreen &&
              event.track.kind == 'video' &&
              event.track.id != _remoteCameraVideoTrackId) ||
          (stream.id != _remoteCameraStreamId && _remoteCameraStreamId != null);

      if (isScreenShareTrack) {
        // Native Android WebRTC renderer fix: force null then re-bind stream
        _remoteScreenStream = stream;
        screenShareRenderer.srcObject = null;
        screenShareRenderer.srcObject = stream;
        state = state.copyWith(remoteSharingScreen: true);
      } else {
        if (remoteRenderer.srcObject != stream) {
          remoteRenderer.srcObject = stream;
        } else if (event.track.kind == 'video') {
          // FIXED: flutter_webrtc native Android bug. If the audio track arrives first,
          // the native renderer binds to a stream with no video. When the video track
          // arrives milliseconds later, assigning the same stream object is ignored
          // by the Dart setter, and the native renderer never updates. Forcing it to 
          // null and back triggers the native re-bind so the video actually shows up.
          remoteRenderer.srcObject = null;
          remoteRenderer.srcObject = stream;
        }

        // Re-assert unmuted right when the real remote stream lands —
        // some browsers reset renderer audio state when srcObject changes.
        if (kIsWeb) {
          remoteRenderer.muted = false;
        }
        state = state.copyWith(
          remoteConnected: true,
          connectionState: CallConnectionState.connected,
        );
      }
    };

    pc.onRemoveTrack = (stream, track) {
      // Failsafe: clear the screen share UI if the WebRTC layer drops the track
      // before the socket.io signaling packet arrives.
      if (screenShareRenderer.srcObject != null) {
        final currentTracks = screenShareRenderer.srcObject!.getVideoTracks();
        if (currentTracks.any((t) => t.id == track.id)) {
          screenShareRenderer.srcObject = null;
          state = state.copyWith(remoteSharingScreen: false);
        }
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
    // An offer can arrive either as the initial call setup or as a
    // renegotiation (e.g. the peer starting/stopping screen share). Only
    // flip the UI to "negotiating" for the former — a renegotiation offer
    // shouldn't make an already-connected call look like it dropped.
    final isRenegotiation = state.remoteConnected;
    try {
      if (!isRenegotiation) {
        state = state.copyWith(connectionState: CallConnectionState.negotiating);
      }
      final pc = await _ensurePeerConnection();
      final sdpData = data['sdp'] as Map;
      await pc.setRemoteDescription(
        RTCSessionDescription(
            sdpData['sdp'] as String, sdpData['type'] as String),
      );
      await _onRemoteDescriptionSet(pc);
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      signaling.sendAnswer({'sdp': answer.sdp, 'type': answer.type});
      if (isRenegotiation) {
        state = state.copyWith(connectionState: CallConnectionState.connected);
      }
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
      await _onRemoteDescriptionSet(pc);
    } catch (e) {
      state = state.copyWith(
        connectionState: CallConnectionState.failed,
        errorMessage: '$e',
      );
    }
  }

  // Flushes any ICE candidates that arrived (and were buffered) before the
  // remote description was set — addCandidate() throws if called earlier,
  // so those can't just be applied immediately as they come in.
  Future<void> _onRemoteDescriptionSet(RTCPeerConnection pc) async {
    _remoteDescriptionSet = true;
    final queued = List<RTCIceCandidate>.from(_pendingRemoteCandidates);
    _pendingRemoteCandidates.clear();
    for (final candidate in queued) {
      await pc.addCandidate(candidate);
    }
  }

  Future<void> _handleRemoteIceCandidate(Map<String, dynamic> data) async {
    try {
      final pc = await _ensurePeerConnection();
      final c = data['candidate'] as Map;
      final candidate = RTCIceCandidate(
        c['candidate'] as String?,
        c['sdpMid'] as String?,
        c['sdpMLineIndex'] as int?,
      );
      if (!_remoteDescriptionSet) {
        // The remote description (offer/answer) hasn't landed yet — queue
        // it rather than dropping it, since these are the candidates the
        // connection actually needs to succeed, not spares.
        _pendingRemoteCandidates.add(candidate);
        return;
      }
      await pc.addCandidate(candidate);
    } catch (_) {
      // A stray failure here (e.g. a duplicate/late candidate) isn't fatal
      // to the call — plenty of other candidates are still in flight.
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
    signaling.sendMediaState(newValue, state.micOn);
  }

  void toggleMic() {
    final tracks = _localStream?.getAudioTracks() ?? [];
    if (tracks.isEmpty) return;
    final newValue = !state.micOn;
    for (final t in tracks) {
      t.enabled = newValue;
    }
    state = state.copyWith(micOn: newValue);
    signaling.sendMediaState(state.cameraOn, newValue);
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

  // ── Screen sharing ────────────────────────────────────────────────────
  //
  // Adds/removes a video-only track on the SAME peer connection used for
  // camera/mic, rather than opening a second connection — so it renegotiates
  // via a fresh createOffer()/setLocalDescription() sent through the same
  // signaling.sendOffer() the initial call used (see the offer/answer relay
  // comment in signaling.handlers.js). Safe from renegotiation glare because
  // only one side can hold the "sharing" slot at a time (enforced server-side
  // by screenshare:start's ack), so both sides never call createOffer() for
  // a screen-share change at once.
  // Throws on failure (instead of only recording state.errorMessage) so the
  // button that triggers this can show the failure immediately — silently
  // swallowing it here would make a real error (permission denied, browser
  // doesn't support screen capture, peer not connected yet, ...) look
  // exactly like the button doing nothing at all.
  Future<void> startScreenShare() async {
    if (state.sharingScreen) return;
    if (!state.remoteConnected) {
      throw Exception(
          'Wait for the other participant to join before sharing your screen.');
    }
    try {
      await signaling.startScreenShare();

      final screenStream = await navigator.mediaDevices.getDisplayMedia({
        'video': true,
        'audio': false,
      });
      _screenStream = screenStream;
      screenShareRenderer.srcObject = screenStream;

      final pc = await _ensurePeerConnection();
      for (final track in screenStream.getVideoTracks()) {
        // Fires if the user stops sharing via the browser/OS's own native
        // "Stop sharing" control instead of our in-app button.
        track.onEnded = () => stopScreenShare();
        await pc.addTrack(track, screenStream);
      }
      await _renegotiate(pc);
      state = state.copyWith(sharingScreen: true);
    } catch (e) {
      final stream = _screenStream;
      _screenStream = null;
      screenShareRenderer.srcObject = null;
      if (stream != null) {
        for (final t in stream.getTracks()) {
          await t.stop();
        }
        await stream.dispose();
      }
      state = state.copyWith(errorMessage: '$e');
      rethrow;
    }
  }

  Future<void> stopScreenShare() async {
    if (!state.sharingScreen) return;
    final stream = _screenStream;
    _screenStream = null;
    screenShareRenderer.srcObject = null;
    state = state.copyWith(sharingScreen: false);
    signaling.stopScreenShare();

    final pc = _pc;
    if (pc != null && stream != null) {
      final senders = await pc.getSenders();
      for (final track in stream.getTracks()) {
        for (final sender in senders) {
          if (sender.track?.id == track.id) {
            await pc.removeTrack(sender);
          }
        }
        await track.stop();
      }
      await stream.dispose();
      await _renegotiate(pc);
    }
  }

  Future<void> _renegotiate(RTCPeerConnection pc) async {
    int retries = 0;
    while (pc.signalingState != RTCSignalingState.RTCSignalingStateStable && retries < 10) {
      await Future.delayed(const Duration(milliseconds: 200));
      retries++;
    }
    if (pc.signalingState != RTCSignalingState.RTCSignalingStateStable) {
      return;
    }
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    signaling.sendOffer({'sdp': offer.sdp, 'type': offer.type});
  }

  Future<void> leave() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _pc?.close();
    _pc = null;
    _pcFuture = null;
    _remoteDescriptionSet = false;
    _remoteCameraStreamId = null;
    _pendingRemoteCandidates.clear();
    final stream = _localStream;
    if (stream != null) {
      for (final t in stream.getTracks()) {
        await t.stop();
      }
      await stream.dispose();
    }
    _localStream = null;
    final screenStream = _screenStream;
    if (screenStream != null) {
      for (final t in screenStream.getTracks()) {
        await t.stop();
      }
      await screenStream.dispose();
    }
    _screenStream = null;
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
    screenShareRenderer.dispose();
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
