// lib/features/payments/repositories/payments_repository.dart

import '../../../core/api/api_service.dart';
import '../../../models/credit_package.dart';
import '../../../models/payment.dart';

class PaymentsRepository {
  final ApiService _api = ApiService.instance;

  // ── Public / student ─────────────────────────────────────────────────────
  Future<List<CreditPackageModel>> getPackages() async {
    final data = await _api.get('/credit-packages');
    return (data as List)
        .map((e) => CreditPackageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PaymentModel>> getMyPayments() async {
    final data = await _api.get('/credits/payments/mine');
    return (data as List)
        .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Student — request a purchase ────────────────────────────────────────
  // No payment gateway yet (Phase 2) — this creates a `pending` payment row.
  // The student is shown manual payment instructions (e.g. send to GCash),
  // and an admin confirms/rejects it from the Payments tab once the transfer
  // is verified — that's when credits actually get added to the account.
  Future<PaymentModel> requestPayment({
    required String creditPackageId,
    required String paymentMethod,
  }) async {
    final data = await _api.post('/credits/payments', data: {
      'creditPackageId': creditPackageId,
      'paymentMethod': paymentMethod,
    });
    return PaymentModel.fromJson(data as Map<String, dynamic>);
  }

  // ── Student — refund / cancel ───────────────────────────────────────────
  // Matches POST /credits/payments/:id/refund-request in routes/index.js
  // (paymentsCtrl.requestRefund). Flags the payment for admin review —
  // credits stay with the student until an admin actually processes it via
  // updatePaymentStatus(status: 'refunded') below, at which point a
  // succeeded->refunded transition claws credits back (or flags for manual
  // review if the balance's since been spent below that amount).
  Future<PaymentModel> requestRefund(String id) async {
    final data = await _api.post('/credits/payments/$id/refund-request');
    return PaymentModel.fromJson(data as Map<String, dynamic>);
  }

  // Matches PATCH /credits/payments/:id/cancel (paymentsCtrl.cancelPayment).
  // Only valid while the payment is still `pending` — cancelling before an
  // admin has confirmed/rejected it, with a reason for our own records.
  Future<PaymentModel> cancelPayment({
    required String id,
    required String reason,
  }) async {
    final data = await _api
        .patch('/credits/payments/$id/cancel', data: {'reason': reason});
    return PaymentModel.fromJson(data as Map<String, dynamic>);
  }

  // ── Admin — confirm / reject a payment ──────────────────────────────────
  // On 'succeeded', the backend credits `creditsAmount` from the linked
  // package onto the student's account. On 'refunded', it claws those
  // credits back if the student's current balance still covers it; if
  // they've since spent below that amount, credits are left alone and the
  // response flags it for manual review instead of silently under-crediting.
  //
  // ⚠️ ASSUMPTION: admin.controller.js's updatePaymentStatus response shape
  // wasn't visible to me — assuming it returns
  // `{ payment: {...same shape as GET /admin/payments item...},
  //    flaggedForReview: bool }`. If the real response is flat (payment
  // fields at the top level plus a `flaggedForReview` key, no nested
  // `payment` wrapper), swap `map['payment']` below for `map` directly.
  Future<({PaymentModel payment, bool flaggedForReview})> updatePaymentStatus({
    required String id,
    required String status, // 'succeeded' | 'failed' | 'refunded'
  }) async {
    final data = await _api
        .patch('/admin/payments/$id/status', data: {'status': status});
    final map = data as Map<String, dynamic>;
    final paymentJson = (map['payment'] as Map<String, dynamic>?) ?? map;
    return (
      payment: PaymentModel.fromJson(paymentJson),
      flaggedForReview: map['flaggedForReview'] as bool? ?? false,
    );
  }

  // ── Admin — packages ─────────────────────────────────────────────────────
  Future<List<CreditPackageModel>> getPackagesAdmin() async {
    final data = await _api.get('/admin/credit-packages');
    return (data as List)
        .map((e) => CreditPackageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createPackage({
    required String name,
    required int creditsAmount,
    required int priceCents,
    String currency = 'PHP',
    int displayOrder = 0,
  }) {
    return _api.post('/admin/credit-packages', data: {
      'name': name,
      'creditsAmount': creditsAmount,
      'priceCents': priceCents,
      'currency': currency,
      'displayOrder': displayOrder,
    });
  }

  Future<void> updatePackage({
    required String id,
    String? name,
    int? creditsAmount,
    int? priceCents,
    String? currency,
    int? displayOrder,
    bool? isActive,
  }) {
    return _api.patch('/admin/credit-packages/$id', data: {
      if (name != null) 'name': name,
      if (creditsAmount != null) 'creditsAmount': creditsAmount,
      if (priceCents != null) 'priceCents': priceCents,
      if (currency != null) 'currency': currency,
      if (displayOrder != null) 'displayOrder': displayOrder,
      if (isActive != null) 'isActive': isActive,
    });
  }

  Future<void> deletePackage(String id) {
    return _api.delete('/admin/credit-packages/$id');
  }

  // ── Admin — payments ─────────────────────────────────────────────────────
  /// Returns { payments: List<PaymentModel>, totalRevenueCents: int }.
  Future<({List<PaymentModel> payments, int totalRevenueCents})>
      getPaymentsAdmin({String? status, String? method}) async {
    final query = <String, String>{
      if (status != null) 'status': status,
      if (method != null) 'method': method,
    };
    final data =
        await _api.get('/admin/payments', query: query.isEmpty ? null : query);
    final map = data as Map<String, dynamic>;
    final payments = (map['payments'] as List)
        .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final totalRevenueCents = (map['totalRevenueCents'] as num).toInt();
    return (payments: payments, totalRevenueCents: totalRevenueCents);
  }
}
