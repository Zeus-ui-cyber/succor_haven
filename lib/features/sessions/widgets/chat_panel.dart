// lib/features/sessions/widgets/chat_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/session_chat_message.dart';
import '../../booking/utils/avatar_url.dart';
import '../controllers/chat_controller.dart';
import 'room_theme.dart';

class ChatPanel extends ConsumerStatefulWidget {
  final String sessionId;
  final String myUserId;
  const ChatPanel({super.key, required this.sessionId, required this.myUserId});

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    ref.read(chatControllerProvider(widget.sessionId).notifier).send(text);
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatControllerProvider(widget.sessionId));

    ref.listen(chatControllerProvider(widget.sessionId), (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });

    return Container(
      decoration: roomPanelDecoration(),
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.all(14),
          child: Row(children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 18, color: RoomColors.magenta),
            SizedBox(width: 8),
            Text('Session Chat',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: RoomColors.textPrimary)),
          ]),
        ),
        const Divider(height: 1, color: RoomColors.line),
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Text('No messages yet',
                      style: TextStyle(color: RoomColors.textSecondary, fontSize: 12)))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    return _ChatBubble(message: m, isMe: m.senderId == widget.myUserId);
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                style: const TextStyle(color: RoomColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(color: RoomColors.textSecondary),
                  filled: true,
                  fillColor: RoomColors.surfaceRaised,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _send,
              style: IconButton.styleFrom(
                backgroundColor: RoomColors.magenta,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final SessionChatMessage message;
  final bool isMe;
  const _ChatBubble({required this.message, required this.isMe});

  String _fmtTime(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final avatar = resolveAvatarUrl(message.senderAvatarUrl);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 12,
              backgroundColor: RoomColors.magenta.withValues(alpha: 0.25),
              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
              child: avatar == null
                  ? Text(
                      message.senderName.isNotEmpty
                          ? message.senderName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 10, color: RoomColors.magenta),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(isMe ? 'You' : message.senderName,
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: RoomColors.textSecondary)),
                  const SizedBox(width: 6),
                  Text(_fmtTime(message.createdAt),
                      style: const TextStyle(fontSize: 9.5, color: RoomColors.textSecondary)),
                ]),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? RoomColors.magenta : RoomColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(message.body,
                      style: const TextStyle(fontSize: 13, color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
