import 'dart:convert';

void main() {
  final title = "test";
  final subtitle = "";
  final description = "test comming";
  final category = "event";
  final priority = "normal";
  final visibility = "everyone";
  final targetValue = "";
  final coverImageUrl = null;
  final galleryUrls = <String>[];
  final attachmentUrl = null;
  final attachmentName = null;
  final externalLink = "";
  final publishAt = DateTime.parse("2026-07-21 09:19:00");
  final expiresAt = DateTime.parse("2026-07-21 10:00:00");
  final isPinned = true;
  final commentsEnabled = true;

  final payload = {
        'title': title,
        if (subtitle != null && subtitle.trim().isNotEmpty) 'subtitle': subtitle.trim(),
        'description': description,
        'category': category,
        'priority': priority,
        'visibility': visibility,
        if (targetValue != null && targetValue.trim().isNotEmpty) 'targetValue': targetValue.trim(),
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        if (galleryUrls != null) 'galleryUrls': galleryUrls,
        if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
        if (attachmentName != null) 'attachmentName': attachmentName,
        if (externalLink != null && externalLink.trim().isNotEmpty) 'externalLink': externalLink.trim(),
        if (publishAt != null) 'publishAt': publishAt.toUtc().toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
        'isPinned': isPinned,
        'commentsEnabled': commentsEnabled,
      };

  print(jsonEncode(payload));
}
