// lib/features/sessions/controllers/presence_controller.dart
//
// Raise hand + emoji reactions — ephemeral UI state, no persistence.
// Reactions auto-clear themselves 3s after arriving so they behave like
// a toast/burst rather than sticking around.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/signaling_repository.dart';
import 'video_call_controller.dart' show signalingRepositoryProvider;

class ReactionEvent {
  final String userId;
  final String emoji;
  final DateTime at;
  const ReactionEvent({required this.userId, required this.emoji, required this.at});
}

class PresenceState {
  final bool myHandRaised;
  final Map<String, bool> raisedHands; // userId -> raised
  final List<ReactionEvent> recentReactions;

  const PresenceState({
    required this.myHandRaised,
    required this.raisedHands,
    required this.recentReactions,
  });

  factory PresenceState.initial() => const PresenceState(
        myHandRaised: false,
        raisedHands: {},
        recentReactions: [],
      );

  PresenceState copyWith({
    bool? myHandRaised,
    Map<String, bool>? raisedHands,
    List<ReactionEvent>? recentReactions,
  }) =>
      PresenceState(
        myHandRaised: myHandRaised ?? this.myHandRaised,
        raisedHands: raisedHands ?? this.raisedHands,
        recentReactions: recentReactions ?? this.recentReactions,
      );
}

class PresenceController extends StateNotifier<PresenceState> {
  final SignalingRepository _signaling;
  final String myUserId;
  StreamSubscription? _handSub;
  StreamSubscription? _reactionSub;

  PresenceController(this._signaling, {required this.myUserId})
      : super(PresenceState.initial()) {
    _handSub = _signaling.onRaiseHand.listen((data) {
      final userId = data['userId'] as String;
      final raised = data['raised'] as bool? ?? false;
      state = state.copyWith(raisedHands: {...state.raisedHands, userId: raised});
    });
    _reactionSub = _signaling.onReaction.listen((data) {
      final event = ReactionEvent(
        userId: data['userId'] as String,
        emoji: data['emoji'] as String,
        at: DateTime.now(),
      );
      state = state.copyWith(recentReactions: [...state.recentReactions, event]);
      Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        state = state.copyWith(
          recentReactions:
              state.recentReactions.where((r) => r.at != event.at).toList(),
        );
      });
    });
  }

  void toggleRaiseHand() {
    final newValue = !state.myHandRaised;
    state = state.copyWith(myHandRaised: newValue);
    _signaling.raiseHand(newValue);
  }

  void sendReaction(String emoji) {
    _signaling.sendReaction(emoji);
    // Optimistic local burst — the server doesn't echo reactions back to
    // the sender (socket.to(room) excludes them), so without this the
    // person who tapped the reaction would never see their own emoji.
    final event = ReactionEvent(userId: myUserId, emoji: emoji, at: DateTime.now());
    state = state.copyWith(recentReactions: [...state.recentReactions, event]);
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      state = state.copyWith(
        recentReactions:
            state.recentReactions.where((r) => r.at != event.at).toList(),
      );
    });
  }

  @override
  void dispose() {
    _handSub?.cancel();
    _reactionSub?.cancel();
    super.dispose();
  }
}

final presenceControllerProvider = StateNotifierProvider.autoDispose.family<
    PresenceController, PresenceState, ({String sessionId, String myUserId})>(
  (ref, args) => PresenceController(
    ref.watch(signalingRepositoryProvider(args.sessionId)),
    myUserId: args.myUserId,
  ),
);
