import 'dart:convert';
import 'lib/models/announcement.dart';

void main() {
  const jsonStr = '''{
    "id": "6e7f97c5-ce44-44dc-90ed-b365fca0ec6a",
    "title": "test",
    "subtitle": null,
    "description": "test comming",
    "cover_image_url": null,
    "gallery_urls": [],
    "attachment_url": null,
    "attachment_name": null,
    "external_link": null,
    "category": "event",
    "priority": "normal",
    "visibility": "everyone",
    "target_value": null,
    "is_pinned": true,
    "is_archived": false,
    "comments_enabled": true,
    "publish_at": "2026-07-21T01:19:00.000Z",
    "expires_at": "2026-07-21T02:00:00.000Z",
    "created_by": "a7e35692-9136-4934-ab28-ad74e5981ca7",
    "created_at": "2026-07-21T01:26:25.731Z",
    "updated_at": "2026-07-21T01:26:25.731Z"
  }''';

  try {
    final map = jsonDecode(jsonStr);
    final a = AnnouncementModel.fromJson(map);
    print("Success: \${a.title}");
  } catch (e, st) {
    print("Error: \$e\\n\$st");
  }
}
