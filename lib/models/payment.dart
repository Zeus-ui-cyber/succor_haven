// lib/models/payment.dart

enum PaymentStatus { pending, succeeded, failed, refunded, cancelled }

extension PaymentStatusX on PaymentStatus {
  static PaymentStatus fromApi(String value) {
    switch (value) {
      case 'succeeded':
        return PaymentStatus.succeeded;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      case 'cancelled':
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.pending;
    }
  }

  String get label => switch (this) {
        PaymentStatus.pending => 'Pending',
        PaymentStatus.succeeded => 'Succeeded',
        PaymentStatus.failed => 'Failed',
        PaymentStatus.refunded => 'Refunded',
        PaymentStatus.cancelled => 'Cancelled',
      };
}

class PaymentModel {
  final String id;
  final int amountCents;
  final String currency;
  final String? paymentMethod;
  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime? paidAt;
  final String? packageName;
  final int? creditsAmount;
  final DateTime? refundRequestedAt;
  final String? cancelReason;
  // Admin-list-only fields — null when parsed from /credits/payments/mine.
  final String? studentName;
  final String? studentEmail;

  const PaymentModel({
    required this.id,
    required this.amountCents,
    required this.currency,
    this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.paidAt,
    this.packageName,
    this.creditsAmount,
    this.refundRequestedAt,
    this.cancelReason,
    this.studentName,
    this.studentEmail,
  });

  double get amountDisplay => amountCents / 100;

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'].toString(),
      amountCents: (json['amount_cents'] as num).toInt(),
      currency: json['currency'] as String? ?? 'PHP',
      paymentMethod: json['payment_method'] as String?,
      status: PaymentStatusX.fromApi(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      packageName: json['package_name'] as String?,
      creditsAmount: (json['credits_amount'] as num?)?.toInt(),
      refundRequestedAt: json['refund_requested_at'] != null
          ? DateTime.parse(json['refund_requested_at'] as String)
          : null,
      cancelReason: json['cancel_reason'] as String?,
      studentName: json['student_name'] as String?,
      studentEmail: json['student_email'] as String?,
    );
  }
}
