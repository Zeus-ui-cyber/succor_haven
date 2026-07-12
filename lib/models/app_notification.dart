// lib/models/app_notification.dart
//
// Mirrors notifications.controller.js's row shape. Rows are created
// server-side by announcements.controller.js's notifyEligibleUsers() when
// an admin publishes — this model is read-only from the client's side.

class AppNotificationModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String? body;
  final String? announcementId;
  // Set on payment-lifecycle notifications (submitted/succeeded/failed/
  // refunded/refund-requested) — see payments.controller.js's notifyUser()
  // and notifyAdmins(). Not currently used for tap-navigation: the target
  // screen differs by role (student vs. admin) and this model has no
  // access to the viewer's role, so wiring that up is left for later
  // rather than risk a role-mismatched deep link.
  final String? paymentId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.body,
    this.announcementId,
    this.paymentId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      announcementId: json['announcement_id']?.toString(),
      paymentId: json['payment_id']?.toString(),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}