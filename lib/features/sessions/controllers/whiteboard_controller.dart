// lib/features/sessions/controllers/whiteboard_controller.dart
//
// Live whiteboard — broadcast-only (see whiteboard.handlers.js), nothing
// persisted. Each stroke is one continuous pen gesture:
// {'points': [[x,y], ...], 'color': '#RRGGBB', 'width': double, 'tool': 'pen'|'eraser'}.
// The server's stroke/clear broadcasts exclude/include the sender
// differently (see comments below), which is why addLocalStroke()
// optimistically appends but clear()/permission changes just wait for
// the server's own echo instead of updating state twice.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/signaling_repository.dart';
import 'video_call_controller.dart' show signalingRepositoryProvider;

class WhiteboardState {
  final List<Map<String, dynamic>> strokes;
  final bool studentCanDraw;

  const WhiteboardState({required this.strokes, required this.studentCanDraw});

  factory WhiteboardState.initial() =>
      const WhiteboardState(strokes: [], studentCanDraw: true);

  WhiteboardState copyWith({
    List<Map<String, dynamic>>? strokes,
    bool? studentCanDraw,
  }) =>
      WhiteboardState(
        strokes: strokes ?? this.strokes,
        studentCanDraw: studentCanDraw ?? this.studentCanDraw,
      );
}

class WhiteboardController extends StateNotifier<WhiteboardState> {
  final SignalingRepository _signaling;
  final bool isTeacher;
  StreamSubscription? _strokeSub;
  StreamSubscription? _clearSub;
  StreamSubscription? _permSub;

  WhiteboardController(this._signaling, {required this.isTeacher})
      : super(WhiteboardState.initial()) {
    // Sender is excluded from its own 'whiteboard:stroke' broadcast (see
    // whiteboard.handlers.js), so only the OTHER participant's strokes
    // ever arrive here — this device's own strokes come from
    // addLocalStroke()'s optimistic append instead.
    _strokeSub = _signaling.onWhiteboardStroke.listen((stroke) {
      state = state.copyWith(strokes: [...state.strokes, stroke]);
    });
    // 'whiteboard:clear' and 'whiteboard:permission' ARE echoed back to
    // the sender (io.to(room), not socket.to(room)), so both devices —
    // including whichever teacher triggered it — converge through this
    // same listener. No separate optimistic update needed for these two.
    _clearSub = _signaling.onWhiteboardClear.listen((_) {
      state = state.copyWith(strokes: []);
    });
    _permSub = _signaling.onWhiteboardPermission.listen((canDraw) {
      state = state.copyWith(studentCanDraw: canDraw);
    });
  }

  bool get canIDraw => isTeacher || state.studentCanDraw;

  void addLocalStroke(Map<String, dynamic> stroke) {
    if (!canIDraw) return;
    state = state.copyWith(strokes: [...state.strokes, stroke]);
    _signaling.sendStroke(stroke);
  }

  void clear() {
    if (!isTeacher) return;
    _signaling.sendWhiteboardClear();
  }

  void setStudentPermission(bool canDraw) {
    if (!isTeacher) return;
    _signaling.setWhiteboardPermission(canDraw);
  }

  @override
  void dispose() {
    _strokeSub?.cancel();
    _clearSub?.cancel();
    _permSub?.cancel();
    super.dispose();
  }
}

final whiteboardControllerProvider = StateNotifierProvider.autoDispose.family<
    WhiteboardController,
    WhiteboardState,
    ({String sessionId, bool isTeacher})>((ref, args) {
  return WhiteboardController(
    ref.watch(signalingRepositoryProvider(args.sessionId)),
    isTeacher: args.isTeacher,
  );
});
