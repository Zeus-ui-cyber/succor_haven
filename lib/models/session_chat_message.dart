// lib/models/session_chat_message.dart
class SessionChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String senderRole; // 'teacher' | 'student'
  final String body;
  final DateTime createdAt;

  const SessionChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.senderRole,
    required this.body,
    required this.createdAt,
  });

  factory SessionChatMessage.fromJson(Map<String, dynamic> json) =>
      SessionChatMessage(
        id: json['id'].toString(),
        senderId: json['sender_id'].toString(),
        senderName: json['sender_name'] as String? ?? 'Unknown',
        senderAvatarUrl: json['sender_avatar_url'] as String?,
        senderRole: json['sender_role'] as String? ?? 'student',
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
