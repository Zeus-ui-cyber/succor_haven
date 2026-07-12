// lib/models/announcement_comment.dart
//
// Mirrors announcementComments.controller.js's joined shape:
//   list()/create() -> c.*, user_name, user_role
//
// One level of nesting: parentCommentId points at a top-level comment's
// id (or is null for a top-level comment itself). Replies-to-replies
// collapse under the original top-level comment on the client.

class AnnouncementCommentModel {
  final String id;
  final String announcementId;
  final String userId;
  final String? userName;
  final String? userRole;
  final String? parentCommentId;
  final String body;
  final DateTime createdAt;

  const AnnouncementCommentModel({
    required this.id,
    required this.announcementId,
    required this.userId,
    this.userName,
    this.userRole,
    this.parentCommentId,
    required this.body,
    required this.createdAt,
  });

  factory AnnouncementCommentModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    return AnnouncementCommentModel(
      id: json['id'].toString(),
      announcementId: json['announcement_id'].toString(),
      userId: json['user_id'].toString(),
      userName: json['user_name'] as String?,
      userRole: json['user_role'] as String?,
      parentCommentId: json['parent_comment_id']?.toString(),
      body: json['body'] as String? ?? '',
      createdAt: parseDate(json['created_at']),
    );
  }
}