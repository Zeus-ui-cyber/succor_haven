// lib/features/sessions/controllers/chat_controller.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session_chat_message.dart';
import '../repositories/sessions_repository.dart';
import '../repositories/signaling_repository.dart';
import 'session_list_controller.dart' show sessionsRepositoryProvider;
import 'video_call_controller.dart' show signalingRepositoryProvider;

class ChatController extends StateNotifier<List<SessionChatMessage>> {
  final SessionsRepository _sessionsRepo;
  final SignalingRepository _signaling;
  final String sessionId;
  StreamSubscription? _sub;

  ChatController({
    required SessionsRepository sessionsRepo,
    required SignalingRepository signaling,
    required this.sessionId,
  })  : _sessionsRepo = sessionsRepo,
        _signaling = signaling,
        super([]) {
    _loadHistory();
    _sub = _signaling.onChatMessage.listen((data) {
      state = [...state, SessionChatMessage.fromJson(data)];
    });
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _sessionsRepo.getChatHistory(sessionId);
      state = history.map(SessionChatMessage.fromJson).toList();
    } catch (_) {
      // Chat panel just opens empty — not fatal to the call itself.
    }
  }

  Future<void> send(String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    await _signaling.sendChat(text);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final chatControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatController, List<SessionChatMessage>, String>((ref, sessionId) {
  return ChatController(
    sessionsRepo: ref.read(sessionsRepositoryProvider),
    signaling: ref.watch(signalingRepositoryProvider(sessionId)),
    sessionId: sessionId,
  );
});
