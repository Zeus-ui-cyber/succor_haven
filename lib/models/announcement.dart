// lib/models/announcement.dart
//
// Mirrors announcements.controller.js's joined shape:
//   list()/getOne()/adminList() -> a.*, created_by_name, like_count, ...
//
// created_by is INTEGER on the live schema (users.id is INTEGER, not
// UUID — same convention as ModuleModel.uploadedBy), parsed defensively
// via .toString() so a numeric JSON value never throws an `as String`
// cast error.

class AnnouncementModel {
  final String id;
  final String title;
  final String? subtitle;
  final String description;
  final String category;
  final String priority;
  final String visibility;
  final String? targetValue;
  final String? coverImageUrl;
  final List<String> galleryUrls;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? externalLink;
  final DateTime publishAt;
  final DateTime? expiresAt;
  final bool isPinned;
  final bool isArchived;
  final bool commentsEnabled;
  final String createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isRead;
  final bool isLiked;
  final bool isBookmarked;
  final int likeCount;
  final int readCount;
  final int commentCount;

  const AnnouncementModel({
    required this.id,
    required this.title,
    this.subtitle,
    required this.description,
    required this.category,
    required this.priority,
    required this.visibility,
    this.targetValue,
    this.coverImageUrl,
    this.galleryUrls = const [],
    this.attachmentUrl,
    this.attachmentName,
    this.externalLink,
    required this.publishAt,
    this.expiresAt,
    required this.isPinned,
    required this.isArchived,
    required this.commentsEnabled,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
    required this.updatedAt,
    this.isRead = false,
    this.isLiked = false,
    this.isBookmarked = false,
    this.likeCount = 0,
    this.readCount = 0,
    this.commentCount = 0,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v, {DateTime? fallback}) {
      if (v == null) return fallback ?? DateTime.now();
      final parsed = DateTime.tryParse(v.toString());
      return parsed ?? (fallback ?? DateTime.now());
    }

    DateTime? parseDateOrNull(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return AnnouncementModel(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'announcement',
      priority: json['priority'] as String? ?? 'normal',
      visibility: json['visibility'] as String? ?? 'everyone',
      targetValue: json['target_value'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      galleryUrls: (json['gallery_urls'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      attachmentUrl: json['attachment_url'] as String?,
      attachmentName: json['attachment_name'] as String?,
      externalLink: json['external_link'] as String?,
      publishAt: parseDate(json['publish_at']),
      expiresAt: parseDateOrNull(json['expires_at']),
      isPinned: json['is_pinned'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      commentsEnabled: json['comments_enabled'] as bool? ?? false,
      createdBy: json['created_by'].toString(),
      createdByName: json['created_by_name'] as String?,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      isRead: json['is_read'] as bool? ?? false,
      isLiked: json['is_liked'] as bool? ?? false,
      isBookmarked: json['is_bookmarked'] as bool? ?? false,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      readCount: (json['read_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
    );
  }
}