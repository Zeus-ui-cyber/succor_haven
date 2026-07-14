// lib/features/sessions/widgets/chat_panel.dart
import 'package:flutter/material.dart';
import '../../booking/utils/avatar_url.dart';
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

  ({String name, String role, String? avatarUrl, Color color}) _senderInfo(
      String senderId) {
    final session = widget.controller.session;
    if (senderId == session.teacherId) {
      return (
        name: session.teacherName ?? 'Teacher',
        role: 'Teacher',
        avatarUrl: resolveAvatarUrl(session.teacherAvatarUrl),
        color: D.slateBlue,
      );
    }
    return (
      name: session.studentName ?? 'Student',
      role: 'Student',
      avatarUrl: resolveAvatarUrl(session.studentAvatarUrl),
      color: D.magenta,
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = widget.controller.currentUserId;
    return Column(children: [
      Expanded(
        child: widget.state.messages.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 28, color: D.textSoft.withOpacity(0.5)),
                  const SizedBox(height: 8),
                  const Text('No messages yet — say hello!',
                      style: TextStyle(color: D.textSoft, fontSize: 12)),
                ]),
              )
            : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: widget.state.messages.length,
                itemBuilder: (_, i) {
                  final msg = widget.state.messages[i];
                  final mine = msg.senderId == myId;
                  final info = _senderInfo(msg.senderId);
                  final time =
                      '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: mine
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (!mine) ...[
                          _Avatar(name: info.name, url: info.avatarUrl, color: info.color),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Column(
                            crossAxisAlignment: mine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(mine ? 'You' : info.name,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: mine ? D.textSoft : info.color)),
                                    const SizedBox(width: 5),
                                    Text(time,
                                        style: const TextStyle(
                                            fontSize: 9.5, color: D.textSoft)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 9),
                                constraints: const BoxConstraints(maxWidth: 230),
                                decoration: BoxDecoration(
                                  gradient: mine
                                      ? const LinearGradient(colors: [
                                          D.magenta,
                                          Color(0xFFB93A63),
                                        ])
                                      : null,
                                  color: mine ? null : D.surfaceRaised,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(14),
                                    topRight: const Radius.circular(14),
                                    bottomLeft:
                                        Radius.circular(mine ? 14 : 3),
                                    bottomRight:
                                        Radius.circular(mine ? 3 : 14),
                                  ),
                                ),
                                child: Text(msg.body,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: mine
                                            ? Colors.white
                                            : D.textPrimary)),
                              ),
                            ],
                          ),
                        ),
                        if (mine) ...[
                          const SizedBox(width: 8),
                          _Avatar(name: 'You', url: null, color: D.green),
                        ],
                      ],
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
          Container(
            decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [D.magenta, Color(0xFFB93A63)])),
            child: IconButton(
              onPressed: _send,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? url;
  final Color color;
  const _Avatar({required this.name, required this.url, required this.color});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: color.withOpacity(0.25),
      backgroundImage: url != null ? NetworkImage(url!) : null,
      child: url == null
          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color))
          : null,
    );
  }
}
