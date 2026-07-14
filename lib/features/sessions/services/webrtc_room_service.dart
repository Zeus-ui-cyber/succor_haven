// lib/features/sessions/services/webrtc_room_service.dart
//
// Local camera/mic capture + one RTCPeerConnection to the other
// participant. Exactly two participants per room (teacher + student),
// so there's only ever one peer connection — no SFU/mesh logic needed.
//
// Signaling itself (who sends the offer, exchanging SDP/ICE) is done by
// the caller (SessionRoomController), which owns a SocketRoomService —
// this class only knows about local/remote MediaStreams and the RTC
// plumbing, not sockets.

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/session_room_models.dart';

class WebrtcRoomService {
  RTCPeerConnection? _pc;
  MediaStream? localStream;
  MediaStream? remoteStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  bool _micOn = true;
  bool _camOn = true;
  bool get micOn => _micOn;
  bool get camOn => _camOn;

  Future<void> init() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<bool> requestPermissions() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    return statuses.values.every((s) => s.isGranted);
  }

  Future<void> openLocalMedia() async {
    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
      },
    });
    localRenderer.srcObject = localStream;
  }

  Future<RTCPeerConnection> _ensurePeerConnection(
    TurnCredentials creds,
    void Function(RTCIceCandidate) onIceCandidate,
    void Function() onRemoteStreamReady,
  ) async {
    if (_pc != null) return _pc!;

    final config = {
      'iceServers': creds.iceServers.isEmpty
          ? [
              // Fallback so the call still has a shot at connecting on
              // pure host/srflx candidates if TURN creds fail to load —
              // NOT a real TURN relay, just public STUN.
              {'urls': 'stun:stun.l.google.com:19302'}
            ]
          : creds.iceServers.map((s) => s.toIceServerMap()).toList(),
    };

    _pc = await createPeerConnection(config);

    localStream?.getTracks().forEach((track) {
      _pc!.addTrack(track, localStream!);
    });

    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) onIceCandidate(candidate);
    };

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams.first;
        remoteRenderer.srcObject = remoteStream;
        onRemoteStreamReady();
      }
    };

    return _pc!;
  }

  Future<Map<String, dynamic>> createOffer({
    required TurnCredentials creds,
    required void Function(RTCIceCandidate) onIceCandidate,
    required void Function() onRemoteStreamReady,
  }) async {
    final pc =
        await _ensurePeerConnection(creds, onIceCandidate, onRemoteStreamReady);
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    return {'type': offer.type, 'sdp': offer.sdp};
  }

  Future<Map<String, dynamic>> createAnswerForOffer({
    required TurnCredentials creds,
    required Map<String, dynamic> remoteSdp,
    required void Function(RTCIceCandidate) onIceCandidate,
    required void Function() onRemoteStreamReady,
  }) async {
    final pc =
        await _ensurePeerConnection(creds, onIceCandidate, onRemoteStreamReady);
    await pc.setRemoteDescription(
      RTCSessionDescription(remoteSdp['sdp'], remoteSdp['type']),
    );
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    return {'type': answer.type, 'sdp': answer.sdp};
  }

  Future<void> applyRemoteAnswer(Map<String, dynamic> remoteSdp) async {
    if (_pc == null) return;
    await _pc!.setRemoteDescription(
      RTCSessionDescription(remoteSdp['sdp'], remoteSdp['type']),
    );
  }

  Future<void> addRemoteIceCandidate(Map<String, dynamic> candidateMap) async {
    if (_pc == null) return;
    await _pc!.addCandidate(RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'],
    ));
  }

  bool toggleMic() {
    _micOn = !_micOn;
    localStream?.getAudioTracks().forEach((t) => t.enabled = _micOn);
    return _micOn;
  }

  bool toggleCam() {
    _camOn = !_camOn;
    localStream?.getVideoTracks().forEach((t) => t.enabled = _camOn);
    return _camOn;
  }

  Future<void> hangup() async {
    await _pc?.close();
    _pc = null;
    remoteStream = null;
    remoteRenderer.srcObject = null;
  }

  Future<void> dispose() async {
    await hangup();
    localStream?.getTracks().forEach((t) => t.stop());
    await localStream?.dispose();
    await localRenderer.dispose();
    await remoteRenderer.dispose();
  }
}
