// lib/features/sessions/widgets/chat_panel.dart
import 'package:flutter/material.dart';
import '../controllers/session_room_controller.dart';
import '../screens/session_room_screen.dart' show D;

class ChatPanel extends StatefulWidget {
  final SessionRoomState state;
  final SessionRoomController controller;
  const ChatPanel({super.key, required this.state, required this.controller});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(covariant ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.messages.length != oldWidget.state.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textCtrl.text;
    if (text.trim().isEmpty) return;
    widget.controller.sendChat(text);
    _textCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final myId = widget.controller.currentUserId;
    return Column(children: [
      Expanded(
        child: widget.state.messages.isEmpty
            ? const Center(
                child: Text('No messages yet — say hello!',
                    style: TextStyle(color: D.textSoft, fontSize: 12)))
            : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: widget.state.messages.length,
                itemBuilder: (_, i) {
                  final msg = widget.state.messages[i];
                  final mine = msg.senderId == myId;
                  return Align(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      constraints: const BoxConstraints(maxWidth: 260),
                      decoration: BoxDecoration(
                        color: mine ? D.magenta : D.surfaceRaised,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(msg.body,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: mine ? Colors.white : D.textPrimary)),
                          const SizedBox(height: 3),
                          Text(
                            '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                                fontSize: 9,
                                color: mine ? Colors.white70 : D.textSoft),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: D.surface,
          border: Border(top: BorderSide(color: D.border)),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              style: const TextStyle(color: D.textPrimary, fontSize: 13),
              maxLength: 2000,
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Message…',
                hintStyle: const TextStyle(color: D.textSoft),
                filled: true,
                fillColor: D.surfaceRaised,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _send,
            icon: const Icon(Icons.send_rounded, color: D.magenta),
          ),
        ]),
      ),
    ]);
  }
}
