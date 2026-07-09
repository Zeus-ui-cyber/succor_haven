// lib/features/booking/utils/avatar_url.dart
//
// Profile pictures are uploaded via POST /settings/profile/picture and
// served statically from the API's project root at /uploads/... (see
// app.js's `express.static` mount and routes/index.js's profilePictureDir),
// NOT from the "/api/v1" prefix that ApiService.baseUrl points at. So a
// stored avatar_url like "/uploads/profile-pictures/user-12-171.jpg" needs
// the "/api/v1" suffix stripped off the base URL, not appended to it.

import '../../../core/api/api_service.dart';

/// Resolves a possibly-relative avatar path into a fully-qualified URL
/// usable by Image.network / NetworkImage. Returns null for empty/missing
/// avatars so callers can fall back to a default avatar UI.
String? resolveAvatarUrl(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.trim().isEmpty) return null;
  final trimmed = avatarUrl.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  final serverRoot =
      ApiService.baseUrl.replaceAll(RegExp(r'/api(/v\d+)?/?$'), '');
  final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  return '$serverRoot$path';
}